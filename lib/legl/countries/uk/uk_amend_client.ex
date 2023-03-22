defmodule Legl.Countries.Uk.UkAmendClient do

  @moduledoc """
    iex instructions
    1. Copy Name, Title_EN, type, year, number from AT into original.txt
    2. Legl.Countries.Uk.UkAmendClient.amendment_bfs_client()
    3. csv import from amending.csv

  """
  alias Legl.Airtable.AirtableIdField
  alias Legl.Airtable.AirtableTitleField
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Countries.Uk.UkAirtable, as: AT

  @at_csv "airtable_amending"

  @amended_fields ~s[
    Name
    Title_EN
    Type
    Year
    Number
    Amendments_Checked
    Amended_By
    leg_gov_uk_updates
    stats_self_amending_count
    stats_amending_laws_count
    stats_amendments_count
    stats_amendments_count_per_law
  ] |> String.split() |> Enum.join(",")

  @at_type %{
    ukpga: ["ukpga"],
    uksi: ["uksi"],
    ni: ["nia", "apni", "nisi", "nisr", "nisro"],
    nisr: ["nisr"],
    s: ["asp", "ssi"],
    uk: ["ukpga", "uksi"],
    w: ["asc", "anaw", "mwa", "wsi"],
    o: ["ukcm", "ukla", "asc", "ukmo", "apgb", "aep"]
  }

  @default_opts %{
    fields: ["Name", "Title_EN", "type_code", "Year", "Number"],
    view: "AMENDMENT"
  }

  def open_file() do
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, @amended_fields)
    file
  end

  def run(t) when is_atom(t) do
    case Map.get(@at_type, t) do
      nil -> IO.puts("ERROR with option")
      types -> run(types)
    end
  end
  def run(types) when is_list(types) do
    file = open_file()
    Enum.each(types, fn type ->
      IO.puts(">>>#{type}")
      opts = [formula: ~s/AND({type_code}="#{type}",{Amendments_Checked}=BLANK())/]
      full_workflow(file, opts)
    end)
    File.close(file)
  end

  def full_workflow(file, opts \\ []) do
    #formula = ~s/AND({type_code}="#{type}",{Live?}=BLANK())/
    #formula = ~s/{type_code}="#{type}"/

    opts = Enum.into(opts, @default_opts)

    #func = &__MODULE__.make_csv_workflow/3
    with(
      {:ok, records} <- AT.get_records_from_at(opts)
    ) do
      {records, _} =
        Enum.reduce(records, [],
          fn %{"fields" =>
            %{
              "Name" => name,
              "Title_EN" => title,
              "type_code" => type,
              "Year" => year,
              "Number" => number
            }}, acc ->
          [[name, title, type, year, number] | acc]
        end)
        |> paths()
        |> (&(amendment_bfs({[], &1}, file, 0))).()
      records_to_csv(records)
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
      |> (&(amendment_bfs({[], &1}, file, 0))).()
    records_to_csv(records)

    File.close(file)
  end
  @doc """
    API for a single piece of law to be processed
  """
  def amendment_bfs_client(title, type, year, number) do
    path = path(type,year,number)
    amendment_bfs_client(title, path)
  end

  def amendment_bfs_client(title, path) do

    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, @amended_fields)

    {records, _} = amendment_bfs( {[], [{title, path}]}, file, 1)
    records_to_csv(records)

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
    Enum.reduce(amended_by_laws, nlinks, fn [name, _title, amending_title, _path, type, year, number, _applied?], acc ->
      MapSet.put(acc, {name, amending_title, path(type, year, number)})
    end)
  end

  def path(type, year, number) do
    case String.match?(number, ~r/\//) do
      :false -> ~s[/changes/affected/#{type}/#{year}/#{number}/data.xml?results-count=1000&&sort=affecting-year-number]
      :true ->
        [_, n] = Regex.run(~r/\/(\d+$)/, number)
        ~s[/changes/affected/#{type}/#{year}/#{n}/data.xml?results-count=1000&&sort=affecting-year-number]
    end
  end

  def records_to_csv([]), do: :ok
  def records_to_csv(records) do
    records
    |> Enum.uniq()
    #|> (&([@amended_fields | &1])).()
    |> Enum.map(fn x -> Enum.join(x, ",") end)
    |> (&([@amended_fields<>"\n" | &1])).()
    |> Enum.join("\n")
    |> save_to_csv()
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
        #IO.inspect(results)
        {results, nil}
      true ->
        enumeration_limit = enumeration_limit + 1
        IO.puts(file, "ENUMERATION #{enumeration_limit} *******************")

        {nresults, nlinks} =
          Enum.reduce(links, {results, MapSet.new()}, fn {name, title, path}, {nresults, nlinks} ->

            {at_type, at_year, at_number} = Legl.Utility.split_name(name)

            at_name = name

            # surround the title with " in case it contains commas
            at_title_en =
              AirtableTitleField.title_clean(title)
              |> Legl.Utility.csv_quote_enclosure()

            # the 'Amendments_Checked' field in Airtable
            at_amendments_checked = Legl.Utility.todays_date()

            IO.puts("title: #{at_title_en} #{at_type} #{at_year} #{at_number}")

            # call to legislation.gov.uk to get the amendments
            {:ok, stats, amended_by_laws} = Record.amendments_table(path)

            # enumerate the amendments of the law to get the 'Amended_By' field's comma seperated string of ids
            # save into the results list

            case amended_by_laws do
              [] ->
                record =
                  [
                    at_name, at_title_en, at_type, at_year, at_number, at_amendments_checked, [], nil, 0, 0, 0, 0
                  ]

                Enum.join(record, ",") |> (&(IO.puts(file, &1))).()

                {[record | nresults], nlinks}

              _ ->
                at_amended_by = at_amended_by(amended_by_laws)
                at_leg_gov_uk_updates = at_leg_gov_uk_updates(amended_by_laws)
                #stats
                at_stats_self_amending_count = stats.self
                at_stats_amendments_count = stats.amendments
                at_stats_amending_laws_count = count_amending_laws(amended_by_laws)
                at_stats_amendments_count_per_law = stats.counts

                record =
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

                Enum.join(record, ",") |> (&(IO.puts(file, &1))).()

                nresults = [record | nresults]

                #Using a MapSet means we eliminate any duplicate amending law links
                nlinks =
                  Enum.reduce(amended_by_laws, nlinks, fn [_title, amending_title, _path, type, year, number, _applied?], acc ->
                      name = AirtableIdField.id(amending_title, at_type, at_year, at_number)
                      path = path(type, year, number)
                      MapSet.put(acc, {name, amending_title, path})
                  end)
                #IO.inspect(nlinks)
                #IO.inspect(nresults)
                {nresults, nlinks}
            end
          end)

        #IO.inspect(nlinks, limit: :infinity)
        #IO.inspect(nresults, limit: :infinity)

        #Let's not process laws that might have been already processed
        nlinks = MapSet.difference(nlinks, MapSet.new(links))
        #IO.inspect(nlinks, limit: :infinity)

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
    Enum.flat_map(amended_by_laws, fn [_title, _amending_title, _path, _type, _year, _number, applied?] ->
      applied?
    end)
    |> Enum.uniq()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
  end

  def save_to_csv(binary) do
    "lib/amending.csv"
    |> Path.absname()
    |> File.write(binary)
    :ok
  end

  defmodule AmendmentStats do
    defstruct [:self, :laws, :amendments, :counts]
  end

  def pre_uniq_summary_amendment_stats(records) do
    stats =
      count_amendments(records)
      |> (&(%{%AmendmentStats{} | amendments: &1})).()

    stats =
      count_self_amendments(records)
      |> (&(%{stats | self: &1})).()

    stats =
      amendment_ids(records)
      |> count_amendments_for_each_law(records)
      |> (&(%{stats | counts: &1})).()

    counts =
      at_stats_amendments_count_per_law(stats)

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
      if title == amending_title do acc + 1 else acc end
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
    Enum.uniq_by(records,
      fn [_title, amending_title, _path, _type, _year, _number, _applied?] -> amending_title
    end)
  end

  def group_by_amending_title(records) do

    #create a list of the uniq titles in the records
    uniq_titles = uniq_by_amending_title(records)

    Enum.map(uniq_titles, fn [_title, amending_title, _path, _type, _year, _number, _applied?] ->
      Enum.reduce(records, [],
      fn [_title, amending_title2, _path, _type, _year, _number, _applied?] = x, acc ->
        if amending_title == amending_title2 do
          [x | acc]
        else
          acc
        end
      end)
    end)
  end

end
