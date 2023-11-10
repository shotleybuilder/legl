defmodule Legl.Countries.Uk.LeglRegister.Amend.Amending do
  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.amendment_parser/1

  alias Legl.Services.LegislationGovUk.RecordGeneric, as: LegGovUk
  alias Legl.Services.LegislationGovUk.Url
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.Amend.Stats

  defstruct ~w[
    Name
    Title_EN
    type_code
    Number
    Year
    path
    target
    affect
    applied?
    target_affect_applied?
    note
    affecting_count
  ]a

  @spec get_laws_amended_by_this_law(map()) :: {LegalRegister, LegalRegister}
  def get_laws_amended_by_this_law(record) do
    # call to legislation.gov.uk to get the laws that have amended this
    {:ok, stats, affected} = affecting(record)
    record = Kernel.struct(record, update_record(stats))
    # Merge with the LegalRegister struct removes all scaffolding members
    affected = convert_amend_structs_to_legal_register_structs(affected)

    {record, affected}
    # |> IO.inspect()
  end

  @spec update_record(AmendmentStats.stats()) :: map()
  defp update_record(stats) do
    %{
      # amendments_checked: ~s/#{Date.utc_today()}/,
      Amending: stats.links,
      stats_amendings_count: stats.amendments,
      stats_self_amendings_count: stats.self,
      stats_amended_laws_count: stats.laws,
      stats_amendings_count_per_law: stats.counts,
      stats_amendings_count_per_law_detailed: stats.counts_detailed
    }
  end

  defp convert_amend_structs_to_legal_register_structs(records) do
    Enum.map(records, fn record ->
      Kernel.struct(%LegalRegister{}, Map.from_struct(record))
    end)
  end

  @spec affecting(map()) :: Stats.AmendmentStats
  def affecting(record) do
    url = Url.affecting_path(record)

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

    # IO.inspect(records, limit: :infinity)
    records = parse_laws_affected(records)
    Stats.amendment_stats(records)
  end

  def parse_laws_affected([]), do: []

  def parse_laws_affected(records) do
    Enum.reduce(records, [], fn {_, _, x}, acc ->
      [parse_law(x) | acc]
    end)
  end

  @doc """
  Receives
  {"tr", [{"class", "oddRow"}],
     [
       {"td", [],
        [
          {"strong",
           [
             {"title",
              "Commission Regulation (EU) No 748/2012 of 3 August 2012 laying down implementing rules for the airworthiness and environmental certification of aircraft and related products, parts and appliances, as well as for the certification of design and production organisations (recast) (Text with EEA relevance)"}
           ], ["Commission Regulation (EU) No 748/2012 "]}
        ]},
       {"td", [], [{"a", [{"href", "/id/eur/2012/748"}], ["2012 No. 748"]}]},
       {"td", [], ["Art. 8(4)(5)"]},
       {"td", [], ["inserted"]},
       {"td", [{"class", "centralCol"}],
        [{"strong", [], ["The Aviation Safety (Amendment) Regulations 2023"]}]},
       {"td", [{"class", "centralCol"}],
        [{"a", [{"href", "/id/uksi/2023/588"}], ["2023 No. 588"]}]},
       {"td", [{"class", "centralCol"}],
        [{"a", [{"href", "/id/uksi/2023/588/regulation/3"}], ["reg. 3"]}]},
       {"td", [], ["Not yet"]},
       {"td", [], []}
     ]
  }
  Returns
    %Amending{}
  """
  @spec parse_law(list()) :: %__MODULE__{}
  def parse_law(record) do
    Enum.with_index(record, fn cell, index -> {index, cell} end)
    |> Enum.reduce([], fn
      {0, {"td", _, [{_, _, [affected_title]}]}}, acc ->
        [String.trim(affected_title) | acc]

      {1, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
        {type_code, number, year} = Legl.Utility.type_number_year(path)
        year = String.to_integer(year)
        [path, year, number, type_code | acc]

      {2, {"td", _, content}}, acc ->
        # IO.inspect(content, label: "CONTENT: ")

        Enum.map(content, fn
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

      {3, {"td", [], []}}, acc ->
        ["" | acc]

      {4, _cell}, acc ->
        acc

      {5, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
        [path | acc]

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
          [
            :Title_EN,
            :type_code,
            :Number,
            :Year,
            :path,
            :target,
            :affect,
            :pathA,
            :applied?,
            :note
          ],
          &1
        )).()
    |> (&Kernel.struct(__MODULE__, &1)).()
  end
end
