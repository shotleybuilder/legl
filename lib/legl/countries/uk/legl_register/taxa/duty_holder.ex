defmodule Legl.Countries.Uk.LeglRegister.Taxa.DutyHolder do
  @moduledoc """
  Module to generate the content for duty holder fields in the Legal Register Table

  ## Field Names in the LRT
    Dutyholder - multi-select field
    duty_holder - long-text
    dutyholder_article - long-text
    article_dutyholder - long-text

  ## Field Names in the LAT
    Dutyholder
    Dutyholder Aggregate
    dutyholder_txt
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def dutyholder(records) do
    result =
      Enum.map(records, fn %{"Dutyholder Aggregate": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    %{
      # duty_holder: Legl.Utility.quote_list(result) |> Enum.join(","),
      Dutyholder: result
    }
  end

  @spec dutyholder_uniq(list(%LATTaxa{})) :: list()
  defp dutyholder_uniq(records) do
    Enum.map(records, fn %{Dutyholder: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec dutyholder_aggregate(list(%LATTaxa{})) :: list()
  defp dutyholder_aggregate(records) do
    records
    |> dutyholder_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          "Dutyholder Aggregate": values
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

  def uniq_dutyholder_article(records) do
    records
    |> dutyholder_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_holder, &1)).()
  end

  def dutyholder_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :"Dutyholder Aggregate"))
    |> Enum.group_by(& &1."Dutyholder Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :dutyholder_article, &1)).()

    # |> IO.inspect()
  end

  def article_dutyholder(records) do
    records
    |> Enum.filter(fn %{"Dutyholder Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."Dutyholder Aggregate")
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_dutyholder, &1)).()

    # |> IO.inspect()
  end
end
