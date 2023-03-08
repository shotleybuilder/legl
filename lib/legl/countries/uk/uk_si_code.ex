defmodule Legl.Countries.Uk.UkSiCode do
  @moduledoc """
  Module automates read of the SI Code for a piece of law and posts the result into Airtable.

  Required parameter is the name of the base with the SI Code field.

  Currently this is -
    UK 🇬🇧️ E 💚️.  The module accepts 'UK E' w/o the emojis.
  """

  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Services.Airtable.AtBasesTables

  def si_code_process(base_name) do
    with {:ok, recordset} <- get_at_records_with_empty_si_code(base_name),
     {:ok, recordset} <- get_si_code_from_legl_gov_uk(recordset),
     {:ok, count} <- make_csv(recordset, "amending")
    do
      IO.puts("csv file saved with #{count} records")
      :ok
    else
      {:error, error} -> IO.puts("#{error}")
    end
  end

  @doc """
  Procedure to get Airtable records with 'empty' SI Code fields.  The SI Code
  fields actually contain "Empty" because the Airtable API does not return completely
  empty fields.
  Data from AT has this shape:
    [%{
      "createdTime" => "2023-02-17T16:17:22.000Z",
      "fields" => %{
        "Name" => "UK_2008_373_PROPWARNI",
        "SI Code" => ["Empty"],
        "leg.gov.uk intro text" =>
        "http://www.legislation.gov.uk/nisr/2008/373/introduction/made"
      },
      "id" => "rec5v3jwxYikGJXRQ"
    }]
  """
  def get_at_records_with_empty_si_code(base_name) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
          fields: ["Name", "Title_EN", "SI CODE", "leg.gov.uk intro text"],
          formula: ~s/{SI CODE}="Empty"/}
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      IO.puts("Records returned from Airtable")
      {:ok, recordset}
    else
      {:error, error} -> {:error, error}
    end
  end
  @doc """
    Legl.Countries.Uk.UkSiCode.get_parent_at_records_with_multi_si_codes("UK E")
  """
  def get_parent_at_records_with_multi_si_codes(base_name, filesave? \\ false) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
          view: "SI_CODE-PARENTS",
          fields: ["Name", "Title_EN", "SI_Code_(from_Children)"],
          formula: ~s/{SI_Code_Children_(Count)}>1/}
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params),
      uniq_recordset <- Enum.map(recordset, fn x -> uniq_si_codes(x) end)
    ) do
      IO.puts("Records returned from Airtable")
      if filesave? == true do save_to_file(uniq_recordset) end
      make_csv(uniq_recordset, "airtable_parent_si_codes")
    else
      {:error, error} -> {:error, error}
    end
  end

  def uniq_si_codes(
    %{"fields" =>
      %{"SI_Code_(from_Children)" => si_codes}
    } = record) do
    Enum.uniq(si_codes)
    |> Enum.sort()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
    |> (&(Map.put_new(record["fields"], "SI CODE", &1))).()
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

  @doc """

  """
  def get_si_code_from_legl_gov_uk(records) do

    #records =
    Enum.into(records, [], fn x ->
        fields = Map.get(x, "fields")
        path = resource_path(Map.get(fields, "leg.gov.uk intro text"))
        si_code =
          case get_si_code(path) do
            {:ok, si_code} -> si_code |> IO.inspect(label: "leg.gov.uk: ")
            {:error, error} ->
              IO.inspect(error, label: "leg.gov.uk: ERROR: ")
              "ERROR #{error}"
          end
        %{x | "fields" => %{x["fields"] | "SI CODE" => si_code}}
        #[x | acc]
    end)
    #{:ok, records}
    |> (&{:ok, &1}).()

  end

  def resource_path(url) do
    [_, path] = Regex.run(~r"^http:\/\/www.legislation.gov.uk(.*)", url)
    "#{path}/data.xml"
  end

  @doc """
  Data from the legislation.gov.uk service has this shape -

    %Legl.Services.LegislationGovUk.Record{
      metadata: %{
        pdf_href: "http://www.legislation.gov.uk/uksi/2016/547/introduction/made/data.pdf",
        subject: "INFRASTRUCTURE PLANNING",
        title: "The A14 Cambridge to Huntingdon Improvement Scheme Development Consent Order 2016"
      }
    }

  """
  #todo: check that we've got the right piece of law by comparing title
  def get_si_code(path) do
    case Record.legislation(path) do
      {:ok, :xml, %{metadata: %{title: _title, subject: si_code}}} ->
        {:ok, si_code}
      {:ok, :xml, %{metadata: %{title: _title}}} ->
        {:ok, ""}
      {:ok, :html} -> {:ok, "not found"}
      {:error, _code, error} -> {:error, error}
    end
  end

  @doc """
    .csv has this structure
    "Name","Title_EN","SI Code"
  """
  def make_csv(records, filename) do
    csv_list =
      Enum.join(["Name,", "SI CODE"])
      |> (&[&1 | []]).()

      Enum.reduce(records, csv_list,
        fn
          %{"Name" => name, "SI CODE" => si_code}, acc ->
            [Enum.join([name, si_code], ",") | acc]
          %{"fields" => %{"Name" => name, "SI CODE" => si_code}}, acc ->
          [Enum.join([name, si_code], ",") | acc]
      end)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> save_to_csv("lib/#{filename}.csv")

  end

  def save_to_csv(binary, filename) do
    line_count = binary |> String.graphemes |> Enum.count(& &1 == "\n")
    filename
    |> Path.absname()
    |> File.write(binary)
    {:ok, line_count}
  end

  def clean_csv do
    Legl.csv("amending")
    |> Path.absname()
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(fn x -> x end)
    |> Enum.reduce([], fn x, acc ->

      [name, si_code] = String.split(x, ",", parts: 2)

      case Enum.count(String.split(si_code, ";")) do

        1 -> si_code(si_code)

        _ ->
          String.split(si_code, ";")
          |> Enum.reduce([],
            fn x, acc ->
              case acc do
                [] ->
                  case si_code(x) do
                    [si_code1, region1] -> [si_code1, region1]
                    [si_code1] -> [si_code1]
                  end
                [si_code2] ->
                  case si_code(x) do
                    [si_code1, region1] ->
                      [Enum.join([si_code2, si_code1], ","), [region1]]
                    [si_code1] ->
                      [Enum.join([si_code2, si_code1], ",")]
                  end
                [si_code2, region2] ->
                  case si_code(x) do
                    [si_code1, region1] ->
                      [Enum.join([si_code2, si_code1], ","), Enum.join([region2, region1], ",")]
                    [si_code1] -> [Enum.join([si_code2, si_code1], ","), region2]
                  end
              end
          end)

      end
      |> (&([name | &1])).()
      |> (&([&1 | acc])).()
    end)
    |> split_si_code_csv()
  end

  @doc """
  Procedure splits the .csv into 4 separate .csv files for upload into Airtable.
  This is needed because AT will overwrite any blank or out-of-date fields contained in the .csv
  CSV 1 - SI Codes with a populated Region field
  CSV 2 - SI Codes w/o a region field
  CSV 3 - records for which an ERROR was returned
  CSV 4 - records with empty SI Code field
  """
  def split_si_code_csv(records) do

    csv1 =
      Enum.flat_map(records, fn x ->
        case Enum.count(x) do
          3 -> [x]
          _ -> []
        end
      end)
      |> (&[["Name", "SI CODE", "Region"] | &1]).()

    csv2 =
      Enum.filter(records, fn x ->
        case x do
          [_, "ERROR" <> _] -> :true
          _ -> :false
        end
    end)
    |> (&[["Name", "SI CODE"] | &1]).()

    csv3 =
      Enum.reduce(records, [], fn x, acc ->
        case Enum.count(x) do
          2 ->
            case x do
              [_, "ERROR" <> _] -> acc
              [_, ""] -> acc
              [name, si_code] -> [[name, String.upcase(si_code)] | acc]
            end
          _ ->
            acc
        end
      end)
    csv4 =
      Enum.reduce(records, [], fn x, acc ->
        case Enum.count(x) do
          2 ->
            case x do
              [_, "ERROR" <> _] -> acc
              [_, ""] -> [x | acc]
              _ -> acc
            end
          _ ->
            acc
        end
      end)
      |> (&[["Name", "SI CODE"] | &1]).()

    [{"lib/si_code_regions.csv", csv1}, {"lib/error_si_codes.csv", csv2}, {"lib/si_codes.csv", csv3}, {"lib/empty_si_codes.csv", csv4}]
    |> Enum.each(fn x -> save_csv(x) end)


  end

  def save_csv({filename, records}) do
    Enum.reduce(records, [], fn x, acc ->
      [Enum.join(x, ",") | acc]
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> save_to_csv(filename)
  end

  def si_code(si_code) do

    cond do

      Regex.match?(~r/[A-Z]*?,[ ]+ENGLAND[ ]+AND[ ]+WALES$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+ENGLAND[ ]+AND[ ]+WALES$/, si_code)
        [si_code, "England,Wales"]

      Regex.match?(~r/[A-Z]*?,[ ]+ENGLAND$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+ENGLAND$/, si_code)
        [si_code, "England"]

      Regex.match?(~r/[A-Z]*?,[ ]+WALES$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+WALES$/, si_code)
        [si_code, "Wales"]

      Regex.match?(~r/[A-Z]*?,[ ]+NORTHERN IRELAND$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+NORTHERN IRELAND$/, si_code)
        [si_code, "Northern Ireland"]

      true -> [si_code]

    end
  end

end
