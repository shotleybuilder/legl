defmodule Legl.Countries.Uk.LeglRegister.Amend.AmendedBy do
  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.amendment_parser/1

  alias Legl.Services.LegislationGovUk.RecordGeneric, as: LegGovUk
  alias Legl.Services.LegislationGovUk.Url
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.Amend.Stats

  defstruct ~w[
    title
    target
    affect
    Title_EN
    path
    type_code
    Number
    Year
    applied?
    affected_count
  ]a

  @spec get_laws_amending_this_law(map()) :: {LegalRegister, LegalRegister}
  def get_laws_amending_this_law(record) do
    # call to legislation.gov.uk to get the laws that have amended this
    {:ok, stats, affecting} = affected(record)
    record = Kernel.struct(record, update_record(stats))
    affecting = convert_amend_structs_to_legal_register_structs(affecting)

    {record, affecting}
    # |> IO.inspect()
  end

  @spec update_record(AmendmentStats.stats()) :: map()
  defp update_record(stats) do
    %{
      # amendments_checked: ~s/#{Date.utc_today()}/,
      Amended_by: stats.links,
      # leg_gov_uk_updates: "",
      stats_amendments_count: stats.amendments,
      stats_self_amending_count: stats.self,
      stats_amending_laws_count: stats.laws,
      stats_amendments_count_per_law: stats.counts,
      stats_amendments_count_per_law_detailed: stats.counts_detailed
    }
  end

  defp convert_amend_structs_to_legal_register_structs(records) do
    Enum.map(records, fn record ->
      Kernel.struct(%LegalRegister{}, Map.from_struct(record))
    end)
  end

  @spec affected(map()) :: Stats.AmendmentStats
  def affected(record) do
    url = Url.affected_path(record)

    records =
      case LegGovUk.leg_gov_uk_html(url, @client, @parser) do
        {:ok, response} ->
          case response do
            [{"tbody", _, records}] -> records
            [] -> []
          end

        {:error, :no_records} ->
          []

        {:error, msg} ->
          IO.puts("ERROR: #{msg}")
          []
      end

    records = parse_laws_affecting(records)

    Stats.amendment_stats(records)
  end

  @spec parse_laws_affecting([]) :: []
  def parse_laws_affecting([]), do: []

  @spec parse_laws_affecting(list()) :: [%__MODULE__{}]
  def parse_laws_affecting(records) do
    Enum.reduce(records, [], fn {_, _, x}, acc ->
      [parse_law(x) | acc]
    end)
  end

  @doc """
    Receives
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

    Returns
          %AmendedBy{}
  """
  @spec parse_law(list()) :: %__MODULE__{}
  def parse_law(record) do
    cells =
      Enum.with_index(record, fn cell, index -> {index, cell} end)
      |> Enum.reduce([], fn
        {0, {"td", _, title}}, acc ->
          Enum.map(title, fn
            {_, _, [t]} when is_binary(t) -> t
            {_, _, t} when is_binary(t) -> t
            t when is_binary(t) -> t
            [t] when is_binary(t) -> t
            [_, t] when is_binary(t) -> t
          end)
          |> Enum.reverse()
          |> Enum.join(" ")
          |> (&[&1 | acc]).()

        {1, _cell}, acc ->
          acc

        {2, {"td", _, target}}, acc ->
          # IO.inspect(content, label: "CONTENT: ")

          Enum.map(target, fn
            {"a", [{"href", _}, [v1]], [v2]} -> ~s/#{v1} #{v2}/
            {"a", [{"href", _}], [v]} -> v
            {"a", [{"href", _}], []} -> ""
            [v] -> v
            v when is_binary(v) -> v
          end)
          # |> IO.inspect(label: "AT: ")
          |> Enum.join(" ")
          |> String.trim()
          |> (&[&1 | acc]).()

        {3, {"td", _, [affect]}}, acc ->
          [affect | acc]

        {3, {"td", _, []}}, acc ->
          ["" | acc]

        {4, {"td", _, [{_, _, [amending_title]}]}}, acc ->
          [amending_title | acc]

        {5, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
          {type_code, number, year} = Legl.Utility.type_number_year(path)
          year = String.to_integer(year)

          [path, year, number, type_code | acc]

        {6, _cell}, acc ->
          acc

        {7, {"td", _, applied?}}, acc ->
          # IO.inspect(applied?, label: "CONTENT: ")

          Enum.map(applied?, fn
            {"a", [{"href", _}, [v1]], [v2]} -> ~s/#{v1} #{v2}/
            {"a", [{"href", _}], [v]} -> v
            {"a", [{"href", _}], []} -> ""
            {"span", _, [v]} -> v
            [v] -> v
            [] -> ""
            v when is_binary(v) -> v
          end)
          # |> IO.inspect(label: "AT: ")
          |> Enum.join(" ")
          |> String.trim()
          |> (&[&1 | acc]).()

        {8, {"td", _, _note}}, acc ->
          acc

        {id, row}, acc ->
          IO.puts(
            "Unhandled amendment table row\nID #{id}\nROW #{inspect(row)}\n[#{__MODULE__}.amendments_table_records]\n"
          )

          acc

        row, acc ->
          IO.puts(
            "Unhandled amendment table row\nROW #{inspect(row)}\n[#{__MODULE__}.amendments_table_records]\n"
          )

          acc
      end)
      |> Enum.reverse()

    case Enum.count(cells) do
      9 ->
        cells
        |> (&Enum.zip(
              ~w[title target affect Title_EN type_code Number Year path applied?]a,
              &1
            )).()
        # |> IO.inspect(label: "parse_law")
        |> (&Kernel.struct(__MODULE__, &1)).()

      _ ->
        IO.puts(
          "ERROR: Wrong number of arguments #{inspect(Enum.with_index(cells))}\n [#{__MODULE__}.parse_law]"
        )
    end
  end
end
