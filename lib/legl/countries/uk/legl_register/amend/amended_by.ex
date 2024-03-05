defmodule Legl.Countries.Uk.LeglRegister.Amend.AmendedBy do
  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.amendment_parser/1

  alias Legl.Services.LegislationGovUk.RecordGeneric, as: LegGovUk
  alias Legl.Services.LegislationGovUk.Url
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.Amend.Stats

  @code_full "❌ Revoked / Repealed / Abolished"
  @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"

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
  def get_laws_amending_this_law(%{type_code: type_code} = record) do
    records = get_affected(record)
    records = parse_laws_affecting(records)

    # Function to separate affected laws into two groups - revoked affected
    {revocations, affectations} =
      Enum.split_with(records, fn %{affect: affect} ->
        Regex.match?(~r/(repeal|revoke)/, affect)
      end)

    # Process the revoked laws
    {:ok, stats, revoked_by} = Stats.amendment_stats(revocations)

    # IO.inspect(revocations, label: "REVOCATIONS")

    eu? =
      case type_code do
        x when x in ["eur", "eudr", "eudn"] -> true
        _ -> false
      end

    live_field =
      cond do
        eu? and repealed_revoked_in_full?(revocations, type_code) ->
          @code_full

        repealed_revoked_in_full?(revocations) ->
          @code_full

        Enum.count(revocations) != 0 ->
          @code_part

        true ->
          @code_live
      end

    record =
      Kernel.struct(record,
        Live?: live_field,
        "Live?_description": stats.counts,
        Revoked_by: stats.links,
        "🔻_stats_revoked_by_laws_count": stats.laws,
        "🔻_stats_revoked_by_count_per_law": stats.counts,
        "🔻_stats_revoked_by_count_per_law_detailed": stats.counts_detailed
      )

    {:ok, stats, affected_by} = Stats.amendment_stats(affectations)

    record =
      Kernel.struct(record,
        Amended_by: stats.links,
        "🔻_stats_affected_by_count": stats.amendments,
        "🔻_stats_self_affected_by_count": stats.self,
        "🔻_stats_affected_by_laws_count": stats.laws,
        "🔻_stats_affected_by_count_per_law": stats.counts,
        "🔻_stats_affected_by_count_per_law_detailed": stats.counts_detailed
      )

    affecting = convert_amend_structs_to_legal_register_structs(affected_by ++ revoked_by)

    {record, affecting}
    # |> IO.inspect()
  end

  defp convert_amend_structs_to_legal_register_structs(records) do
    Enum.map(records, fn record ->
      Kernel.struct(%LegalRegister{}, Map.from_struct(record))
    end)
  end

  @spec get_affected(map()) :: Stats.AmendmentStats
  def get_affected(record) do
    url = Url.affected_path(record)

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
  end

  @spec repealed_revoked_in_full?(list(), atom()) :: boolean()
  def repealed_revoked_in_full?(data, _type_code) do
    Enum.reduce_while(data, false, fn
      %{target: "", affect: affect}, _acc
      when affect in ["repeal", "revoked"] ->
        {:halt, true}

      _, acc ->
        {:cont, acc}
    end)
  end

  @doc """
  Function filters amendment table rows for entries describing the full revocation / repeal of a law
  """
  @spec repealed_revoked_in_full?(list()) :: boolean()
  def repealed_revoked_in_full?(data) do
    Enum.reduce_while(data, false, fn
      %{target: target, affect: affect}, _acc
      when target in ["Regulations", "Order", "Act"] and affect in ["revoked", "repealed"] ->
        {:halt, true}

      _, acc ->
        {:cont, acc}
    end)
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
          # IO.inspect(target, label: "TARGET")

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

        # no amending title
        {4, {"td", _, [{_, _, []}]}}, acc ->
          ["" | acc]

        {5, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
          case Legl.Utility.type_number_year(path) do
            {type_code, number, year} ->
              year = String.to_integer(year)

              [path, year, number, type_code | acc]

            {"eua"} ->
              [path, nil, "", "eua" | acc]

            _ ->
              [path, nil, ""]
          end

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
