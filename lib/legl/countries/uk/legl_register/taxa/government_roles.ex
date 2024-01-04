defmodule Legl.Countries.Uk.LeglRegister.Taxa.GovernmentRoles do
  @moduledoc """
  Module to generate the content for Government Roles fields in the Legal Register Table

  ## Field Names in the LRT
    Duty Actor Gvt - multi-select field
    duty_actor_gvt - long-text
    duty_actor_gvt_article - long-text
    article_duty_actor_gvt - long-text

  ## Field Names in the LAT
    Duty Actor Gvt
    Duty Actor Gvt Aggregate
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def duty_actor_gvt(records) do
    result =
      Enum.map(records, fn %{"Duty Actor Gvt Aggregate": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    %{
      # duty_actor_gvt: Legl.Utility.quote_list(result) |> Enum.join(","),
      "Duty Actor Gvt": result
    }
  end

  @spec duty_actor_gvt_uniq(list(%LATTaxa{})) :: list()
  defp duty_actor_gvt_uniq(records) do
    Enum.map(records, fn %{"Duty Actor Gvt": value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec duty_actor_gvt_aggregate(list(%LATTaxa{})) :: list()
  defp duty_actor_gvt_aggregate(records) do
    records
    |> duty_actor_gvt_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          "Duty Actor Gvt Aggregate": values
        } = _record,
        acc
        when rt in ["section", "article"] ->
          rt = if rt != "section", do: "regulation", else: rt

          case Enum.member?(values, member) do
            true ->
              url = ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/#{rt}/#{s}]
              [url | acc]

            false ->
              acc
          end

        _record, acc ->
          acc
      end)
      |> Enum.sort(NaturalOrder)
      |> (&[{member, &1} | col]).()
      |> Enum.reverse()
    end)
  end

  def uniq_duty_actor_gvt_article(records) do
    records
    |> duty_actor_gvt_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_actor_gvt, &1)).()
  end

  def duty_actor_gvt_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :"Duty Actor Gvt Aggregate"))
    |> Enum.group_by(& &1."Duty Actor Gvt Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_actor_gvt_article, &1)).()

    # |> IO.inspect()
  end

  def article_duty_actor_gvt(records) do
    records
    |> Enum.filter(fn %{"Duty Actor Gvt Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."Duty Actor Gvt Aggregate")
    |> Enum.sort()
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_duty_actor_gvt, &1)).()

    # |> IO.inspect()
  end
end
