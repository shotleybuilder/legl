defmodule Legl.Services.LegislationGovUk.Record do
  require Logger

  # alias Legl.Airtable.AirtableIdField

  @endpoint "https://www.legislation.gov.uk"

  # @legislation_gov_uk_api is a module attribute (constant) set to the env value
  # defined in dev.exs/prod.exs/test.exs.  Allows to mock the http call

  def legislation(url) do
    case Legl.Services.LegislationGovUk.Client.run!(@endpoint <> url) do
      {:ok, %{:content_type => :xml, :body => body}} ->
        {:ok, :xml, body.metadata}

      {:ok, %{:content_type => :html}} ->
        {:ok, :html}

      {:error, code, error} ->
        # Some older legislation doesn't have .../made/data.xml api
        case code do
          # temporary redirect
          307 ->
            if String.contains?(url, "made") != true do
              legislation(String.replace(url, "data.xml", "made/data.xml"))
            else
              {:error, code, error}
            end

          404 ->
            if String.contains?(url, "/made/") do
              legislation(String.replace(url, "/made", ""))
            else
              {:error, code, error}
            end

          _ ->
            {:error, code, error}
        end
    end
  end

  def amendments_table(url) do
    case Legl.Services.LegislationGovUk.ClientAmdTbl.run!(@endpoint <> url) do
      {:ok, %{:content_type => :html, :body => body}} ->
        # File.write!("lib/amendments.html", body)
        case Legl.Services.LegislationGovUk.Parsers.Amendment.amendment_parser(body) do
          {:ok, response} -> amendments_table_records(url, response)
        end

      {:error, code, response} ->
        IO.puts("************* #{code} #{response} **************")
        {:ok, nil, []}
    end
  end

  @doc """
    ACCEPTS
    {"tr", [{"class", "oddRow"}],
    [
      {"td", [], [{"strong", [], ["Scrap Metal Dealers Act 2013"]}]},
      {"td", [], [{"a", [{"href", "/id/ukpga/2013/10"}], ["2013 c. 10"]}]},
      {"td", [], [{"a", [{"href", "/id/ukpga/2013/10/section/5"}], ["s. 5"]}]},
      {"td", [], ["coming into force"]},
      {"td", [{"class", "centralCol"}],
        [
          {"strong", [],
          ["The Scrap Metal Dealers Act 2013 (Commencement and Transitional Provisions) Order 2013"]}
        ]},
      {"td", [{"class", "centralCol"}],
        [{"a", [{"href", "/id/uksi/2013/1966"}], ["2013 No. 1966"]}]},
      {"td", [{"class", "centralCol"}],
        [{"a", [{"href", "/id/uksi/2013/1966/article/2/a"}], ["art. 2(a)"]}]},
      {"td", [], [{"span", [{"class", "effectsApplied"}], ["Yes"]}]},
      {"td", [], []}
    ]}

    RETURNS
    ["Finance Act 2021", "ukpga", "2021", "26", "Yes", "inserted", []]
    ["The Environmental Permitting (England and Wales) Regulations 2016", "uksi", "2016",
    "1154", "Yes", "words substituted", []]
    ["The Scrap Metal Dealers Act 2013 (Commencement and Transitional Provisions) Order 2013",
    "uksi", "2013", "1966", "Yes", "coming into force", []]
  """
  def amendments_table_records(_url, []) do
    IO.puts("Number of amendments 0 (zero)\n [#{__MODULE__}.amendments_table_records]\n")
    {:ok, nil, []}
  end

  def amendments_table_records(_url, [{"tbody", _, records}]) do
    # "/changes/affected/ukpga/2010/10/data.xml?results-count=1000&sort=affecting-year-number"
    # [_, otype, oyear, onumber] =
    # Regex.run(~r/\/changes\/affected\/([a-z]+?)\/(\d{4})\/(\d+)\/data\.xml\?results-count=1000&sort=affecting-year-number/,
    # url)
    IO.puts(
      "Total number of amendments #{Enum.count(records)}\n [#{__MODULE__}.amendments_table_records]\n"
    )

    # IO.inspect(records, label: "LAWS: ", limit: :infinity)

    # Each row of the table is a 3-part tuple:
    # Element == "tr"
    # Class == [{"class", "oddRow"}]
    # Content
    amending_records =
      Enum.reduce(records, [], fn {_, _, x}, acc ->
        case process_amendment_table_row(x) do
          {:ok, title, _amendment_type, amending_title, path, yr_num, applied?, _note} ->
            [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)

            case Regex.run(~r/(\d{4}).*?(\d+)/, yr_num) do
              [_, year2, number2] ->
                if year != year2 do
                  Logger.warning("Year doesn't match #{path}")
                end

                if number != number2 do
                  Logger.warning("Number doesn't match #{path}")
                end

              nil ->
                [[title, amending_title, path, type, year, number, applied?] | acc]
            end

            [[title, amending_title, path, type, year, number, applied?] | acc]

          {:error, "no match"} ->
            IO.puts(
              "ERROR: No match against this row #{inspect(x)} [#{__MODULE__}.amendments_table_records]"
            )

            acc
        end
      end)

    stats = stats(amending_records)
    # |> IO.inspect(limit: :infinity)
    Enum.uniq(amending_records)
    # |> IO.inspect(label: "UNIQ: ", limit: :infinity)
    |> remove_self_amending()
    # |> IO.inspect(label: "NO SELF: ", limit: :infinity)
    |> applied()
    # |> IO.inspect(label: "APPLIED: ", limit: :infinity)
    # |> save_amendments_as_csv_file()
    |> (&{:ok, stats, &1}).()
  end

  def process_amendment_table_row(row) do
    Enum.with_index(row, fn cell, index -> {index, cell} end)
    |> Enum.reduce([:ok], fn
      {0, {"td", _, [{_, _, [title]}]}}, acc ->
        [title | acc]

      {1, _cell}, acc ->
        acc

      {2, _cell}, acc ->
        acc

      {3, {"td", _, []}}, acc ->
        ["" | acc]

      {3, {"td", _, [amendment_effect]}}, acc ->
        [amendment_effect | acc]

      {4, {"td", _, [{_, _, [amending_title]}]}}, acc ->
        [amending_title | acc]

      {5, {"td", _, [{_, [{"href", path}], [yr_num]}]}}, acc ->
        [yr_num, path | acc]

      {6, _cell}, acc ->
        acc

      {7, {"td", _, [{_, _, [applied?]}]}}, acc ->
        [applied? | acc]

      {7, {"td", _, [{_, _, [applied1?]}, {_, _, [applied2?]}]}}, acc ->
        [~s/#{applied1?}. #{applied2?}/ | acc]

      {7, {"td", _, [applied?]}}, acc ->
        [applied? | acc]

      {8, {"td", _, note}}, acc ->
        [note | acc]

      {id, row}, acc ->
        IO.puts(
          "Unhandled amendment table row\nID #{id}\nROW #{inspect(row)}\n[#{__MODULE__}.amendments_table_records]\n"
        )

        acc
    end)
    |> Enum.reverse()
    |> List.to_tuple()
  end

  def stats(records) do
    Legl.Countries.Uk.LeglRegister.Amend.pre_uniq_summary_amendment_stats(records)
    # |> IO.inspect(label: "stats")
  end

  defp uniq_by_amending_title(records) do
    Enum.uniq_by(
      records,
      fn [_title, amending_title, _path, _type, _year, _number, _applied?] ->
        amending_title
      end
    )
  end

  @doc """
    Groups the amendments by law and then combines the tag that decribes if the
    amended law has actually been updated on the legislation.gov.uk website.
    Captures the tags as a comma separated string in the variable 'applied?'
  """
  def applied([]), do: []

  def applied(records) do
    # create a list of the uniq titles in the records
    uniq_titles = uniq_by_amending_title(records)

    grouped_by_title =
      Enum.map(
        uniq_titles,
        fn [_title, amending_title, _path, _type, _year, _number, _applied?] ->
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
        end
      )

    Enum.map(grouped_by_title, fn x ->
      {list, str} =
        Enum.reduce(x, {[], []}, fn [
                                      _title,
                                      _amending_title,
                                      _path,
                                      _type,
                                      _year,
                                      _number,
                                      applied?
                                    ] = y,
                                    {_acc, str} ->
          {y, [applied? | str]}
        end)

      # ","<>str = str
      # str = ~s/"#{str}"/
      List.replace_at(list, 6, str)
    end)
  end

  def remove_self_amending([]), do: []

  def remove_self_amending(records) do
    Enum.reduce(records, [], fn [title, amending_title, _, _, _, _, _] = x, acc ->
      if title == amending_title do
        acc
      else
        [x | acc]
      end
    end)
  end

  def save_amendments_as_csv_file(records) do
    binary =
      Enum.map(records, fn x -> Enum.join(x, ",") end)
      |> Enum.join("\n")

    "lib/amending.csv"
    |> Path.absname()
    |> File.write(binary)

    records
  end
end
