defmodule Legl.Services.LegislationGovUk.Record do

  require Logger

  @endpoint "https://www.legislation.gov.uk"

  # @legislation_gov_uk_api is a module attribute (constant) set to the env value
  # defined in dev.exs/prod.exs/test.exs.  Allows to mock the http call

  defstruct metadata: []

  def legislation(url) do
    case Legl.Services.LegislationGovUk.Client.run!(@endpoint <> url) do

      {:ok, %{:content_type => :xml, :body => body}} ->
        { :ok,
          :xml,
          %__MODULE__{
            metadata: body.metadata
          }
        }

      {:ok, %{:content_type => :html}} ->
        { :ok,
          :html
        }

      { :error, code, error } ->
        #Some older legislation doesn't have .../made/data.xml api
        case code do
          404 ->
            if String.contains?(url, "/made/") do
              legislation(String.replace(url, "/made", "") )
            else
              { :error, code, error }
            end
          _ -> { :error, code, error }
        end

    end
  end

  def amendments_table(url) do
    case Legl.Services.LegislationGovUk.ClientAmdTbl.run!(@endpoint <> url) do
      { :ok, %{:content_type => :html, :body => body} } ->
        case Legl.Services.LegislationGovUk.Parsers.Amendment.amendment_parser(body) do
          {:ok, response} -> amendments_table_records(url, response)
        end
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
  def amendments_table_records(_url, []), do: []
  def amendments_table_records(url, [{"tbody", _, records}]) do

    #"/changes/affected/ukpga/2010/10/data.xml?results-count=1000&sort=affecting-year-number"
    [_, otype, oyear, onumber] = Regex.run(~r/\/changes\/affected\/([a-z]+?)\/(\d{4})\/(\d+)\/data\.xml\?results-count=1000&sort=affecting-year-number/, url)

    Enum.reduce(records, [], fn {_, _, x}, acc ->

      case process_amendment_table_row(x) do
        {:ok, _amendment_type, title, path, yr_num, _applied?, _note} ->

          [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)
          [_, year2, number2] = Regex.run(~r/(\d{4}).*?(\d+)/, yr_num)

          if otype == type && oyear == year && onumber == number do
            #amended (original law) is the same as the amending and needs to be dropped
            acc

          else
            if year != year2 do Logger.warning("Year doesn't match #{path}") end
            if number != number2 do Logger.warning("Number doesn't match #{path}") end

            [[title, path, type, year, number] | acc]
          end
        {:error, "no match"} -> acc
      end

    end)
    |> Enum.uniq()
    #|> save_amendments_as_csv_file()

  end

  @pattern quote do: [
    {"td", _, _},
    {"td", _, _},
    {"td", _, _},
    {"td", _, [var!(amendment_type)]},
    {"td", _, [{_, _, [var!(title)]}]},
    {"td", _, [{_, [{"href", var!(path)}], [var!(yr_num)]}]},
    {"td", _, _},
    {"td", _, [{_, _, [var!(applied?)]}]},
    {"td", _, var!(note)}
  ]

  def process_amendment_table_row(row) do
    #IO.puts(Macro.to_string(@pattern))
    case row do
      unquote(@pattern) -> {:ok, amendment_type, title, path, yr_num, applied?, note}
      _ -> {:error, "no match"}
    end
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
