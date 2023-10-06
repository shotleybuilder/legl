defmodule Legl.Countries.Uk.LeglRegister.Amend do
  @moduledoc """
    iex instructions
    1. Copy Name, Title_EN, type, year, number from AT into original.txt
    2. Legl.Countries.Uk.UkAmendClient.amendment_bfs_client()
    3. csv import from amending.csv

    To run against a single record

    Legl.Countries.Uk.LeglRegister.Amend.UkAmendClient.run(base_name: "UK S",
    name: "UK_uksi_2002_2677_CSHHR", new?: false, filesave?: true, view: "")

    To run and select those records w/o a full set of amending laws use percent?:

    Legl.Countries.Uk.LeglRegister.Amend.UkAmendClient.run(base_name: "UK S",
    sClass: "Occupational / Personal Safety", percent?: true, type_class:
    :regulation, type_code: :uksi, new?: false, filesave?: true, view: "")


  """
  alias Legl.Airtable.AirtableIdField
  alias Legl.Airtable.AirtableTitleField
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Countries.Uk.UkAirtable, as: AT

  alias Legl.Countries.Uk.LeglRegister.Amend.Delta
  alias Legl.Countries.Uk.LeglRegister.Amend.Csv

  @at_csv ~s[lib/legl/countries/uk/legl_register/amend/amended_by.csv] |> Path.absname()

  @amended_fields_list ~s[
    Name
    Title_EN
    type_code
    Year
    Number
    amendments_checked
    Amended_by
    leg_gov_uk_updates
    stats_self_amending_count
    stats_amending_laws_count
    stats_amendments_count
    stats_amendments_count_per_law
    amended_by_change_log
  ] |> String.split()

  @amended_fields @amended_fields_list |> Enum.join(",")

  def amended_fields_list(), do: @amended_fields_list
  def amended_fields(), do: @amended_fields

  @default_opts %{
    name: "",
    # workflow options are [:create, :update]
    # :update triggers the update workflow and populates the change log
    workflow: :create,
    base_name: "UK E",
    type_code: [""],
    type_class: "",
    sClass: "",
    family: "",
    percent?: false,
    filesave?: false,
    # getting existing field data from Airtable
    view: "VS_CODE_AMENDMENT"
  }

  @doc """
  Function sets the optional parameters and gets one or more type_class codes
  which are used to get records from the AT Legal Register
  """
  def run(opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})

    with {:ok, type_codes} <- Legl.Countries.Uk.UkTypeCode.type_code(opts.type_code),
         {:ok, type_classes} <- Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class),
         {:ok, sClass} <- Legl.Countries.Uk.SClass.sClass(opts.sClass),
         {:ok, family} <- Legl.Countries.Uk.Family.family(opts.family),
         opts =
           Map.merge(opts, %{
             type_code: type_codes,
             type_class: type_classes,
             sClass: sClass,
             family: family
           }),
         IO.puts("OPTIONS: #{inspect(opts)}"),
         {:ok, file} <- @at_csv |> File.open([:utf8, :write]),
         IO.puts(file, @amended_fields) do
      Enum.each(type_codes, fn type ->
        IO.puts(">>>#{type}")

        IO.puts("#{formula(type, opts)}")
        opts = Map.put(opts, :fields, fields(opts))
        opts = Map.put(opts, :formula, formula(type, opts))

        full_workflow(file, opts)
      end)

      File.close(file)
    else
      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  def fields(%{workflow: :create} = _opts),
    do: ["Name", "Title_EN", "type_code", "Year", "Number"]

  def fields(%{workflow: :update} = _opts), do: @amended_fields_list

  def formula(type, %{name: ""} = opts) do
    f = if opts.workflow == :create, do: [~s/{amendments_checked}=BLANK()/], else: []
    f = if opts.workflow == :update, do: [~s/{amendments_checked}!=TODAY()/ | f], else: f
    f = if opts.type_code != [""], do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f

    f =
      if opts.percent? != false,
        do: [~s/{% Amended By}<"1.00",{stats_amending_laws_count}>"0"/ | f],
        else: f

    f =
      if opts.family != "",
        do: [~s/{Family}="#{opts.family}"/ | f],
        else: f

    f =
      if opts.sClass != "",
        do: [~s/{sClass}="#{opts.sClass}"/ | f],
        else: f

    ~s/AND(#{Enum.join(f, ",")})/
  end

  def formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end

  def full_workflow(file, opts) do
    with({:ok, current_records} <- AT.get_records_from_at(opts)) do
      {latest_records, _} =
        Enum.reduce(current_records, [], fn %{
                                              "fields" => %{
                                                "Name" => name,
                                                "Title_EN" => title,
                                                "type_code" => type,
                                                "Year" => year,
                                                "Number" => number
                                              }
                                            },
                                            acc ->
          [[name, title, type, year, number] | acc]
        end)
        |> paths()
        |> IO.inspect()
        |> (&amendment_bfs({[], &1}, file, 0)).()

      if opts.workflow == :update do
        Delta.compare(current_records, latest_records)
      end

      Csv.records_to_csv(latest_records)
    end
  end

  @enumeration_limit 2

  def recover_error() do
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, @amended_fields)

    records =
      File.read!("lib/amending.csv")
      |> String.split("\n")

    Enum.each(records, fn record ->
      [_, title, type, year, number] = Regex.run(~r/,"(.*?)",(.*?),(\d{4}),(.*?),/, record)
      name = AirtableIdField.id(title, type, year, number)
      record = Regex.replace(~r/^(.*?),/, record, "#{name},")
      IO.puts(file, record)
    end)

    File.close(file)
  end

  @doc """
    API for records copied from AT into original.txt
    Copy for following fields in this order
      Name, Title_EN, Type, Year, Number
  """
  def amendment_bfs_client() do
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, @amended_fields)

    {records, _} =
      File.read!("lib/original.txt")
      |> String.split("\n")
      |> Enum.map(&String.split(&1, "\t"))
      |> paths()
      |> (&amendment_bfs({[], &1}, file, 0)).()

    Csv.records_to_csv(records)

    File.close(file)
  end

  @doc """
    API for a single piece of law to be processed
  """
  def amendment_bfs_client(title, type, year, number) do
    path = path(type, year, number)
    amendment_bfs_client(title, path)
  end

  def amendment_bfs_client(title, path) do
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, @amended_fields)

    {records, _} = amendment_bfs({[], [{title, path}]}, file, 1)

    Csv.records_to_csv(records)

    File.close(file)
  end

  @doc """
    MapSet.new([
      {"Criminal Procedure (Scotland) Act",
      "/changes/affected/ukpga/1975/21/data.xml?results-count=1000&sort=affecting-year-number"},
      {"Parliamentary Commissioner Act",
      "/changes/affected/ukpga/1967/13/data.xml?results-count=1000&sort=affecting-year-number"}
    ])
  """
  def paths(laws) do
    Enum.reduce(laws, MapSet.new(), fn [name, title, type, year, number], acc ->
      MapSet.put(acc, {name, title, path(type, year, number)})
    end)
  end

  def paths(amended_by_laws, nlinks) do
    Enum.reduce(amended_by_laws, nlinks, fn [
                                              name,
                                              _title,
                                              amending_title,
                                              _path,
                                              type,
                                              year,
                                              number,
                                              _applied?
                                            ],
                                            acc ->
      MapSet.put(acc, {name, amending_title, path(type, year, number)})
    end)
  end

  def path(type, year, number) do
    case String.match?(number, ~r/\//) do
      false ->
        ~s[/changes/affected/#{type}/#{year}/#{number}/data.xml?results-count=1000&&sort=affecting-year-number]

      true ->
        [_, n] = Regex.run(~r/\/(\d+$)/, number)

        ~s[/changes/affected/#{type}/#{year}/#{n}/data.xml?results-count=1000&&sort=affecting-year-number]
    end
  end

  @doc """
    Breadth first search up to an arbitrary number of layers of the amendments tree
    results -> is a list of the Airtable records that get saved as a .csv for upload
    links -> is a list of the links to be followed to get more amendments

    Airtable field names are prefixed 'at_'

    csv row structure
    [
      at_name,
      at_title_en,
      at_type,
      at_year,
      at_number,
      at_amendments_checked,
      at_amended_by,
      at_leg_gov_uk_updates,
      at_stats_self_amending_count,
      at_stats_amending_laws_count,
      at_stats_amendments_count,
      at_stats_amendments_count_per_law
    ]
  """
  def amendment_bfs(data, _file, @enumeration_limit), do: data

  def amendment_bfs({results, links}, file, enumeration_limit) do
    IO.puts("enumeration #{enumeration_limit}")

    case ExPrompt.confirm("There are #{Enum.count(links)} laws in this iteration.  Continue?") do
      false ->
        # IO.inspect(results)
        {results, nil}

      true ->
        enumeration_limit = enumeration_limit + 1
        IO.puts(file, "ENUMERATION #{enumeration_limit} *******************")

        {nresults, nlinks} =
          Enum.reduce(links, {results, MapSet.new()}, fn {name, title, path},
                                                         {nresults, nlinks} ->
            {at_type, at_year, at_number} = Legl.Utility.split_name(name)

            at_name = name

            # surround the title with " in case it contains commas
            at_title_en =
              AirtableTitleField.title_clean(title)
              |> Legl.Utility.csv_quote_enclosure()

            # the 'amendments_checked' field in Airtable
            at_amendments_checked = Legl.Utility.todays_date()

            IO.puts("title: #{at_title_en} #{at_type} #{at_year} #{at_number}")

            # call to legislation.gov.uk to get the amendments
            {:ok, stats, amended_by_laws} = Record.amendments_table(path)

            # IO.inspect(amended_by_laws)

            # enumerate the amendments of the law to get the 'Amended_By' field's comma seperated string of ids
            # save into the results list

            case amended_by_laws do
              [] ->
                record = [
                  at_name,
                  at_title_en,
                  at_type,
                  at_year,
                  at_number,
                  at_amendments_checked,
                  [],
                  nil,
                  0,
                  0,
                  0,
                  0
                ]

                Enum.join(record, ",") |> (&IO.puts(file, &1)).()

                {[record | nresults], nlinks}

              _ ->
                at_amended_by = at_amended_by(amended_by_laws)
                at_leg_gov_uk_updates = at_leg_gov_uk_updates(amended_by_laws)
                # stats
                at_stats_self_amending_count = stats.self
                at_stats_amendments_count = stats.amendments
                at_stats_amending_laws_count = count_amending_laws(amended_by_laws)
                at_stats_amendments_count_per_law = stats.counts

                record = [
                  at_name,
                  at_title_en,
                  at_type,
                  at_year,
                  at_number,
                  at_amendments_checked,
                  at_amended_by,
                  at_leg_gov_uk_updates,
                  at_stats_self_amending_count,
                  at_stats_amending_laws_count,
                  at_stats_amendments_count,
                  at_stats_amendments_count_per_law
                ]

                Enum.join(record, ",") |> (&IO.puts(file, &1)).()

                nresults = [record | nresults]

                # Using a MapSet means we eliminate any duplicate amending law links
                nlinks =
                  Enum.reduce(amended_by_laws, nlinks, fn [
                                                            _title,
                                                            amending_title,
                                                            _path,
                                                            type,
                                                            year,
                                                            number,
                                                            _applied?
                                                          ],
                                                          acc ->
                    name = AirtableIdField.id(amending_title, type, year, number)
                    path = path(type, year, number)
                    MapSet.put(acc, {name, amending_title, path})
                  end)

                # IO.inspect(nlinks)
                # IO.inspect(nresults)
                {nresults, nlinks}
            end
          end)

        # IO.inspect(nlinks, limit: :infinity)
        # IO.inspect(nresults, limit: :infinity)

        # Let's not process laws that might have been already processed
        nlinks = MapSet.difference(nlinks, MapSet.new(links))
        # IO.inspect(nlinks, limit: :infinity)

        # IO.inspect(nlinks)
        params = {nresults, nlinks}

        amendment_bfs(params, file, enumeration_limit)
    end
  end

  @doc """
    Content of the Airtable Amended_By field.
    A comma separated list within quote marks of the Airtable ID field (Name).
    "UK_ukpga_2010_41_abcd,UK_uksi_2013_57_abcd"
  """
  def at_amended_by(amended_by_laws) do
    Enum.map(amended_by_laws, fn [_title, amending_title, _path, type, year, number, _applied?] ->
      AirtableIdField.id(amending_title, type, year, number)
    end)
    |> Enum.sort()
    |> Enum.join(", ")
    |> Legl.Utility.csv_quote_enclosure()
  end

  @doc """
    Content of the Airtable leg_gov_uk_updates field
    A comma separated list of options that are transformed into multi-select options.
    "Yes, No, See Notes"
  """
  def at_leg_gov_uk_updates(amended_by_laws) do
    Enum.flat_map(amended_by_laws, fn [
                                        _title,
                                        _amending_title,
                                        _path,
                                        _type,
                                        _year,
                                        _number,
                                        applied?
                                      ] ->
      applied?
    end)
    |> Enum.uniq()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
  end

  defmodule AmendmentStats do
    defstruct [:self, :laws, :amendments, :counts]
  end

  def pre_uniq_summary_amendment_stats(records) do
    stats =
      count_amendments(records)
      |> (&%{%AmendmentStats{} | amendments: &1}).()

    stats =
      count_self_amendments(records)
      |> (&%{stats | self: &1}).()

    stats =
      amendment_ids(records)
      |> count_amendments_for_each_law(records)
      |> (&%{stats | counts: &1}).()

    counts = at_stats_amendments_count_per_law(stats)

    %{stats | counts: counts}
  end

  @doc """
    <name> <count>
    <anme> <count>
  """
  def at_stats_amendments_count_per_law(nil), do: "no amendments"

  def at_stats_amendments_count_per_law(stats) do
    counts =
      Enum.map(stats.counts, fn {linked_record_name, count} ->
        "#{linked_record_name} - #{count}"
      end)
      |> Enum.join("💚️")

    Legl.Utility.csv_quote_enclosure(counts)
  end

  def amendment_ids(records) do
    uniq_by_amending_title(records)
    |> Enum.map(fn [_, amending_title, _, type, year, number, _] ->
      AirtableIdField.id(amending_title, type, year, number)
    end)
  end

  def count_self_amendments(records) do
    Enum.reduce(records, 0, fn [title, amending_title, _, _, _, _, _], acc ->
      if title == amending_title do
        acc + 1
      else
        acc
      end
    end)
  end

  def count_amendments(records) do
    Enum.count(records)
  end

  def count_amending_laws(records) do
    uniq_by_amending_title(records)
    |> Enum.count()
  end

  def count_amendments_for_each_law(ids, records) do
    counts =
      group_by_amending_title(records)
      |> Enum.map(fn x ->
        Enum.count(x)
      end)

    Enum.zip(ids, counts)
    # sort descending using the value of count
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  def uniq_by_amending_title(records) do
    Enum.uniq_by(
      records,
      fn [_title, amending_title, _path, _type, _year, _number, _applied?] -> amending_title end
    )
  end

  def group_by_amending_title(records) do
    # create a list of the uniq titles in the records
    uniq_titles = uniq_by_amending_title(records)

    Enum.map(uniq_titles, fn [_title, amending_title, _path, _type, _year, _number, _applied?] ->
      Enum.reduce(records, [], fn [
                                    _title,
                                    amending_title2,
                                    _path,
                                    _type,
                                    _year,
                                    _number,
                                    _applied?
                                  ] = x,
                                  acc ->
        if amending_title == amending_title2 do
          [x | acc]
        else
          acc
        end
      end)
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Delta do
  @moduledoc """
  Module compares the content of the following fields against the latest data @leg.gov.uk
  stats_amendments_count
  stats_amending_laws_count
  stats_amendments_count_per_law

  Generates a amended_by_change_log field to capture the differences
  """
  alias Legl.Countries.Uk.LeglRegister.Amend

  @field_paddings %{
    :stats_amendments_count => 10,
    :stats_amending_laws_count => 8,
    :stats_amendments_count_per_law => 6
  }
  @compare_fields ~w[
    leg_gov_uk_updates
    stats_amendments_count
    stats_amending_laws_count
    stats_amendments_count_per_law
    stats_self_amending_count
    ] |> Enum.map(&String.to_atom(&1))

  def amended_fields() do
    Enum.map(Amend.amended_fields_list(), &String.to_atom(&1))
  end

  def compare(current_records, latest_records) do
    # convert keys from strings to atoms
    current_records =
      Enum.map(current_records, fn record ->
        record =
          for {key, val} <- record, into: %{} do
            {String.to_atom(key), val}
          end

        fields =
          for {key, val} <- record.fields, into: %{} do
            {String.to_atom(key), val}
          end

        %{record | fields: fields}
      end)

    latest_records_as_maps =
      Enum.map(latest_records, fn latest_record ->
        Enum.zip(amended_fields(), latest_record)
      end)
      |> Enum.map(fn record ->
        Enum.reduce(record, %{}, fn {k, v}, acc -> Map.put(acc, k, v) end)
      end)

    Enum.zip(current_records, latest_records_as_maps)
    |> Enum.map(fn {current, latest} ->
      current = %{current | fields: Map.put_new(current.fields, :amended_by_change_log, "")}
      latest = Map.put_new(latest, :amended_by_change_log, "")
      {current, %{id: current.id, fields: latest}}
    end)
    |> Enum.map(fn {current, latest} ->
      compare_fields(current.fields, latest.fields)
    end)
    |> IO.inspect()
  end

  def compare_fields(current_fields, latest_fields) do
    Enum.reduce(@compare_fields, [], fn field, acc ->
      current = Map.get(current_fields, field)
      latest = Map.get(latest_fields, field)

      case changed?(current, latest) do
        false ->
          acc

        value ->
          Keyword.put(acc, field, value)
      end
    end)
    |> amended_by_change_log()
    |> (&Kernel.<>(current_fields.amended_by_change_log, &1)).()
    |> String.trim_leading("📌")
  end

  defp amended_by_change_log([]), do: ""

  defp amended_by_change_log(changes) do
    IO.inspect(changes)
    # Returns the metadata changes as a formated multi-line string
    date = Date.utc_today()
    date = ~s(#{date.day}/#{date.month}/#{date.year})

    Enum.reduce(changes, ~s/📌#{date}📌/, fn {k, v}, acc ->
      # width = 80 - string_width(k)
      width = Map.get(@field_paddings, k)
      k = ~s/#{k}#{Enum.map(1..width, fn _ -> "." end) |> Enum.join()}/
      # k = String.pad_trailing(~s/#{k}/, width, ".")
      ~s/#{acc}#{k}#{v}📌/
    end)
    |> String.trim_trailing("📌")
  end

  defp changed?(current, latest) when current in [nil, "", []] and latest not in [nil, "", []] do
    case current != latest do
      false ->
        false

      true ->
        ~s/New value/
    end
  end

  defp changed?(_, latest) when latest in [nil, "", []], do: false

  defp changed?(current, latest) when is_list(current) and is_list(latest) do
    case current != latest do
      false ->
        false

      true ->
        ~s/#{Enum.join(current, ", ")} -> #{Enum.join(latest, ", ")}/
    end
  end

  defp changed?(current, current), do: false

  defp changed?(current, latest), do: "#{current} -> #{latest}"
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Csv do
  alias Legl.Countries.Uk.LeglRegister.Amend

  def records_to_csv([]), do: :ok

  def records_to_csv(records) do
    records
    |> Enum.uniq()
    # |> (&([@amended_fields | &1])).()
    |> Enum.map(fn x -> Enum.join(x, ",") end)
    |> (&[Amend.amended_fields() <> "\n" | &1]).()
    |> Enum.join("\n")
    |> save_to_csv()
  end

  def save_to_csv(binary) do
    "lib/amending.csv"
    |> Path.absname()
    |> File.write(binary)

    :ok
  end
end
