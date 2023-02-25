defmodule Legl.Countries.Uk.UkAmendClient do

  @moduledoc """

  """
  alias Legl.Airtable.AirtableIdField
  alias Legl.Airtable.AirtableTitleField
  alias Legl.Services.LegislationGovUk.Record

  @amended_fields ~s[
    Name
    Title_EN
    Type
    Year
    Number
    Amendments_Checked
    Amended_By
    leg_gov_uk_updates
    Amendment_Stats
  ]
  @enumeration_limit 2

  def amended_fields(), do: String.split(@amended_fields)

  def amendment_bfs_client(title, path) do
    {records, _} = amendment_bfs( {[], [{title, path}]}, 0)
    records
    |> Enum.uniq()
    |> (&([amended_fields() | &1])).()
    |> Enum.map(fn x -> Enum.join(x, ",") end)
    |> Enum.join("\n")
    |> save_to_csv()
  end

  @doc """
    Breadth first search up to an arbitrary number of layers of the amendments tree
    results -> is a list of the Airtable records that get saved as a .csv for upload
    links -> is a list of the links to be followed to get more amendments

    Airtable field names are prefixed 'at_'
  """
  def amendment_bfs(data, @enumeration_limit), do: data
  def amendment_bfs({results, links}, enumeration_limit) do

    IO.puts("enumeration #{enumeration_limit}")

    enumeration_limit = enumeration_limit + 1

    {nresults, nlinks} =
      Enum.reduce(links, {results, MapSet.new()}, fn {title, path}, {nresults, nlinks} ->

        [_, at_type, at_year, at_number] =
          Regex.run(~r/\/changes\/affected\/([a-z]+?)\/(\d{4})\/(\d+)\/data\.xml\?results-count=1000&sort=affecting-year-number/, path)

        at_name = AirtableIdField.id(title, at_type, at_year, at_number)

        # surround the title with " in case it contains commas
        at_title_en = ~s/"#{AirtableTitleField.title_clean(title)}"/ #Regex.replace(~r/,/m, title, ":")

        # the 'Amendments_Checked' field in Airtable
        at_date = Legl.Utility.todays_date()

        IO.puts("title: #{at_title_en} #{at_type} #{at_year} #{at_number}")

        # call to legislation.gov.uk to get the amendments
        {:ok, stats, amended_by_laws} = Record.amendments_table(path)

        summary_amendment_stats = summary_amendment_stats(stats, amended_by_laws)

        # enumerate the amendments of the law to get the 'Amended_By' field's comma seperated string of ids
        # save into the results list

        case amended_by_laws do
          [] ->
            {[[at_name, at_title_en, at_type, at_year, at_number, at_date, [] ] | nresults], nlinks}
          _ ->
            at_amended_by =
              Enum.map(amended_by_laws, fn [_title, amending_title, _path, type, year, number, _applied?] ->
                AirtableIdField.id(amending_title, type, year, number)
              end)
              |> Enum.sort()
              |> Enum.join(", ")

            at_leg_gov_uk_updates =
              Enum.flat_map(amended_by_laws, fn [_title, _amending_title, _path, _type, _year, _number, applied?] ->
                applied?
              end)
              |> Enum.uniq()
              |> Enum.join(",")

            at_leg_gov_uk_updates = ~s/"#{at_leg_gov_uk_updates}"/

            nresults =
              ~s/"#{at_amended_by}"/
              |> (&[[at_name, at_title_en, at_type, at_year, at_number, at_date, &1, at_leg_gov_uk_updates, summary_amendment_stats] | nresults]).()

            #Using a MapSet means we eliminate any duplicate amending law links
            nlinks =
              Enum.reduce(amended_by_laws, nlinks, fn [_title, amending_title, _path, type, year, number, _applied?], acc ->
                  MapSet.put(acc, {amending_title, "/changes/affected/#{type}/#{year}/#{number}/data.xml?results-count=1000&sort=affecting-year-number"})
              end)
            #IO.inspect(nlinks)
            #IO.inspect(nresults)
            {nresults, nlinks}
        end
      end)

    #Let's not process laws that might have been already processed
    params = {nresults, MapSet.difference(nlinks, MapSet.new(links))}

    amendment_bfs(params, enumeration_limit)

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

    amendment_ids(records)
    |> count_amendments_for_each_law(records)
    |> (&(%{stats | counts: &1})).()

  end

  @doc """
    Create an amendment description.

    :self amendments: <count>
    total amending laws: <count>
    total separate amendments: <count>
    <name> <count>
    <anme> <count>
  """
  def summary_amendment_stats(nil, _), do: "no amendments"
  def summary_amendment_stats(stats, records) do

    stats =
    count_amending_laws(records)
    |> (&(%{stats | laws: &1})).()

    counts =
      Enum.map(stats.counts, fn {x, y} ->
        "#{x} - #{y}"
      end)
      |> Enum.join("\n")

    [
    ":self amendments - #{stats.self}",
    "number of amending laws - #{stats.laws}",
    "total number of amendments made - #{stats.amendments}",
    "#{counts}"
    ]
    |> Enum.join("\n")

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
  end

  def uniq_by_amending_title(records) do
    Enum.uniq_by(records, fn [_title, amending_title, _path, _type, _year, _number, _applied?] -> amending_title end)
  end

  def group_by_amending_title(records) do

    #create a list of the uniq titles in the records
    uniq_titles = uniq_by_amending_title(records)

    Enum.map(uniq_titles, fn [_title, amending_title, _path, _type, _year, _number, _applied?] ->
      Enum.reduce(records, [], fn [_title, amending_title2, _path, _type, _year, _number, _applied?] = x, acc ->
        if amending_title == amending_title2 do
          [x | acc]
        else
          acc
        end
      end)
    end)
  end

end
