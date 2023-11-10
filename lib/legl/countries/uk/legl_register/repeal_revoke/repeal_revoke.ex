defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke do
  @moduledoc """

    Module checks the amendments table of a piece of legislation for a table row
    that describes the law as having been repealed or revoked.

    Saves the results as a .csv file with the fields given by @fields

    Example

    Legl.Countries.Uk.UkRepealRevoke.run(base_name: "UK S", type_code:
    :nia, field_content: [{"Live?_description", ""}], workflow: :create)

  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.IdField, as: ID
  alias Legl.Airtable.AirtableTitleField, as: Title
  alias Legl.Services.LegislationGovUk.Url

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.Options
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RRDescription
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.Delta

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.Patch

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Csv

  defstruct [
    :Title_EN,
    :target,
    :affect,
    :amending_title,
    :type_code,
    :Number,
    :Year,
    :path
  ]

  @doc """
  Function to update a single Legal Register Table record by Name
  """
  def single_record(opts \\ []) do
    Options.single_record_options(opts)
    |> workflow()
  end

  @doc """
    Run in iex as
     Legl.Countries.Uk.UkRepealRevoke.run()
  """
  def run(opts \\ []) do
    opts
    |> Options.set_options()
    |> workflow()
  end

  @api_post_results_path ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_post_results.json]

  @spec workflow(map()) :: :ok
  def workflow(opts) do
    records =
      AT.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)
      |> AT.strip_id_and_createdtime_fields()
      |> AT.make_records_into_legal_register_structs()

    results = workflow(records, opts)

    # UPDATED LAWS that are REVOKED / REPEALED

    Legl.Utility.maps_from_structs(results)
    |> Enum.map(&Map.put(&1, :"Live?_checked", ~s/#{Date.utc_today()}/))
    |> Legl.Utility.map_filter_out_empty_members()
    # PATCH the results to Airtable if :patch? == true
    |> Patch.patch(opts)

    if opts.csv?, do: Csv.closeFiles(opts)

    :ok
  end

  @spec workflow(list(), map()) :: list()
  def workflow(records, opts) do
    # {:ok, opts} = Options.set_options(opts)
    {records, revoking} =
      Enum.reduce(records, {[], []}, fn
        record, acc ->
          IO.puts("TITLE_EN: #{record."Title_EN"}")

          {latest_record, revoking} = get_revocations(record, opts)

          # We :update when we need a new Live? data and :delta to change_log
          result =
            case opts.workflow do
              :update ->
                latest_record

              :delta ->
                Delta.compare(record, latest_record)
            end

          {[result | elem(acc, 0)], [revoking | elem(acc, 1)]}
      end)

    # Save the new laws to json for later processing
    revoking
    |> List.flatten()
    |> Legl.Utility.save_json(
      ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_revoke.json]
    )

    records
  end

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.amendment_parser/1

  @spec get_revocations(%LegalRegister{}, map()) :: {%LegalRegister{}, list() | []}
  def get_revocations(record, opts) do
    with(
      url = Url.content_path(record),
      {:ok, html} <- RecordGeneric.leg_gov_uk_html(url, @client, @parser),
      # IO.inspect(html, label: "TABLE DATA", limit: :infinity), Process the
      # html to get a list of data tuples
      #
      # {:ok, "Consumer Protection Act 1987",
      # "s. 34", "applied (with modifications)", "The Personal Protective
      # Equipment (Enforcement) Regulations 2018", "uksi", "390", 2018,
      # "/id/uksi/2018/390"}
      data <- proc_amd_tbl(html),
      # Search and filter for the terms 'revoke' or 'repeal' returning {:ok, list} or :no_records
      # List {:ok, [{title, amendment_target, amendment_effect, amending_title&path}, ...{}]
      {:ok, rr_data} <- filter(data) |> IO.inspect(),
      # Sets the content of the revocation / repeal "Live?_description" field
      {:ok, record} <- RRDescription.live_description(rr_data, record, opts),
      # Filters for laws that have been revoked / repealed in full
      record <- full_filter(data, record, opts),
      # The Revoked_by linked record field
      {:ok, record} <- revoked_by(rr_data, record),
      {:ok, new_laws} <- new_law(rr_data)
    ) do
      {record, new_laws}
    else
      :no_records ->
        {Map.put(record, :Live?, opts.code_live), []}

      {:error, :no_records} ->
        result =
          case Map.has_key?(record, :fields) do
            true ->
              Map.merge(record[:fields], %{Live?: opts.code_live, "Live?_checked": opts.date})
              |> (&Map.put(record, :fields, &1)).()

            _ ->
              Map.put(record, :Live?, opts.code_live)
          end

        {result, []}

      {:live, result} ->
        IO.puts("LIVE: #{record."Title_EN"}\n#{inspect(result)}")

        {result, []}

      {nil, msg} ->
        IO.puts("NIL: #{record."Title_EN"}\n#{msg}\n")
        {record, []}

      {:error, code, response, _} ->
        IO.puts("#{code} #{response}")
        {record, []}

      {:error, code, response} ->
        IO.puts("#{code} #{response}")
        {record, []}

      {:error, :html} ->
        IO.puts(".html from #{record."Title_EN"}")
        {record, []}

      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
        {record, []}

      :error ->
        {record, []}
    end
  end

  @doc """
  Function processes each row of the amendment table html
  Returns a tuple:
  {:ok, title, target, effect, amending_title, path}
  where:
    Target = the part of the law that's amended eg 'reg. 2', 'Act'
    Effect = the type of amendment made eg 'words inserted', 'added'
  """
  def proc_amd_tbl([]), do: []

  def proc_amd_tbl([{"tbody", _, rows}]) do
    Enum.map(rows, fn {_, _, x} -> x end)
    |> Enum.map(&proc_amd_tbl_row(&1))
  end

  def proc_amd_tbl_row(row) do
    Enum.with_index(row, fn cell, index -> {index, cell} end)
    |> Enum.reduce([], fn
      {0, {"td", _, [{_, _, [title]}]}}, acc ->
        [title | acc]

      {1, _cell}, acc ->
        acc

      {2, {"td", _, content}}, acc ->
        # IO.inspect(content, label: "CONTENT: ")

        Enum.map(content, fn
          {"a", [{"href", _}, [v1]], [v2]} -> ~s/#{v1} #{v2}/
          {"a", [{"href", _}], [v]} -> v
          {"a", [{"href", _}], []} -> ""
          [v] -> v
          v when is_binary(v) -> v
        end)
        # |> IO.inspect(label: "AT: ")
        |> Enum.join(" ")
        |> String.trim()
        |> (&[&1 | acc]).()

      {3, {"td", _, [amendment_effect]}}, acc ->
        [amendment_effect | acc]

      {3, {"td", [], []}}, acc ->
        ["" | acc]

      {4, {"td", _, [{_, _, [amending_title]}]}}, acc ->
        [amending_title | acc]

      {5, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
        {type_code, number, year} = Legl.Utility.type_number_year(path)
        year = String.to_integer(year)
        [path, year, number, type_code | acc]

      {6, _cell}, acc ->
        acc

      {7, _cell}, acc ->
        acc

      {8, _cell}, acc ->
        acc

      {id, row}, acc ->
        IO.puts(
          "Unhandled amendment table row\nID #{id}\nCELL #{inspect(row)}\n[#{__MODULE__}.amendments_table_records]\n"
        )

        acc
    end)
    |> Enum.reverse()
    |> (&Enum.zip(
          [
            :Title_EN,
            :target,
            :affect,
            :amending_title,
            :type_code,
            :Number,
            :Year,
            :path
          ],
          &1
        )).()
    |> (&Kernel.struct(__MODULE__, &1)).()

    # |> IO.inspect(label: "DATA TUPLE: ")

    # |> IO.inspect(label: "TABLE ROW TUPLE: ")
  end

  @doc """
    Function searches using a Regex for the terms 'repeal' or 'revoke' in each amendment record

    If no repeal or revoke terms are found then :no_records is returned

    INPUT
      {:ok, "Consumer Protection Act 1987",
       "s. 34", "applied (with modifications)", "The Personal Protective
       Equipment (Enforcement) Regulations 2018", "uksi", "390", 2018,
       "/id/uksi/2018/390"}
    OUTPUT
    [
      {"Forestry Act 1967", "s. 39(5)", "repealed",
      "Requirements of Writing (Scotland) Act 1995💚️https://legislation.gov.uk/id/ukpga/1995/7"},
      {"Forestry Act 1967", "Act", "power to repealed or amended (prosp.)",
      "Government of Wales Act 1998💚️https://legislation.gov.uk/id/ukpga/1998/38"},
      ...
    ]
    ALT OUTPUT
    :no_records
  """
  @spec rr_filter(list()) :: :no_records | {:ok, list()}
  def rr_filter(records) do
    case Enum.reduce(records, [], fn x, acc ->
           case x do
             {:ok, title, amendment_target, amendment_effect, amending_title, type_code, number,
              year, path} ->
               case Regex.match?(~r/(repeal|revoke)/, amendment_effect) do
                 true ->
                   [
                     {title, amendment_target, amendment_effect, amending_title, type_code,
                      number, year, path, ~s[#{amending_title}💚️https://legislation.gov.uk#{path}]}
                     | acc
                   ]

                 false ->
                   acc
               end

             _ ->
               acc
           end
         end) do
      [] -> :no_records
      data -> {:ok, data}
    end
  end

  def filter(records) do
    Enum.filter(
      records,
      fn %{affect: affect} ->
        Regex.match?(~r/(repeal|revoke)/, affect)
      end
    )
    |> amending_title_and_path()
  end

  def amending_title_and_path([]), do: :no_records

  def amending_title_and_path(data) do
    Enum.map(
      data,
      &Map.put(
        &1,
        :amending_title_and_path,
        ~s[#{&1.amending_title}💚️https://legislation.gov.uk#{&1.path}]
      )
    )
    |> IO.inspect()
    |> (&{:ok, &1}).()
  end

  @doc """
  Function filters amendment table rows for entries describing the full revocation / repeal of a law
  """
  @spec full_filter(list(), %__MODULE__{}, map()) :: %__MODULE__{}
  def full_filter(data, struct, opts) do
    case Enum.reduce_while(data, false, fn x, acc ->
           case x do
             {:ok, _title, target, effect, _amending_title, _path}
             when target in ["Regulations", "Order", "Act"] and effect in ["revoked", "repealed"] ->
               {:halt, true}

             _ ->
               {:cont, acc}
           end
         end) do
      true -> Map.put(struct, :Live?, opts.code_full)
      false -> struct
    end
  end

  @doc """
  Function builds Name field (ID/key) and saves the result to :revoked_by
  # {"Consumer Protection Act 1987", "s. 45(4)", "repealed",
    "Trade Marks Act 1994💚️https://legislation.gov.uk/id/ukpga/1994/26"}
  """
  @spec revoked_by(list(), %__MODULE__{}) :: %__MODULE__{}
  def revoked_by(rr_data, struct) do
    rr_data
    # |> rr_filter()
    # |> elem(1)
    |> Enum.reduce([], fn {_, _, _, x}, acc ->
      x = Regex.replace(~r/\s/u, x, " ")

      [_, title] =
        case Regex.run(~r/(.*)[ ]\d*💚️/, x) do
          [_, title] ->
            [nil, title]

          _ ->
            case Regex.run(~r/(.*)[ ]\d{4}[ ]\(repealed\)💚️/, x) do
              [_, title] ->
                [nil, title]

              _ ->
                IO.puts("PROBLEM TITLE #{x}")
                [nil, x]
            end
        end

      [_, type, year, number] = Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d*)/, x)
      [ID.id(title, type, year, number) | acc]
    end)
    |> Enum.uniq()
    |> Enum.join(",")
    # |> Legl.Utility.csv_quote_enclosure()
    |> (&Map.put(struct, :Revoked_by, &1)).()
    |> (&{:ok, &1}).()
  end

  def new_law(raw_data) do
    raw_data
    |> Enum.reduce([], fn {_, _, _, x}, acc ->
      x = Regex.replace(~r/\s/u, x, " ")

      [_, title] =
        case Regex.run(~r/(.*)[ ]\d*💚️/, x) do
          [_, title] ->
            [nil, title]

          _ ->
            case Regex.run(~r/(.*)[ ]\d{4}[ ]\(repealed\)💚️/, x) do
              [_, title] ->
                [nil, title]

              _ ->
                IO.puts("PROBLEM TITLE #{x}")
                [nil, x]
            end
        end

      title =
        title
        |> Title.title_clean()

      # |> (fn x -> ~s/"#{x}"/ end).()

      [_, type, year, number] = Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d*)/, x)

      name = ID.id(title, type, year, number)

      Map.new(
        Name: name,
        Title_EN: title,
        type_code: type,
        Year: String.to_integer(year),
        Number: number
      )
      # |> (&Map.put(%{}, :fields, &1)).()

      # [id, title, type, year, number]
      # |> Enum.join(",")
      # |> (fn x -> ~s/"#{x}"/ end).()
      |> (&[&1 | acc]).()
    end)
    |> Enum.uniq()
    |> (&{:ok, &1}).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Post do
  def post([], _), do: :ok

  def post(records, opts) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    records =
      Enum.chunk_every(records, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.put(%{}, "records", set)
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(records, fn subset ->
      Legl.Services.Airtable.AtPost.post_records(subset, headers, params)
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.NewLaw do
  @moduledoc """
  Module to handle addition of new amending laws into the Base
  1. Checks existence of law (for enumeration 1+)
  2. Filters records based on absence
  3. Posts new record with amendment data to Base
  """
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  def new_law?(records, opts) do
    # Loop through the records and add a new record parameter :url
    # Record has this shape:
    # %{
    #    Name: "UK_uksi_2003_3073_RVRLAR",
    #    Number: "3073",
    #    Title_EN: "Road Vehicles (Registration and Licensing) (Amendment) (No. 4) Regulations",
    #    Year: "2003",
    #    type_code: "uksi"
    # }
    records =
      Enum.map(records, fn record ->
        options = [
          formula: ~s/{Name}="#{Map.get(record, :Name)}"/,
          fields: ["Name", "Number", "Year", "type_class"]
        ]

        {:ok, url} = Url.url(opts.base_id, opts.table_id, options)
        Map.put(record, :url, url)
      end)

    record_exists_filter(records)
  end

  def record_exists_filter(records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            Map.drop(record, [:url])
            |> (&Map.put(%{}, :fields, &1)).()
            |> (&[&1 | acc]).()

          _ ->
            acc
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR #{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Csv do
  @at_csv ~s[lib/legl/countries/uk/legl_register/repeal_revoke/repeal_revoke.csv]
          |> Path.absname()
  @rr_new_law ~s[lib/legl/countries/uk/legl_register/repeal_revoke/rr_new_law.csv]
              |> Path.absname()
  def openFiles(opts) do
    with {:ok, file} <- File.open(@at_csv, [:utf8, :write]),
         IO.puts(file, opts.fields_update),
         {:ok, file_new_law} <- File.open(@rr_new_law, [:utf8, :write]),
         IO.puts(file_new_law, opts.fields_new_law) do
      Map.merge(opts, %{file: file, file_new_law: file_new_law})
    end
  end

  def closeFiles(opts) do
    File.close(opts.file)
    File.close(opts.file_new_law)
  end

  def save_to_csv(name, %{"Live?_description": ""}, opts) do
    # no revokes or repeals
    ~s/#{name},#{opts.code_live}/ |> (&IO.puts(opts.file, &1)).()
  end

  def save_to_csv(name, %{"Live?_description": nil}, opts) do
    # no revokes or repeals
    ~s/#{name},#{opts.code_live}/ |> (&IO.puts(opts.file, &1)).()
  end

  def save_to_csv(name, r, opts) do
    # part revoke or repeal
    if "" != r."Live?_description" |> to_string() |> String.trim() do
      ~s/#{name},#{r."Live?"},#{r.revoked_by},#{r."Live?_description"}/
      |> (&IO.puts(opts.file, &1)).()
    end

    :ok
  end

  def save_new_law(new_laws, opts) do
    new_laws
    |> IO.inspect()
    |> Enum.uniq()
    |> Enum.each(fn law ->
      IO.puts(opts.file, law)
    end)
  end
end
