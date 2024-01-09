defmodule Legl.Countries.Uk.LeglRegister.Taxa.GovernmentRoles do
  @moduledoc """
  Module to generate the content for Government Roles fields in the Legal Register Table

  ## Field Names in the LRT
    actor_gvt - multi-select field
    actor_gvt_article - long-text
    article_actor_gvt - long-text

  ## Field Names in the LAT
    Duty Actor Gvt
    Duty Actor Gvt Aggregate
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def actor_gvt(records) do
    result = actor_gvt_uniq(records)

    %{
      actor_gvt: result
    }
  end

  @spec actor_gvt_uniq(list(%LATTaxa{})) :: list()
  defp actor_gvt_uniq(records) do
    Enum.map(records, fn %{"Duty Actor Gvt": value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec actor_gvt_aggregate(list(%LATTaxa{})) :: list()
  defp actor_gvt_aggregate(records) do
    records
    |> actor_gvt_uniq
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
    end)
    |> Enum.reverse()
  end

  def actor_gvt_article(records) do
    records
    |> actor_gvt_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :actor_gvt_article, &1)).()
  end

  def article_actor_gvt(records) do
    records
    |> Enum.filter(fn %{"Duty Actor Gvt Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(& &1."ID", &{&1.url, &1."Duty Actor Gvt Aggregate"})
    |> Enum.sort_by(&elem(&1, 0), NaturalOrder)
    |> Enum.map(&Legl.Countries.Uk.LeglRegister.Taxa.article_xxx_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_actor_gvt, &1)).()
  end

  defp mod_id(%{ID: id} = record) do
    id = Regex.replace(~r/_*[A-Z]*$/, id, "")
    Map.put(record, :ID, id)
  end
end
