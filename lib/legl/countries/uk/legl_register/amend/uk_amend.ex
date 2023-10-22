defmodule Legl.Countries.Uk.UkAmend do
  @moduledoc """
  A script to list unique legislation IDs.
  Source is amending.txt and which is scrapped from the changes to legislation table in legislation.gov.uk
  Output is amends.txt
  URL is of the form https://www.legislation.gov.uk/changes/affected/ukpga/1981/69?results-count=1000&sort=affecting-year-number
  Where the results-count has all the amendments on a single page and the sort ensures affecting law is grouped
  """
  alias Types.ATLawSchema
  # alias Legl.Services.LegislationGovUk.Record
  alias Legl.Countries.Uk.LeglRegister.IdField
  alias Legl.Airtable.AirtableTitleField

  @doc """
    Parses content that has been copied from the webpage manually
  """
  @spec parse_amend :: :ok
  def parse_amend do
    binary = read_original()

    Legl.txt("amends")
    |> Path.absname()
    |> File.write("#{__MODULE__.parse(binary)}")

    String.split(binary, "\n")
    |> Enum.reduce(
      [],
      fn x, acc ->
        [amending_title, type, year, number, _, _] = line_item(x)

        IdField.id(amending_title, type, year, number)
        |> (&[&1 | acc]).()
      end
    )
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join(", ")
    |> IO.inspect()

    # |> Legl.copy()
    :ok
  end

  @amended_fields ~s[
    Name
    Title_EN
    Type
    Year
    Number
    Amendments_Checked
    Amends?
    Amended_By
  ]

  def amended_fields(), do: String.split(@amended_fields)

  def get_next_set_of_records(records, ids) do
    Enum.reduce(ids, records, fn x, acc ->
      String.to_atom(x)
      |> (&List.keydelete(acc, &1, 0)).()
    end)
  end

  def read_original do
    Legl.txt("original")
    |> Path.absname()
    |> File.read!()
  end

  @spec parse(binary) :: binary
  def parse(binary) do
    enumerable =
      String.split(binary, "\n")
      |> Enum.reduce(
        [],
        fn x, acc ->
          line_item(x)
          |> file_text()
          |> (&[&1 | acc]).()
        end
      )
      |> Enum.uniq()

    enumerable
    |> Enum.count()
    |> IO.inspect(label: "total")

    enumerable
    |> Enum.sort()
    |> Enum.join("\n")
  end

  def line_item(str) do
    {amending_title, yr_num, web} = get_record_values(String.split(str, "\t"))

    if web != "Yes" do
      IO.puts("An amendment not on legislation.gov.uk")
    end

    <<year::binary-size(4), rest::binary>> = yr_num

    {number, region, type} =
      case rest do
        " No. " <> number -> {number, "tbc", "uksi"}
        " c. " <> number -> {number, "tbc", "ukpga"}
        " asp " <> number -> {number, "Scotland", "asp"}
        " anaw " <> number -> {number, "Wales", "anaw"}
        " asc " <> number -> {number, "Scotland", "asp"}
      end

    [amending_title, year, number, region, type]
  end

  def get_record_values([
        _amended_title,
        _year,
        _changed_provision,
        _type,
        amending_title,
        yr_num,
        _affecting_provision,
        web,
        _note
      ]) do
    {amending_title, yr_num, web}
  end

  def get_record_values([
        _amended_title,
        _year,
        _changed_provision,
        _type,
        amending_title,
        yr_num,
        _affecting_provision,
        web
      ]) do
    {amending_title, yr_num, web}
  end

  def get_record_values([
        _amended_title,
        _year,
        _changed_provision,
        _type,
        amending_title,
        yr_num,
        _affecting_provision,
        web,
        _note,
        _
      ]) do
    {amending_title, yr_num, web}
  end

  @doc """
    .csv has this structure
    "Title_EN", "Geo Parent", "Region", "Year", "Number", "Type", "Amends?", "Environment?"
  """

  def make_csv_file() do
    # Create the heading
    csv_list =
      ATLawSchema.law_schema_as_list()
      |> Enum.join(", ")
      |> (&[&1 | []]).()

    # Add the records
    read_original()
    |> String.split("\n")
    |> Enum.reduce(
      csv_list,
      fn x, acc ->
        [amending_title, year, number, region, type] = line_item(x)

        amending_title =
          AirtableTitleField.remove_the(amending_title)
          |> AirtableTitleField.remove_year()
          |> escape_commas()

        amending_title
        |> IdField.id(type, year, number)
        |> (&[&1 | [amending_title, "United Kingdom", region, year, number, type, true, true]]).()
        |> Enum.join(",")
        |> (&[&1 | acc]).()
      end
    )
    |> Enum.uniq()
    |> Enum.reverse()
    |> Enum.join("\n")
    |> save_to_csv()
  end

  def save_to_csv(binary) do
    "lib/amending.csv"
    |> Path.absname()
    |> File.write(binary)

    :ok
  end

  def file_text([amending_title, type, year, number, _, _]) do
    "#{IdField.id(amending_title, type, year, number)}, #{amending_title}"
  end

  def escape_commas(str) do
    case Regex.match?(~r/,/, str) do
      true -> ~s/"#{str}"/
      _ -> str
    end
  end
end
