defmodule Legl.Countries.Uk.LeglRegister.Taxa.ResponsibilityHolder do
  @moduledoc """
  Module to generate the content for responsibility holder fields in the Legal Register Table

  ## Field Names in the LRT
    Responsibility Holder - multi-select field
    responsibility_holder - long-text
    responsibility_article - long-text
    article_responsibility - long-text

  ## Field Names in the LAT
    Responsibility_Holder
    Responsibility_Holder_Aggregate
    responsibility_holder_txt
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def responsibilityholder(records) do
    result =
      Enum.map(records, fn %{Responsibility_Holder_Aggregate: value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    %{
      # duty_holder_gvt: Legl.Utility.quote_list(result) |> Enum.join(","),
      "Responsibility Holder": result
    }
  end

  @spec responsibilityholder_uniq(list(%LATTaxa{})) :: list()
  defp responsibilityholder_uniq(records) do
    Enum.map(records, fn %{Responsibility_Holder: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec responsibilityholder_aggregate(list(%LATTaxa{})) :: list()
  defp responsibilityholder_aggregate(records) do
    records
    |> responsibilityholder_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          Responsibility_Holder_Aggregate: values
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

  def uniq_responsibilityholder_article(records) do
    records
    |> responsibilityholder_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_holder_gvt, &1)).()
  end

  def responsibilityholder_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :Responsibility_Holder_Aggregate))
    |> Enum.group_by(& &1."Responsibility_Holder_Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :responsibility_article, &1)).()

    # |> IO.inspect()
  end

  def article_responsibilityholder(records) do
    records
    |> Enum.filter(fn %{Responsibility_Holder_Aggregate: daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."Responsibility_Holder_Aggregate")
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_responsibility, &1)).()

    # |> IO.inspect()
  end
end
