defmodule Legl.Countries.Uk.UkSearch do
  @moduledoc """
    Module to undertake searches against the title and content of legislation.gov.uk
    using keywords.
    There are two url patterns.  The first uses the title search and second full text search.
    1.https://www.legislation.gov.uk/all?title=ragwort&results-count=1000&sort=year
    2.https://www.legislation.gov.uk/all?text=ragwort&results-count=1000&sort=year
    2b.https://www.legislation.gov.uk/all?text=%22nature%20conservation%22&results-count=1000&sort=year
  """

  # create the search terms

  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Countries.Uk.UkSearch.Terms

  defstruct [
    :name,
    :title,
    :path,
    :type,
    :year,
    :number,
    :search
  ]

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.ParserSearch.search_parser/1
  @at_csv "airtable_new_law?"

  @pattern quote do: [
                   {"td", _, [{"a", [{"href", _}], [var!(title)]}]},
                   {"td", _, [{"a", [{"href", var!(path)}], [var!(_year_number)]}]},
                   {"td", _, [_type_description]}
                 ]

  @welsh quote do: [
                 {"td", [{"class", "bilingual cy"}],
                  [{"a", [{"href", var!(_path)}, _], [var!(_title)]}]}
               ]

  @doc """
    To run the saved searches use
      Legl.Countries.Uk.UkSearch.run(:waste)
    To search inside the content
      Legl.Countries.Uk.UkSearch.run(:waste, %{search_type: :all})
    To run a tailored search
      Legl.Countries.Uk.UkSearch.run(:waste, %{waste: [["waste"]], search_type: :title})
  """
  def run(search, opts \\ []) do
    opts = Enum.into(opts, Terms.all_search_terms())
    IO.inspect(opts)
    # |> IO.inspect()
    search_set = Map.get(opts, search)
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, "Name,Title_EN,type_code,year,number,search_paste")

    results =
      Enum.reduce(search_set, %{}, fn search_terms, acc ->
        workflow(search_terms, opts.search_type, acc)
      end)

    Enum.each(results, fn {_k, v} -> save_to_csv(file, v) end)
    File.close(file)
  end

  def workflow(search_terms, search_type, results) do
    Enum.reduce(search_terms, results, fn search, acc ->
      search = Regex.replace(~r/\s/u, search, " ")
      IO.puts("#{search}")

      url =
        case search_type do
          :title ->
            URI.encode(~s[/all?title="#{search}"&results-count=1000&sort=year])

          _ ->
            URI.encode(~s[/all?text="#{search}"&results-count=1000&sort=year])
        end

      get_search_results(url, search_type, search, acc)
    end)
  end

  def get_search_results(url, search_type, search, results) do
    with(
      IO.puts("#{url}"),
      {:ok, table_data} <- RecordGeneric.leg_gov_uk_html(url, @client, @parser),
      {:ok, results} <- process_search_table(table_data, search, results),
      {:ok, results} <- rm_matching_title_for_all_text_search(search_type, search, results)
    ) do
      results
    else
      {:error, code, _url, error} ->
        IO.puts("#{code} #{error} #{search}")
        results
    end
  end

  def save_to_csv(file, r) do
    search = ~s/"#{Enum.join(r.search, ",")}"/ |> String.trim()

    ~s/#{r.name},"#{r.title}",#{r.type},#{r.year},#{r.number},#{search}/
    |> (&IO.puts(file, &1)).()
  end

  def rm_matching_title_for_all_text_search(:title, _search, results), do: {:ok, results}

  def rm_matching_title_for_all_text_search(_, search, results) do
    Enum.reduce(results, %{}, fn {k, v}, acc ->
      %{title: title} = v
      IO.puts("#{title} #{search}")

      case String.match?(String.downcase(title), ~r/#{search}/) do
        true -> acc
        _ -> Map.put(acc, k, v)
      end
    end)
    |> (&{:ok, &1}).()
  end

  @doc """
        {
          "tr", [{"class", "oddRow"}],
          [
            {"td", _, [{"a", [{"href", _path}], [var!(title)]}]},
            {"td", _, [{"a", [{"href", _path}], [var!(year_number)]}]},
            {"td", _, [_typedescription]}
          ]
        }

  """
  def process_search_table([], search, results) do
    IO.puts("Search for #{search} returned no results")
    {:ok, results}
  end

  def process_search_table([{"tbody", _, records}], search, results) do
    results =
      Enum.reduce(records, results, fn {_, _, x}, acc ->
        case process_search_table_row(x) do
          {:ok, title, type, year, number, path} ->
            name = Legl.Countries.Uk.LeglRegister.IdField.id(title, type, year, number)
            title = Legl.Airtable.AirtableTitleField.title_clean(title)
            key = String.to_atom(name)

            result =
              case Map.get(acc, key) do
                nil ->
                  %__MODULE__{
                    name: name,
                    title: title,
                    path: path,
                    type: type,
                    year: year,
                    number: number,
                    search: [search]
                  }

                result ->
                  %{result | search: [search | result.search]}
              end

            Map.put(acc, key, result)

          {:error, error} ->
            IO.puts("#{error}")
            acc

          _ ->
            acc
        end
      end)

    {:ok, results}
  end

  def process_search_table_row(row) do
    case row do
      unquote(@pattern) ->
        case Regex.run(~r/^\/([a-z]*)\/(\d{4})\/(\d+)\//, path) do
          [_, "eur", _, _] ->
            {:euro_regulation}

          [_, "eudn", _, _] ->
            {:euro_decision}

          [_, "eudr", _, _] ->
            {:euro_directive}

          [_, type, year, number] ->
            {:ok, title, type, year, number, path}

          nil ->
            case Regex.run(~r/^\/([a-z]*)\/([a-zA-Z0-9]+?\/[-\d]+?)\/(\d+)\//, path) do
              [_, type, year, number] ->
                {:ok, title, type, year, number, path}

              _ ->
                {:error, "no match against this path #{path}"}
            end
        end

      unquote(@welsh) ->
        {:welsh_law, "welsh law: #{inspect(row)}"}

      _ ->
        {:error, "error: no match "}
    end
  end
end

defmodule Legl.Countries.Uk.UkSearch.Terms do
  alias Legl.Countries.Uk.UkSearch.Terms.Environment, as: E
  alias Legl.Countries.Uk.UkSearch.Terms.HealthSafety, as: HS

  def separate_class_search_terms() do
    [hs: HS.hs_search_terms(), e: E.e_search_terms()]
  end

  def all_search_terms() do
    HS.hs_search_terms() ++ E.e_search_terms()
  end

  def compiled_search_terms() do
    Enum.map(HS.hs_search_terms(), fn {k, v} ->
      {k, :binary.compile_pattern(v)}
    end)
  end
end

defmodule Legl.Countries.Uk.UkSearch.Terms.Environment do
  @climate_change ~w[
      carbon\u00a0accounting
      climate\u00a0change
      energy\u00a0conservation
      sustainable\u00a0energy
      greenhouse\u00a0gas
      ozone\u00a0depleting
      ozone-depleting
    ]

  @general ~w[
      environmental\u00a0impact\u00a0assessment
      circular\u00a0economy
    ]

  @marine ~w[
      marine\u00a0pollution
      marine\u00a0conservation
      fish\u00a0conservation
      deep\u00a0sea\u00a0mining
      eels
      coastal\u00a0access
      river\u00a0pollution
      river\u00a0conservation
    ]

  @pollution ~w[
      control\u00a0of\u00a0pollution
      oil\u00a0pollution
      pollution\u00a0prevention
      nitrate\u00a0pollution
      prevention\u00a0of\u00a0pollution
    ]

  @waste ~w[
      waste\u00a0management
      special\u00a0waste
      hazardous\u00a0waste
      waste\u00a0incineration
      landfill
      list\u00a0of\u00a0waste
      shipment\u00a0of\u00a0waste
      waste\u00a0electrical
      packaging\u00a0waste
      controlled\u00a0waste

      contaminated\u00a0land
    ]

  @water ~w[
      water\u00a0abstraction
      water\u00a0pollution
      discharge\u00a0consent
    ]

  @wildlife_countryside ~w[
      countryside
      country\u00a0park
      national\u00a0park
      countryside\u00a0stewardship
      wildlife
      badger
      beaver
      reptile
      wild\u00a0bird
      rabbit
      weed
      ragwort
      nature\u00a0conservation
      nature\u00a0reserve
      habitat
      species
      sites\u00a0of\u00a0special\u00a0scientific\u00a0interest
      hedgerows
      biodiversity
      rights\u00a0of\u00a0way
      byway
      historic\u00a0site
      archeological\u00a0service
    ]

  def e_search_terms() do
    # putting the likely most popular matching terms first
    [
      "Climate Change": Enum.map(@climate_change, &String.replace(&1, "\u00a0", " ")),
      "Environmental Protection": Enum.map(@general, &String.replace(&1, "\u00a0", " ")),
      "Marine & Riverine": Enum.map(@marine, &String.replace(&1, "\u00a0", " ")),
      Pollution: Enum.map(@pollution, &String.replace(&1, "\u00a0", " ")),
      Waste: Enum.map(@waste, &String.replace(&1, "\u00a0", " ")),
      "Water & Wastewater": Enum.map(@water, &String.replace(&1, "\u00a0", " ")),
      "Wildlife & Countryside":
        Enum.map(@wildlife_countryside, &String.replace(&1, "\u00a0", " "))
    ]
  end
end

defmodule Legl.Countries.Uk.UkSearch.Terms.HealthSafety do
  @building_safety ~w[
    building\u00a0safety
    building\u00a0regulation
    building\u00a0standard
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @dangerous_explosive_substances ~w[
    explosive
    dangerous
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @oh_s ~w[
    health\u00a0and\u00a0safety
    accident
    consultation\u00a0of\u00a0employee
    protection\u00a0at\u00a0work
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @fire_safety ~w[
    fire
    explosive
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @food_safety ~w[
    food\u00a0safety
    contact\u00a0with\u00a0food
    hygiene
    food\u00a0irradiation
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @gas_electric_safety ~w[
    gas
    electric
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @hr_employment ~w[
    working\u00a0time
    agency\u00a0worker
    employment\u00a0right
    employment\u00a0tribunal
    employment\u00a0relation
    maternity
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @hr_pay ~w[
    mesothelioma
    pneumoconiosis
    wage
    industrial\u00a0injuries
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @hr_working_time ~w[
    working\u00a0time
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @mine_quarry_safety ~w[
    mine
    quarrie
    coal\u00a0industry
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @offshore_safety ~w[
    offshore\u00a0installation
    offshore\u00a0safety
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @patient_safety ~w[
    medical\u00a0device
    national\u00a0health\u00a0service
    nhs
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @product_safety ~w[
    product\u00a0safety
    cosmetic\u00a0products
    toys
    consumer
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @public_health ~w[
    smoking
    smoke_free
    health\u00a0protection
    care
    cqc
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @air_safety ~w[
    air\u00a0navigation
    air\u00a0traffic
    civil\u00a0aviation
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @rail_safety ~w[
    railway
    rail\u00a0vehicle
    train\u00a0driv
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @ship_safety ~w[
    harbour
    merchant\u00a0shipping
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @road_safety ~w[
    road\u00a0transport
    road\u00a0safety
    road\u00a0traffic
    road\u00a0vehicle
    motor\u00a0vehicle
    goods\u00a0vehicle
    passenger
    driver
    pedestrian
    disabled\u00a0persons’\u00a0vehicles
    parking
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  @drug_safety ~w[
    drug
    medicine
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

  def hs_search_terms() do
    # Keys are the Family names
    # putting the likely most popular matching terms first
    # Replacing \u00a0 because it will not match an empty space
    [
      "OH&S: Occupational / Personal Safety": @oh_s,
      FIRE: @fire_safety,
      FOOD: @food_safety,
      "PUBLIC: Consumer / Product Safety": @product_safety,
      "TRANS: Road Safety": @road_safety,
      "HEALTH: Public": @public_health,
      "HR: Employment": @hr_employment,
      "PUBLIC: Building Safety": @building_safety,
      "FIRE: Dangerous and Explosive Substances": @dangerous_explosive_substances,
      "GAS & ELECTRIC": @gas_electric_safety,
      "HEALTH: Drug & Medicine Safety": @drug_safety,
      "HEALTH: Patient Safety": @patient_safety,
      "HR: Insurance / Compensation / Wages / Benefits": @hr_pay,
      "TRANS: Rail Safety": @rail_safety,
      "TRANS: Ship Safety": @ship_safety,
      "OH&S: Offshore Safety": @offshore_safety,
      "HR: Working Time": @hr_working_time,
      "TRANS: Air Safety": @air_safety,
      "OH&S: Mines & Quarries": @mine_quarry_safety
    ]
  end
end

defmodule Legl.Countries.Uk.UkSearch.Terms.SICodes do
  @si_codes MapSet.new([
              "ATOMIC ENERGY AND RADIOACTIVE SUBSTANCES",
              "BUILDING AND BUILDINGS",
              "BUILDING REGULATIONS",
              "CIVIL AVIATION",
              "COAL INDUSTRY",
              "CONSUMER PROTECTION",
              "DANGEROUS DRUGS",
              "DOCKS",
              "ELECTRICITY",
              "ELECTROMAGNETIC COMPATABILITY",
              "ELECTROMAGNETIC COMPATIBILITY",
              "EMPLOYER'S LIABILITY",
              "FACTORIES",
              "FIRE AND RESCUE SERVICES",
              "FIRE PRECAUTIONS",
              "FIRE SAFETY",
              "FIRE SERVICES",
              "FOOD",
              "GAS",
              "HARBOUR",
              "HARBOURS",
              "HEALTH AND SAFETY",
              "HEALTH AND WELFARE",
              "INDUSTRIAL TRAINING",
              "MENTAL HEALTH",
              "MERCHANT SHIPPING",
              "OFFSHORE INSTALLATIONS",
              "PESTICIDES",
              "PETROLEUM",
              "PUBLIC HEALTH",
              "RADIOACTIVE SUBSTANCES",
              "RAILWAYS",
              "TERMS AND CONDITIONS OF EMPLOYMENT",
              "ROAD TRAFFIC",
              "ROAD TRAFFIC AND VEHICLES",
              "SAFETY",
              "SAFETY, HEALTH AND WELFARE"
            ])

  def si_codes(), do: @si_codes
end
