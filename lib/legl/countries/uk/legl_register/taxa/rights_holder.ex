defmodule Legl.Countries.Uk.LeglRegister.Taxa.RightsHolder do
  @moduledoc """
  Module to generate the content for RightsHolder fields in the Legal Register Table

  ## Field Names
    Rightsholder
    rights_holder
    rightsholder_article
    article_rightsholder
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  @spec rightsholder(list(%LATTaxa{})) :: map()
  def rightsholder(records) do
    result =
      Enum.map(records, fn %{"Rightsholder Aggregate": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
      |> IO.inspect(label: ~s[#{__MODULE__}.rightsholder/1: ])

    %{
      # duty_holder: Legl.Utility.quote_list(result) |> Enum.join(","),
      Rightsholder: result
    }
  end

  @spec rightsholder_uniq(list(%LATTaxa{})) :: list()
  defp rightsholder_uniq(records) do
    Enum.map(records, fn %{Rightsholder: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
    |> IO.inspect(label: ~s[#{__MODULE__}.rightsholder_uniq/1: ])
  end

  @spec rightsholder_aggregate(list(%LATTaxa{})) :: list()
  defp rightsholder_aggregate(records) do
    records
    |> rightsholder_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          "Rightsholder Aggregate": values
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
      |> IO.inspect(label: ~s[#{__MODULE__}.rightsholder_aggregate/1: ])
    end)
  end

  @spec rightsholder_aggregate(list(%LATTaxa{})) :: map()
  def uniq_rightsholder_article(records) do
    records
    |> rightsholder_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :rights_holder, &1)).()
    |> IO.inspect(label: ~s[#{__MODULE__}.uniq_rightsholder_article/1: ])
  end

  @spec rightsholder_article(list(%LATTaxa{})) :: map()
  def rightsholder_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :"Rightsholder Aggregate"))
    |> Enum.group_by(& &1."Rightsholder Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :rightsholder_article, &1)).()
    |> IO.inspect(label: ~s[#{__MODULE__}.rightsholder_article/1: ])
  end

  @spec article_rightsholder(list(%LATTaxa{})) :: map()
  def article_rightsholder(records) do
    records
    |> Enum.filter(fn %{"Rightsholder Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."Rightsholder Aggregate")
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_rightsholder, &1)).()
    |> IO.inspect(label: ~s[#{__MODULE__}.article_rightsholder/1: ])
  end
end
