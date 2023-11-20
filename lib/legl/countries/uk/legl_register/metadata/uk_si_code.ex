defmodule Legl.Countries.Uk.LeglRegister.Metadata.UkSiCode do
  @moduledoc """
  Module automates read of the SI Code for a piece of law and posts the result into Airtable.

  Required parameter is the name of the base with the SI Code field.

  Currently this is -
    UK 🇬🇧️ E 💚️.  The module accepts 'UK E' w/o the emojis.
  """

  alias Legl.Services.Airtable.Records
  alias Legl.Services.Airtable.AtBasesTables

  @at_csv ~s[lib/legl/countries/uk/legl_register/metadata/si_code.csv]
          |> Path.absname()
  @default_opts %{
    base_name: "UK E"
  }
  @doc """
    Can be called with an optional view name

    LLegl.Countries.Uk.LeglRegister.Metadata.UkSiCode.si_code_process([view: view])

  """

  def si_code_process(opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    {:ok, file} = @at_csv |> File.open([:utf8, :write])
    IO.puts(file, "Name,SI Code")

    with {:ok, recordset} <- get_at_records_with_empty_si_code(opts),
         :ok <- get_and_save_si_code_from_legl_gov_uk(recordset, file),
         :ok <- rm_last_line(@at_csv),
         {:ok, records} <- clean_csv(),
         # IO.inspect(limit: :infinity),
         :ok <- split_si_code_csv(records) do
      Legl.Utility.count_csv_rows(@at_csv)
      |> (&IO.puts("csv file saved with #{&1} records")).()

      :ok
    else
      {:error, error} -> IO.puts("#{error}")
    end

    File.close(file)
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
  def get_at_records_with_empty_si_code(opts) do
    options =
      Enum.into(
        opts,
        %{
          fields: ["Name", "Title_EN", "SI Code", "leg.gov.uk intro text"],
          formula: ~s/{SI CODE}=BLANK()/
        }
      )

    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(opts.base_name),
      params = %{
        base: base_id,
        table: table_id,
        options: options
      },
      {:ok, {_, recordset}} <- Records.get_records({[], []}, params)
    ) do
      IO.puts("Records returned from Airtable")
      {:ok, recordset}
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
    Legl.Countries.Uk.LeglRegister.Metadata.UkSiCode.get_parent_at_records_with_multi_si_codes("UK E")
  """

  def get_and_save_si_code_from_legl_gov_uk(at_records, file) do
    Enum.each(at_records, fn x ->
      name = x |> Map.get("fields") |> Map.get("Name")

      with(
        {:ok, path} <- name |> resource_path(),
        {:ok, si_code} <- get_si_code(path)
      ) do
        si_code =
          if si_code != "" do
            si_code
          else
            "_NO_SI_CODE"
          end

        ~s/#{name},#{si_code}/
        |> (&IO.puts(file, &1)).()
      else
        {:error, error} ->
          IO.inspect(error, label: "ERROR: ")

        {:error, code, error} ->
          IO.puts("ERROR: #{code} #{error}")
      end
    end)

    :ok
  end

  def rm_last_line(path) do
    File.read!(path)
    |> (&Regex.replace(~r/\s*\Z/, &1, "")).()
    |> (&File.write!(path, &1)).()

    :ok
  end

  @doc """
    /uksi/1995/304/introduction/made/data.xml
  """
  def resource_path({type_code, year, number}) when is_integer(year) do
    resource_path({type_code, Integer.to_string(year), number})
  end

  def resource_path({type_code, year, number}) do
    {:ok, ~s[/#{type_code}/#{year}/#{number}/introduction/data.xml]}
  end

  def resource_path("UK" <> name) do
    case Legl.Utility.split_name(name) do
      {type, year, number} ->
        resource_path({type, year, number})

      {:error, error} ->
        {:error, error}

      {type, number} ->
        {:ok, ~s[/#{type}/#{number}/introduction/data.xml]}
    end
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
  # todo: check that we've got the right piece of law by comparing title
  def get_si_code(path) do
    case Legl.Services.LegislationGovUk.RecordGeneric.metadata(path) do
      {:ok, :xml, %{Title_EN: _title, si_code: si_code} = _metadata} ->
        {:ok, si_code}

      {:ok, :xml, %{Title_EN: title}} ->
        {:none, "no SI codes for #{title}"}

      {:ok, :html} ->
        {:error, "not found"}

      {:error, code, error} ->
        {:error, code, error}
    end
  end

  def clean_csv do
    Legl.csv("amending")
    |> Path.absname()
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(fn x -> x end)
    |> IO.inspect(limit: :infinity)
    |> Enum.reduce([], fn x, acc ->
      [name, si_code] = String.split(x, ",", parts: 2)

      case Enum.count(String.split(si_code, ";")) do
        1 ->
          si_code(si_code)

        _ ->
          String.split(si_code, ";")
          |> Enum.reduce(
            [],
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
                      [join([si_code2, si_code1]), [region1]]

                    [si_code1] ->
                      [join([si_code2, si_code1])]
                  end

                [si_code2, region2] ->
                  case si_code(x) do
                    [si_code1, region1] ->
                      [join([si_code2, si_code1]), join([region2, region1])]

                    [si_code1] ->
                      [join([si_code2, si_code1]), region2]
                  end
              end
            end
          )
      end
      |> (&[name | &1]).()
      |> (&[&1 | acc]).()
    end)
    |> (&{:ok, &1}).()
  end

  def join([term1, term2]) do
    ~s/"#{term1},#{term2}"/
  end

  def si_code(si_code) do
    cond do
      Regex.match?(~r/[A-Z ]*?,[ ]+ENGLAND[ ]+AND[ ]+WALES[ ]+[A-Z ]*?,[ ]SCOTLAND$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+ENGLAND[ ]+AND[ ]+WALES/, si_code)
        [si_code, ~s/"England,Wales,Scotland"/]

      Regex.match?(~r/[A-Z ]*?[ ]+ENGLAND[ ]+AND[ ]+WALES[ ]+AND[ ]+SCOTLAND$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?)[ ]+ENGLAND[ ]+AND[ ]+WALES/, si_code)
        [si_code, ~s/"England,Wales,Scotland"/]

      Regex.match?(~r/[A-Z ]*?,[ ]+ENGLAND[ ]+AND[ ]+WALES$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+ENGLAND[ ]+AND[ ]+WALES$/, si_code)
        [si_code, ~s/"England,Wales"/]

      Regex.match?(~r/[A-Z ]*?,[ ]+ENGLAND$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+ENGLAND$/, si_code)
        [si_code, "England"]

      Regex.match?(~r/[A-Z ]*?,[ ]+WALES$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+WALES$/, si_code)
        [si_code, "Wales"]

      Regex.match?(~r/[A-Z ]*?,[ ]+SCOTLAND$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+SCOTLAND$/, si_code)
        [si_code, "Scotland"]

      Regex.match?(~r/[A-Z ]*?,[ ]+NORTHERN IRELAND$/, si_code) ->
        [_, si_code] = Regex.run(~r/^(.*?),[ ]+NORTHERN IRELAND$/, si_code)
        [si_code, "Northern Ireland"]

      true ->
        [si_code]
    end
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
      |> (&[["Name", "SI CODE", "Geo_Region"] | &1]).()

    csv2 =
      Enum.filter(records, fn x ->
        case x do
          [_, "ERROR" <> _] -> true
          _ -> false
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

    [
      {"lib/si_code_regions.csv", csv1},
      {"lib/error_si_codes.csv", csv2},
      {"lib/si_codes.csv", csv3},
      {"lib/empty_si_codes.csv", csv4}
    ]
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

  def save_to_csv(binary, filename) do
    line_count = binary |> String.graphemes() |> Enum.count(&(&1 == "\n"))

    filename
    |> Path.absname()
    |> File.write(binary)

    {:ok, line_count}
  end
end
