defmodule Legl.Countries.Uk.LeglRegister.Taxa.DutyHolder do
  @moduledoc """
  Module to generate the content for duty holder fields in the Legal Register Table

  ## Field Names in the LRT
    duty_holder - multi-select field
    duty_holder_article - long-text
    duty_holder_article_clause - long-text
    article_duty_holder - long-text
    article_duty_holder_clause - long-text

  ## Field Names in the LAT
    Dutyholder
    Dutyholder Aggregate
    dutyholder_txt
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def duty_holder(records) do
    Map.put(
      %{},
      :duty_holder,
      duty_holder_uniq(records)
    )
  end

  @spec duty_holder_uniq(list(%LATTaxa{})) :: list()
  defp duty_holder_uniq(records) do
    Enum.map(records, fn %{Dutyholder: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec duty_holder_aggregate(list(%LATTaxa{})) :: list()
  defp duty_holder_aggregate(records) do
    records
    |> duty_holder_uniq
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

  @spec duty_holder_article(list(%LATTaxa{})) :: map()
  def duty_holder_article(records) do
    records
    |> duty_holder_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_holder, &1)).()
  end

  @spec duty_holder_article_clause(list(%LATTaxa{})) :: map()
  def duty_holder_article_clause(records) do
    records
    |> create_duty_holder_txt_aggregate_field()
    |> duty_holder_aggregate(true)
    |> Enum.map(&clause_text_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_holder_article_clause, &1)).()
  end

  @spec create_duty_holder_txt_aggregate_field(list(%LATTaxa{})) :: list(%LATTaxa{})
  def create_duty_holder_txt_aggregate_field(records) do
    records
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_keys()
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregates(:dutyholder_txt, records)
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_result(
      :duty_holder_txt_aggregate,
      records
    )
  end

  @spec duty_holder_aggregate(list(%LATTaxa{})) :: list()
  defp duty_holder_aggregate(records, clause? \\ false) do
    records
    |> duty_holder_uniq
    |> Enum.reduce([], fn member, collector ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          "Dutyholder Aggregate": duty_holder_aggregate
        } = record,
        acc
        when rt in ["section", "article"] ->
          rt = if rt != "section", do: "regulation", else: rt

          case Enum.member?(duty_holder_aggregate, member) do
            true ->
              url = ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/#{rt}/#{s}]

              case clause? do
                true ->
                  [{url, record.duty_holder_txt_aggregate} | acc]

                false ->
                  [url | acc]
              end

            false ->
              acc
          end

        _record, acc ->
          acc
      end)
      |> natural_order_sort()
      |> (&[{member, &1} | collector]).()
    end)
    |> Enum.reverse()
  end

  defp natural_order_sort([]), do: []

  defp natural_order_sort(values) do
    case hd(values) do
      v when is_tuple(v) ->
        Enum.sort_by(values, &elem(&1, 0), NaturalOrder)

      v when is_binary(v) ->
        Enum.sort(NaturalOrder)
    end
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

  def article_duty_holder(records) do
    records
    |> Enum.filter(fn %{"Dutyholder Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(& &1."ID", &{&1.url, &1."Dutyholder Aggregate"})
    |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
    |> Enum.map(&article_duty_holder_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_duty_holder, &1)).()

    # |> IO.inspect()
  end

  @spec mod_id(%LATTaxa{}) :: %LATTaxa{}
  defp mod_id(%{ID: id} = record) do
    id = Regex.replace(~r/_*[A-Z]*$/, id, "")
    Map.put(record, :ID, id)
  end

  @spec article_duty_holder_field(tuple()) :: binary()
  defp article_duty_holder_field({_, [{url, terms}]} = _record) do
    ~s/#{url}\n#{terms |> Enum.sort() |> Enum.join("; ")}/
  end

  @spec article_duty_holder_clause(list(%LATTaxa{})) :: map()
  def article_duty_holder_clause(records) do
    records
    |> create_duty_holder_txt_aggregate_field()
    |> Enum.filter(fn %{"Dutyholder Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(
      & &1."ID",
      &{&1.url, &1."Dutyholder Aggregate", &1.duty_holder_txt_aggregate}
    )
    |> Enum.sort_by(&elem(&1, 0), NaturalOrder)
    |> Enum.map(&article_duty_holder_clause_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_duty_holder_clause, &1)).()
  end

  @spec article_duty_holder_clause_field(tuple()) :: binary()
  defp article_duty_holder_clause_field({_, [{url, actors_gvt, clauses}]}) do
    content =
      Enum.zip(actors_gvt, clauses)
      |> Enum.map(fn {actor, clause} -> ~s/#{actor} -> #{clause}/ end)

    ~s/#{url}\n#{Enum.join(content, "\n")}/
  end
end
