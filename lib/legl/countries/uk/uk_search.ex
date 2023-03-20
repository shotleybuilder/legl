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

  @climate_change [
    ~w[
      climate\u00a0change
      energy\u00a0conservation
      sustainable\u00a0energy
      greenhouse\u00a0gas
      ozone\u00a0depleting
      ozone-depleting
    ]
  ]

  @general [
    ~w[
      environmental\u00a0impact\u00a0assessment
    ],
    ~w[
      circular\u00a0economy
    ]
  ]

  @marine [
    ~w[
      marine\u00a0pollution
      marine\u00a0conservation
      fish\u00a0conservation
      deep\u00a0sea\u00a0mining
      eels
    ],
    ~w[
      coastal\u00a0access
    ],
    ~w[
      river\u00a0pollution
      river\u00a0conservation
    ]
  ]

  @pollution [
    ~w[
      control\u00a0of\u00a0pollution
      oil\u00a0pollution
      pollution\u00a0prevention
      nitrate\u00a0pollution
      prevention\u00a0of\u00a0pollution
    ]
  ]

  @waste [
    ~w[
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
    ],
    ~w[
      contaminated\u00a0land
    ]
  ]

  @water [
    ~w[
      water\u00a0abstraction
      water\u00a0pollution
      discharge\u00a0consent
    ]
  ]

  @wildlife_countryside [
    ~w[
      countryside
      country\u00a0park
      national\u00a0park
      countryside\u00a0stewardship
    ],
    ~w[
      wildlife
      badger
      beaver
      reptile
      wild\u00a0bird
      rabbit
    ],
    ~w[
      weed
      ragwort

    ],
    ~w[
      nature\u00a0conservation
      nature\u00a0reserve
      habitat
      species
      sites\u00a0of\u00a0special\u00a0scientific\u00a0interest
      hedgerows
      biodiversity
    ],
    ~w[
      rights\u00a0of\u00a0way
      byway
    ],
    ~w[
      historic\u00a0site
      archeological\u00a0service
    ]
  ]

  def search_terms() do
    %{
      search_type: :title,
      climate_change: @climate_change,
      general: @general,
      marine: @marine,
      pollution: @pollution,
      waste: @waste,
      water: @water,
      wildlife_countryside: @wildlife_countryside
    }
  end

  @pattern quote do: [
    {"td", _, [{"a", [{"href", _}], [var!(title)]}]},
    {"td", _, [{"a", [{"href", var!(path)}], [var!(_year_number)]}]},
    {"td", _, [_type_description]}
  ]

  @welsh quote do: [
    {"td", [{"class", "bilingual cy"}], [{"a", [{"href", var!(_path)}, _], [var!(_title)]}]}]

  @doc """
    To run the saved searches use
      Legl.Countries.Uk.UkSearch.run(:waste)
    To search inside the content
      Legl.Countries.Uk.UkSearch.run(:waste, %{search_type: :all})
    To run a tailored search
      Legl.Countries.Uk.UkSearch.run(:waste, %{waste: [["waste"]], search_type: :title})
  """
  def run(search, opts \\ []) do
    opts = Enum.into(opts, search_terms())
    #IO.inspect(opts)
    search_set = Map.get(opts, search) #|> IO.inspect()
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, "Name,Title_EN,type_code,year,number,search")
    results =
      Enum.reduce(search_set, %{}, fn search_terms, acc ->
        workflow(search_terms, opts.search_type, acc)
      end)
    Enum.each(results, fn {_k, v} ->
      save_to_csv(file, v)
    end)
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
      get_search_results(url, search, acc)
    end)
  end

  def get_search_results(url, search, results) do
    with(
      IO.puts("#{url}"),
      {:ok, table_data} <- RecordGeneric.leg_gov_uk_html(url, @client, @parser),
      {:ok, results} <- process_search_table(table_data, search, results)
    ) do
      #IO.inspect(result)
      results
    else
      {:error, code, _url, error} ->
        IO.puts("#{code} #{error} #{search}")
        results
    end
  end

  def save_to_csv(file, r) do
    search = ~s/"#{Enum.join(r.search, ",")}"/ |> String.trim
    ~s/#{r.name},"#{r.title}",#{r.type},#{r.year},#{r.number},#{search}/
    |> (&(IO.puts(file, &1))).()
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
      Enum.reduce(records, results, fn{_, _, x}, acc ->
        case process_search_table_row(x) do
          {:ok, title, type, year, number, path} ->

            name = Legl.Airtable.AirtableIdField.id(title, type, year, number)
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
                result -> %{result | search: [search | result.search]}
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
      unquote (@pattern) ->
        case Regex.run(~r/^\/([a-z]*)\/(\d{4})\/(\d+)\//, path) do
          [_, "eur", _, _] -> {:euro_regulation}
          [_, "eudn", _, _] -> {:euro_decision}
          [_, "eudr", _, _] -> {:euro_directive}
          [_, type, year, number] -> {:ok, title, type, year, number, path}
          nil ->
            case Regex.run(~r/^\/([a-z]*)\/([a-zA-Z0-9]+?\/[-\d]+?)\/(\d+)\//, path) do
              [_, type, year, number] -> {:ok, title, type, year, number, path}
              _ ->
                {:error, "no match against this path #{path}"}
            end
        end
      unquote (@welsh) ->
        {:welsh_law, "welsh law: #{inspect(row)}"}
      _ ->
        {:error, "error: no match "}
    end
  end

end
