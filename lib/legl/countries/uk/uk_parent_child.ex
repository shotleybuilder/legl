defmodule Legl.Countries.Uk.UkParentChild do

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.RecordEnactingText

  def get_child_process(base_name) do
    with {:ok, recordset} <- get_at_records_with_empty_child(base_name),
      {:ok, recordset} <- get_child_laws_from_leg_gov_uk(recordset),
      {:ok, count } <- make_csv(recordset)
    do
      IO.puts("csv saved with #{count} records")
      :ok
    else
      {:error, error} -> IO.puts("#{error}")
    end
  end

  def get_at_records_with_empty_child(base_name) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
          fields: ["Name", "Title_EN", "Type", "Year", "Number", "Child of"],
          formula: ~s/{Child of}=""/}
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      IO.puts("Records returned from Airtable")
      IO.inspect(recordset)
      {:ok, recordset}
    else
      {:error, error} -> {:error, error}
    end
  end

  def get_child_laws_from_leg_gov_uk(records) do
    #records =
    Enum.into(records, [],
      fn %{"fields" => %{"Type" => type, "Year" => year, "Number" => number}} = x ->
        path = introduction_path(type, year, number)
        response =
          case get_parent(path) do
            {:ok, response} -> response
            {:error, error} ->
              IO.inspect(error, label: "leg.gov.uk: ERROR: ")
              "ERROR #{error}"
          end
        {:ok, enacting_laws} = parse_enacting_text(response)
        enacting_laws = Map.merge(x["fields"], enacting_laws)
        %{x | "fields" => enacting_laws}
    end)
    |> (&{:ok, &1}).()
  end
  @doc """
    Parses xml containing clauses with the following patterns:

    The Secretary of State, in exercise of the powers conferred by sections 38 and 51(1)
    of the Fisheries Act 2020 <FootnoteRef Ref="f00001"/>, makes the following Regulations.

    The Secretary of State makes the following Order in exercise of the powers conferred by
    regulation 143(1) of the Conservation of Habitats and Species Regulations 2017 <FootnoteRef Ref="f00001"/>
    (“<Term id="term-the-2017-regulations">the 2017 Regulations</Term>”) and section 22(5)(a) of the
    Wildlife and Countryside Act 1981 <FootnoteRef Ref="f00002"/> (“<Term id="term-the-act">the Act</Term>”).

    The key elements being the phrase "conferred by" and the footnote references.
  """
  def get_parent(path) do
    case RecordEnactingText.enacting_text(path) do
      {:ok, :xml, response} ->
        {:ok, response}
      {:ok, :html} -> {:ok, "not found"}
      {:error, _code, error} -> {:error, error}
    end
  end

  def parse_enacting_text(%{enacting_text: enacting_text, urls: urls} = response) do
    [_, txt] = Regex.run(~r/powers[ ]conferred[ a-z]*?by(.*)$/, enacting_text)
    IO.inspect(txt)
    matches = Regex.scan(~r/f\d{5}/m, txt)
    IO.inspect(matches)
    urls =
      Enum.map(matches, fn [x] ->
        Map.get(urls, x) |> to_string()
      end)
    IO.inspect(urls)
    parents =
      Enum.reduce(urls, [], fn x, acc ->
        case x do
          "" -> acc
          _ ->
            [_, type, year, number] =
              Regex.run(~r/http:\/\/www.legislation.gov.uk\/id\/([a-z]*?)\/(\d{4})\/(\d+)$/, x)
            {:ok, title} =
              introduction_path(type, year, number)
              |> get_title()
            [{title, type, year, number} | acc]
        end
      end)
    {:ok, Map.put_new(response, :enacting_laws, parents)}
  end

  def get_title(path) do
    case Legl.Services.LegislationGovUk.Record.legislation(path) do
      {:ok, :xml, %{metadata: %{title: title}}} ->
        {:ok, title}
      {:ok, :html} -> {:ok, "not found"}
      {:error, _code, error} -> {:error, error}
    end
  end

  defp introduction_path(type, year, number) do
     "/#{type}/#{year}/#{number}/introduction/made/data.xml"
  end


  def make_csv(records) do
    Enum.reduce(records, [],
      fn %{
        "fields" =>
        %{
          "Name" => name,
          "Title_EN" => title,
          "Type" => type,
          "Year" => year,
          "Number" => number,
          enacting_laws: enacting_laws
        }
        } = _law, acc ->
        at_parent = at_parent(enacting_laws)
        [~s/#{name}, #{title}, #{type}, #{year}, #{number},#{at_parent}/ | acc]
        |> new_acting_laws(enacting_laws)
    end)
    |> field_names()
    |> Enum.join("\n")
    |> save_to_csv("lib/amending.csv")
  end

  def save_to_csv(binary, filename) do
    line_count = binary |> String.graphemes |> Enum.count(& &1 == "\n")
    filename
    |> Path.absname()
    |> File.write(binary)
    {:ok, line_count}
  end
  @doc """
    Content of the Airtable Parent field.
    A comma separated list within quote marks of the Airtable ID field (Name).
    "UK_ukpga_2010_41_abcd,UK_uksi_2013_57_abcd"
  """
  def at_parent(enacting_laws) do
    Enum.map(enacting_laws, fn {title, type, year, number} ->
      Legl.Airtable.AirtableTitleField.title_clean(title)
      |> Legl.Airtable.AirtableIdField.id(type, year, number)
    end)
    |> Enum.sort()
    |> Enum.join(", ")
    |> Legl.Utility.csv_quote_enclosure()
  end

  def new_acting_laws(recs, enacting_laws) do
    Enum.reduce(enacting_laws, recs, fn {title, type, year, number}, acc ->
      title = Legl.Airtable.AirtableTitleField.title_clean(title)
      name = Legl.Airtable.AirtableIdField.id(title, type, year, number)
      [~s/#{name},"#{title}",#{type},#{year},#{number}/ | acc]
    end)
  end

  def field_names(records) do
    [~s/Name,Title_EN,Type,Year,Number,Child\sof/ | records]
  end

end
