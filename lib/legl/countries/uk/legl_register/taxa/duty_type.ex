defmodule Legl.Countries.Uk.LeglRegister.Taxa.DutyType do
  @moduledoc """
  Module to generate the content for duty type fields in the Legal Register Table

  ## Field Names in the LRT
    duty_type - multi-select field
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
          type_code: type_code,
          Year: year,
          Number: number,
          Record_Type: [rt],
          "Section||Regulation": s,
          "Duty Type Aggregate": values
        } = _record,
        acc
        when rt in ["section", "article"] ->
          rt = if rt != "section", do: "regulation", else: rt

          [tc | _] = if is_list(type_code), do: type_code, else: [type_code]
          [y | _] = if is_list(year), do: year, else: [year]
          [n | _] = if is_list(number), do: number, else: [number]

          case Enum.member?(values, member) do
            true ->
              url = ~s[https://legislation.gov.uk/#{tc}/#{y}/#{n}/#{rt}/#{s}]
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
    |> Enum.map(&Legl.Countries.Uk.LeglRegister.Taxa.article_xxx_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_duty_type, &1)).()

    # |> IO.inspect()
  end

  @spec mod_id(%LATTaxa{}) :: %LATTaxa{}
  defp mod_id(%{ID: id} = record) do
    id = Regex.replace(~r/_*[A-Z]*$/, id, "")
    Map.put(record, :ID, id)
  end
end
