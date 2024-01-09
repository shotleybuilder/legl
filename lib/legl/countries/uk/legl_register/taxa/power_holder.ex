defmodule Legl.Countries.Uk.LeglRegister.Taxa.PowerHolder do
  @moduledoc """
  Module to generate the content for power holder fields in the Legal Register Table

  ## Field Names in the LRT
    power_holder - multi-select field
    power_holder_article - long-text
    power_holder_article_clause - long-text
    article_power_holder - long-text
    article_power_holder_clause - long-text

  ## Field Names in the LAT
    Power_Holder
    Power_Holder_Aggregate
    power_holder_txt
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  @spec power_holder(list(%LATTaxa{})) :: map()
  def power_holder(records) do
    Map.put(
      %{},
      :power_holder,
      power_holder_uniq(records)
    )
  end

  @spec power_holder_uniq(list(%LATTaxa{})) :: list()
  defp power_holder_uniq(records) do
    Enum.map(records, fn %{Power_Holder: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()

    # |> IO.inspect(label: ~s[#{__MODULE__}.power_holder_uniq/1: ])
  end

  @spec power_holder_article(list(%LATTaxa{})) :: map()
  def power_holder_article(records) do
    records
    |> power_holder_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :power_holder_article, &1)).()

    # |> IO.inspect(label: ~s[#{__MODULE__}.uniq_powerholder_article/1: ])
  end

  @spec power_holder_article_clause(list(%LATTaxa{})) :: map()
  def power_holder_article_clause(records) do
    records
    |> create_power_holder_txt_aggregate_field()
    |> power_holder_aggregate(true)
    |> Enum.map(&clause_text_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :power_holder_article_clause, &1)).()
  end

  @spec create_power_holder_txt_aggregate_field(list(%LATTaxa{})) :: list(%LATTaxa{})
  defp create_power_holder_txt_aggregate_field(records) do
    records
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_keys()
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregates(:power_holder_txt, records)
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_result(
      :power_holder_txt_aggregate,
      records
    )
  end

  @spec power_holder_aggregate(list(%LATTaxa{})) :: list()
  defp power_holder_aggregate(records, clause? \\ false) do
    records
    |> power_holder_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          Power_Holder_Aggregate: values
        } = record,
        acc
        when rt in ["section", "article"] ->
          rt = if rt != "section", do: "regulation", else: rt

          case Enum.member?(values, member) do
            true ->
              url = ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/#{rt}/#{s}]

              case clause? do
                true ->
                  [{url, record.power_holder_txt_aggregate} | acc]

                false ->
                  [url | acc]
              end

            false ->
              acc
          end

        _record, acc ->
          acc
      end)
      |> Legl.Countries.Uk.LeglRegister.Taxa.natural_order_sort()
      |> (&[{member, &1} | col]).()
    end)
    |> Enum.reverse()
  end

  @spec clause_text_field(tuple()) :: binary()
  defp clause_text_field({k, v}) do
    content =
      Enum.map(v, fn {url, clauses} ->
        ~s/#{url}\n    #{Enum.join(clauses, "\n")}/
      end)
      |> Enum.join("\n")

    ~s/[#{k}]\n#{content}/
  end

  @spec article_power_holder(list(%LATTaxa{})) :: map()
  def article_power_holder(records) do
    records
    |> Enum.filter(fn %{Power_Holder_Aggregate: daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(& &1."ID", &{&1.url, &1."Power_Holder_Aggregate"})
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&Legl.Countries.Uk.LeglRegister.Taxa.article_xxx_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_power_holder, &1)).()

    # |> IO.inspect(label: ~s[#{__MODULE__}.article_powerholder/1: ])
  end

  @spec mod_id(%LATTaxa{}) :: %LATTaxa{}
  defp mod_id(%{ID: id} = record) do
    id = Regex.replace(~r/_*[A-Z]*$/, id, "")
    Map.put(record, :ID, id)
  end

  @spec article_power_holder_clause(list(%LATTaxa{})) :: map()
  def article_power_holder_clause(records) do
    records
    |> create_power_holder_txt_aggregate_field()
    |> Enum.filter(fn %{Power_Holder_Aggregate: daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(
      & &1."ID",
      &{&1.url, &1."Power_Holder_Aggregate", &1.power_holder_txt_aggregate}
    )
    |> Enum.sort_by(&elem(&1, 0), NaturalOrder)
    |> Enum.map(&Legl.Countries.Uk.LeglRegister.Taxa.article_xxx_clause_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_power_holder_clause, &1)).()
  end
end
