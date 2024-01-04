defmodule Legl.Countries.Uk.LeglRegister.Taxa.Popimar do
  @moduledoc """
  Module to generate the content for POPIMAR fields in the Legal Register Table

  ## Field Names in the LRT
    POPIMAR - multi-select field
    popimar_ - long-text
    popimar_article - long-text
    article_popimar - long-text

  ## Field Names in the LAT
    POPIMAR
    POPIMAR Aggregate
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def popimar(records) do
    result =
      Enum.map(records, fn %{"POPIMAR Aggregate": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    %{
      # popimar_: Legl.Utility.quote_list(result) |> Enum.join(","),
      POPIMAR: result
    }
  end

  @spec popimar_uniq(list(%LATTaxa{})) :: list()
  defp popimar_uniq(records) do
    Enum.map(records, fn %{POPIMAR: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec popimar_aggregate(list(%LATTaxa{})) :: list()
  defp popimar_aggregate(records) do
    records
    |> popimar_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          "POPIMAR Aggregate": values
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

  def uniq_popimar_article(records) do
    records
    |> popimar_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :popimar_, &1)).()
  end

  def popimar_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :"Duty Actor Aggregate"))
    |> Enum.group_by(& &1."POPIMAR Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :popimar_article, &1)).()

    # |> IO.inspect()
  end

  def article_popimar(records) do
    records
    |> Enum.filter(fn %{"POPIMAR Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."POPIMAR Aggregate")
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_popimar, &1)).()

    # |> IO.inspect()
  end
end
