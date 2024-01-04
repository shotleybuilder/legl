defmodule Legl.Countries.Uk.LeglRegister.Taxa.DutyType do
  @moduledoc """
  Module to generate the content for duty type fields in the Legal Register Table

  ## Field Names in the LRT
    Duty Type - multi-select field
    duty_type - long-text
    duty_type_article - long-text
    article_duty_type - long-text

  ## Field Names in the LAT
    Duty Type
    Duty Type Aggregate
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def duty_type(records) do
    result =
      Enum.map(records, fn %{"Duty Type Aggregate": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    %{
      # duty_type: Legl.Utility.quote_list(result) |> Enum.join(","),
      "Duty Type": result
    }
  end

  @spec duty_type_uniq(list(%LATTaxa{})) :: list()
  defp duty_type_uniq(records) do
    Enum.map(records, fn %{"Duty Type": value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec duty_type_aggregate(list(%LATTaxa{})) :: list()
  defp duty_type_aggregate(records) do
    records
    |> duty_type_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          "Duty Type Aggregate": values
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

  def uniq_duty_type_article(records) do
    records
    |> duty_type_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_type, &1)).()
  end

  def duty_type_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :"Duty Type Aggregate"))
    |> Enum.group_by(& &1."Duty Type Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_type_article, &1)).()

    # |> IO.inspect()
  end

  def article_duty_type(records) do
    records
    |> Enum.filter(fn %{"Duty Type Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."Duty Type Aggregate")
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_duty_type, &1)).()

    # |> IO.inspect()
  end
end
