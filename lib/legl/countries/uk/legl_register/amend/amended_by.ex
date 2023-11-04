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
    record = Map.merge(record, update_record(stats))
    affecting = convert_amend_structs_to_legal_register_structs(affecting)
    {record, affecting}
  end

  @spec update_record(AmendmentStats.stats()) :: LegalRegister
  defp update_record(stats) do
    %LegalRegister{
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
    with(
      url = Url.affected_path(record),
      {:ok, response} <- LegGovUk.leg_gov_uk_html(url, @client, @parser),
      records =
        case response do
          [{"tbody", _, records}] -> records
          [] -> []
        end
    ) do
      records = parse_laws_affecting(records)
      Stats.amendment_stats(records)
    else
      {:error, :no_records} -> {:error, :no_records}
      {:error, _} -> {:ok, nil, []}
    end
  end

  @spec parse_laws_affecting(list()) :: []
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
    Enum.with_index(record, fn cell, index -> {index, cell} end)
    # |> IO.inspect()
    |> Enum.reduce([], fn
      {0, {"td", _, [{_, _, [title]}]}}, acc ->
        [title | acc]

      {1, _cell}, acc ->
        acc

      {2, {"td", _, targets}}, acc when is_list(targets) ->
        Enum.reduce(targets, [], fn
          {_, _, [target]}, accum ->
            [target | accum]

          "-", accum ->
            ["-" | accum]
        end)
        |> Enum.reverse()
        |> Enum.join(" ")
        |> (&[&1 | acc]).()

      {2, {"td", _, [{_, _, [target]}, {_, _, [target2]}]}}, acc ->
        [~s/#{target} #{target2}/ | acc]

      {2, {"td", _, [{_, _, [target]}]}}, acc ->
        [target | acc]

      {3, {"td", _, [affect]}}, acc ->
        [affect | acc]

      {4, {"td", _, [{_, _, [amending_title]}]}}, acc ->
        [amending_title | acc]

      {5, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
        {type_code, number, year} = Legl.Utility.type_number_year(path)
        [path, year, number, type_code | acc]

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
    |> (&Enum.zip(
          ~w[title target affect Title_EN type_code Number Year path applied? note ]a,
          &1
        )).()
    # |> IO.inspect(label: "parse_law")
    |> (&Kernel.struct(__MODULE__, &1)).()
  end
end
