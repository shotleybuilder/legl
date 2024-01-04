defmodule Legl.Countries.Uk.LeglRegister.Taxa.PowerHolder do
  @moduledoc """
  Module to generate the content for power holder fields in the Legal Register Table

  ## Field Names in the LRT
    Power Holder - multi-select field
    power_holder - long-text
    power_holder_article - long-text
    article_power_holder - long-text

  ## Field Names in the LAT
    Power_Holder
    Power_Holder_Aggregate
    power_holder_txt
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  @spec powerholder(list(%LATTaxa{})) :: map()
  def powerholder(records) do
    result =
      Enum.map(records, fn %{Power_Holder_Aggregate: value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
      |> IO.inspect(label: ~s[#{__MODULE__}.powerholder/1: ])

    %{
      # duty_holder: Legl.Utility.quote_list(result) |> Enum.join(","),
      "Power Holder": result
    }
  end

  @spec powerholder_uniq(list(%LATTaxa{})) :: list()
  defp powerholder_uniq(records) do
    Enum.map(records, fn %{Power_Holder: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
    |> IO.inspect(label: ~s[#{__MODULE__}.powerholder_uniq/1: ])
  end

  @spec powerholder_aggregate(list(%LATTaxa{})) :: list()
  defp powerholder_aggregate(records) do
    records
    |> powerholder_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          Power_Holder_Aggregate: values
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
      |> IO.inspect(label: ~s[#{__MODULE__}.powerholder_aggregate/1: ])
    end)
  end

  @spec uniq_powerholder_article(list(%LATTaxa{})) :: map()
  def uniq_powerholder_article(records) do
    records
    |> powerholder_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :power_holder, &1)).()
    |> IO.inspect(label: ~s[#{__MODULE__}.uniq_powerholder_article/1: ])
  end

  @spec powerholder_article(list(%LATTaxa{})) :: map()
  def powerholder_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :Power_Holder_Aggregate))
    |> Enum.group_by(& &1."Power_Holder_Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :power_holder_article, &1)).()
    |> IO.inspect(label: ~s[#{__MODULE__}.powerholder_article/1: ])
  end

  @spec article_powerholder(list(%LATTaxa{})) :: map()
  def article_powerholder(records) do
    records
    |> Enum.filter(fn %{Power_Holder_Aggregate: daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."Power_Holder_Aggregate")
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_power_holder, &1)).()
    |> IO.inspect(label: ~s[#{__MODULE__}.article_powerholder/1: ])
  end
end
