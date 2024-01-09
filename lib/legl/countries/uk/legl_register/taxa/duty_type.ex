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

  alias Legl.Countries.Uk.Article.Taxa.DutyTypeTaxa.DutyType

  def duty_type(records) do
    Map.put(
      %{},
      :duty_type,
      duty_type_uniq(records)
    )
  end

  @spec duty_type_uniq(list(%LATTaxa{})) :: list()
  defp duty_type_uniq(records) do
    Enum.map(records, fn %{"Duty Type": value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> DutyType.duty_type_sorter()
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
    end)
    |> Enum.reverse()
  end

  def duty_type_article(records) do
    records
    |> duty_type_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_type_article, &1)).()
  end

  def article_duty_type(records) do
    records
    |> Enum.filter(fn %{"Duty Type Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(& &1."ID", &{&1.url, &1."Duty Type Aggregate"})
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&article_duty_type_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_duty_type, &1)).()

    # |> IO.inspect()
  end

  @spec mod_id(%LATTaxa{}) :: %LATTaxa{}
  defp mod_id(%{ID: id} = record) do
    id = Regex.replace(~r/_*[A-Z]*$/, id, "")
    Map.put(record, :ID, id)
  end

  @spec article_duty_type_field(tuple()) :: binary()
  defp article_duty_type_field({_, [{url, terms}]} = _record) do
    ~s/#{url}\n#{terms |> Enum.sort() |> Enum.join("; ")}/
  end
end
