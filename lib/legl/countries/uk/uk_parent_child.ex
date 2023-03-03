defmodule Legl.Countries.Uk.UkParentChild do

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.RecordEnactingText

  @new_law_csv_file "lib/airtable_new_law?.csv" |> Path.absname()
  @parents_csv "lib/airtable_parents.csv" |> Path.absname()

  def get_child_process(base_name) do
    with {:ok, recordset} <- get_at_records_with_empty_parent(base_name),
      {:ok, recordset} <- get_parent_laws_from_leg_gov_uk(recordset),
      {:ok, count } <- make_csv(recordset)
    do
      IO.puts("csv saved with #{count} records")
      :ok
    else
      {:error, error} -> IO.puts("#{error}")
    end
  end

  @doc """
    THe AT base field for parent laws is called 'Child of'
  """
  def get_at_records_with_empty_parent(base_name, filesave? \\ false) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
          fields: ["Name", "Title_EN", "Type", "Year", "Number", "Child of"],
          formula: ~s/AND({Child of}=BLANK(),{Type}="uksi")/}
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      IO.puts("Records returned from Airtable")
      IO.inspect(recordset)
      if filesave? == true do save_to_file(recordset) end
      {:ok, recordset}
    else
      {:error, error} -> {:error, error}
    end
  end

  def save_to_file() do
    {:ok, file} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.open([:read, :utf8, :write])
    Airtable.at_data()
    |> Enum.each(
        fn record ->
          str =
          case record do

            %{
              "fields" =>
              %{
                "Name" => name,
                "Title_EN" => title,
                "Type" => [type],
                "Year" => year,
                "Number" => number
              }
            } -> ~s/#{name} "#{title}" #{type} #{year} #{number}/

            %{
              "fields" =>
              %{
                "Name" => name,
                "Title_EN" => title,
                "Year" => year,
                "Number" => number
              }
            } -> ~s/#{name} "#{title}" TYPE_MISSING #{year} #{number}/

            %{
              "fields" =>
              %{
                "Name" => name,
                "Title_EN" => title,
                "Type" => [type],
                "Year" => year
              }
            } -> ~s/#{name} "#{title}" #{type} #{year} NUMBER_MISSING/

          end
          IO.puts(file, str)
        end
    )
    File.close(file)
  end

  def save_to_file(records) when is_list(records) do
    {:ok, file} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.open([:read, :utf8, :write])
    IO.puts(file, inspect(records, limit: :infinity))
    File.close(file)
    :ok
  end

  def open_airtable_data_from_file() do
    {:ok, binary} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.read()

    String.split(binary, "%")
    |> Enum.each(fn x -> IO.inspect(x) end)
  end

  def data do
    Enum.each(Airtable.at_data(), fn x -> IO.inspect(x) end)
  end

  def process_records() do
    Airtable.at_data()
    |> Enum.each(
        fn record ->
          case record do

            %{
              "fields" =>
              %{
                "Name" => _name,
                "Title_EN" => _title,
                "Type" => _type,
                "Year" => _year,
                "Number" => _number
              }
            } -> step_parent_laws_from_leg_gov_uk([record])

            %{
              "fields" =>
              %{
                "Name" => _name,
                "Title_EN" => _title,
                "Year" => _year,
                "Number" => _number
              }
            } -> ExPrompt.confirm("Type Missing")

            %{
              "fields" =>
              %{
                "Name" => _name,
                "Title_EN" => _title,
                "Type" => _type,
                "Year" => _year
              }
            } -> ExPrompt.confirm("Number Missing")
          end
        end
    )
  end

  def step_parent_laws_from_leg_gov_uk(records) do
    #clear_and_header_row_csv()
    Enum.reduce(records, [],
      fn %{"fields" => %{"Type" => type, "Year" => year, "Number" => number}} = x, acc ->
        case prompt(x) do
          true ->
            path = introduction_path(type, year, number)
              case get_parent(path) do
                {:ok, response} ->
                  case parse_enacting_text(response) do
                    {:ok, enacting_laws} ->
                      enacting_laws = Map.merge(x["fields"], enacting_laws)
                      record = %{x | "fields" => enacting_laws}
                      make_csv_record(record)
                      [record | acc]
                    {:error} -> acc
                  end
                {:error, error} ->
                  IO.inspect(error, label: "leg.gov.uk: ERROR: ")
                  acc
              end
          false ->
            acc
        end
    end)
    |> (&{:ok, &1}).()
  end

  def prompt(%{"fields" => %{"Name" => name, "Title_EN" => title, "Type" => [type]}}) do
    case type do
      "ukpga" -> false #no parents for an Act
      "asp" -> false
      "msw" -> false
      "ukcm" -> false
      _ -> IO.puts(~s/#{name} #{title}/)
        true #ExPrompt.confirm(~s/#{name} #{title}/)
    end
  end

  def get_parent_laws_from_leg_gov_uk(records) do
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

  def parse_enacting_text(%{enacting_text: nil, urls: _urls} = response) do
    {:ok, Map.put_new(response, :enacting_laws, [])}
  end

  def parse_enacting_text(%{enacting_text: enacting_text, urls: urls} = response) do
    [_, txt] =
      cond do
        Regex.match?(~r/powers[ ]conferred[ a-z]*?by(.*)$/, enacting_text) == true ->
          enacting_text = Regex.replace(~r/\n/m, enacting_text, " ")
          Regex.run(~r/power[s]?[ ]conferred[ a-z]*?by(.*)$/, enacting_text)
        true -> [nil, nil]
      end
    case txt do
      nil -> {:error}
      _ ->
      IO.inspect(txt)
      matches = Regex.scan(~r/f\d{5}/m, txt)
      urls =
        Enum.map(matches, fn [x] ->
          Map.get(urls, x) |> to_string()
        end)
      parents =
        Enum.reduce(urls, [], fn x, acc ->
          case x do
            "" -> acc
            _ ->
              cond do
                Regex.match?(
                  ~r/http:\/\/www.legislation.gov.uk\/id\/([a-z]*?)\/(\d{4})\/(\d+)$/, x) == true ->
                    [_, type, year, number] =
                      Regex.run(~r/http:\/\/www.legislation.gov.uk\/id\/([a-z]*?)\/(\d{4})\/(\d+)$/, x)
                      case introduction_path(type, year, number) |> get_title() do
                        {:ok, title} -> [{title, type, year, number} | acc]
                        {:error, error} -> [{error, type, year, number} | acc]
                      end
                Regex.match?(
                  ~r/http:\/\/www.legislation.gov.uk\/european\/directive\/(\d{4})\/(\d+)$/, x) == true ->
                    [_, year, number] =
                      Regex.run(~r/http:\/\/www.legislation.gov.uk\/european\/directive\/(\d{4})\/(\d+)$/, x)
                    [{"eu law", "eudr", year, number} | acc]
              end
          end
        end)
        |> Enum.uniq()
      {:ok, Map.put_new(response, :enacting_laws, parents)}
    end
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



  #*****************************************************************
  #Deal with one record at a time
  #
  #*****************************************************************
  def make_csv_record(%{
    "fields" =>
    %{
      "Name" => name,
      "Title_EN" => title,
      "Type" => type,
      "Year" => year,
      "Number" => number,
      enacting_laws: enacting_laws
    }
    } = _law) do

    at_parent = at_parent(enacting_laws)
    title = title |> Legl.Utility.csv_quote_enclosure()
    [~s/#{name},#{title},#{type},#{year},#{number},#{at_parent}/]
    |> new_acting_laws(enacting_laws)
    |> Enum.reverse()
    |> save_record_to_csv()
  end

  def make_csv_record(), do: nil

  def clear_and_header_row_csv() do
    #File.write! overwrites existing content
    File.write!(@new_law_csv_file, "Name,Title_EN,Type,Year,Number")
    File.write!(@parents_csv, "Name,Title_EN,Type,Year,Number,Child of")
  end

  def save_record_to_csv([child | new_parent?]) do

    {:ok, file} =
      @new_law_csv_file |> File.open([:utf8, :append])
      Enum.each(new_parent?, &IO.puts(file, &1))
      File.close(file)

    {:ok, file} =
      @parents_csv |> File.open([:utf8, :append])
      IO.puts(file, child)
      File.close(file)
  end

  #*****************************************************************
  #Deal with all records at once
  #
  #*****************************************************************
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
        title = title |> Legl.Utility.csv_quote_enclosure()
        [~s/#{name},#{title},#{type},#{year},#{number},#{at_parent}/ | acc]
        |> new_acting_laws(enacting_laws)
    end)
    |> field_names()
    |> Enum.join("\n")
    |> save_records_to_csv("lib/amending.csv")
  end
  def save_records_to_csv(binary, filename) do
    line_count = binary |> String.graphemes |> Enum.count(& &1 == "\n")
    filename
    |> Path.absname()
    |> File.write(binary)
    {:ok, line_count}
  end

  #*****************************************************************
  #Helper functions
  #
  #*****************************************************************

  @doc """
    Content of the Airtable Parent field.
    A comma separated list within quote marks of the Airtable ID field (Name).
    "UK_ukpga_2010_41_abcd,UK_uksi_2013_57_abcd"
  """
  def at_parent({:url_error, url} = _enacting_laws), do: url

  def at_parent(enacting_laws) do
    Enum.map(enacting_laws, fn {title, type, year, number} ->
      Legl.Airtable.AirtableTitleField.title_clean(title)
      |> Legl.Airtable.AirtableIdField.id(type, year, number)
    end)
    |> Enum.sort()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
  end

  def new_acting_laws(recs, enacting_laws) do
    Enum.reduce(enacting_laws, recs, fn {title, type, year, number}, acc ->
      title =
        Legl.Airtable.AirtableTitleField.title_clean(title)
        |> Legl.Utility.csv_quote_enclosure()
      name = Legl.Airtable.AirtableIdField.id(title, type, year, number)
      [~s/#{name},#{title},#{type},#{year},#{number}/ | acc]
    end)
  end

  def field_names(records) do
    [~s/Name,Title_EN,Type,Year,Number,Child\sof/ | records]
  end

end
