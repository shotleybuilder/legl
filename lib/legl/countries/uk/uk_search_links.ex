defmodule Legl.Countries.Uk.UkSearchLinks do
  @moduledoc """

    Module produces the content for the 'leg.gov.uk Search' field

  """

  alias Legl.Countries.Uk.UkAirtable, as: AT

  @at_type %{
    ukpga: ["ukpga"],
    uksi: ["uksi"],
    ni: ["nia", "apni", "nisi", "nisr", "nisro"],
    s: ["asp", "ssi"],
    uk: ["ukpga", "uksi"],
    w: ["anaw", "mwa", "wsi"],
    o: ["ukcm", "ukla", "asc"]
  }

  @at_csv "airtable_search_links"

  def run(t) when is_atom(t) do

    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, "Name,leg.gov.uk Search")

    t = Map.get(@at_type, t)
    Enum.each(t, fn x -> run(file, x) end)

    File.close(file)
  end

  def run(file, type) do
    #formula = ~s/{leg.gov.uk Search}=BLANK()/
    formula = ~s/AND({leg.gov.uk Search}=BLANK(),{type}="#{type}")/
    opts =
      [
        formula: formula,
        view: "SEARCH",
        fields: ["Name","Title_EN","Search"]
      ]
    func = &__MODULE__.make_csv/2
    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      IO.inspect(records, limit: :infinity),
      {:ok, msg} <- AT.enumerate_at_records({file, records}, func)
    ) do
      IO.puts(msg)
    end
  end


  def make_csv(file,
    %{
      "Name" => name,
      "Search" => search
    } =
    _fields) do

    txt =
      case Legl.Utility.split_name(name) do
        {type, year, number} ->
          Enum.reduce(search, [], fn x, acc ->
            url = URI.encode(~s[https://legislation.gov.uk/#{type}/#{year}/#{number}/contents/made?text="#{x}"#match-1])
            [~s/#{x}💚#{url} / | acc]
          end)
        {type, number} ->
          Enum.reduce(search, [], fn x, acc ->
            url = URI.encode(~s[https://legislation.gov.uk/#{type}/#{number}/contents/made?text="#{x}"#match-1])
            [~s/#{x}💚#{url} / | acc]
          end)
      end

    ~s/#{name},#{Enum.join(txt, "💚")}/
    |> IO.inspect()
    |> (&(IO.puts(file, &1))).()

    {:ok, "csv saved"}

  end
end
