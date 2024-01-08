defmodule Legl.Countries.Uk.LeglRegister.Taxa.ResponsibilityHolder do
  @moduledoc """
  Module to generate the content for responsibility holder fields in the Legal Register Table

  ## Field Names in the LRT
    responsibility_holder - multi-select field
    responsibility_holder_article - long-text
    responsibility_holder_article_clause - long-text
    article_responsibility_holder - long-text
    article_responsibility_holder_clause - long text

  ## Field Names in the LAT
    Responsibility_Holder
    Responsibility_Holder_Aggregate
    responsibility_holder_txt
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def responsibility_holder(records) do
    %{responsibility_holder: responsibility_holder_uniq(records)}
  end

  @spec responsibility_holder_uniq(list(%LATTaxa{})) :: list()
  defp responsibility_holder_uniq(records) do
    Enum.map(records, fn %{Responsibility_Holder: value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec responsibility_holder_aggregate(list(%LATTaxa{})) :: list()
  defp responsibility_holder_aggregate(records, clause? \\ false) do
    records
    |> responsibility_holder_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: [rt],
          "Section||Regulation": s,
          Responsibility_Holder_Aggregate: values
        } = record,
        acc
        when rt in ["section", "article"] ->
          rt = if rt != "section", do: "regulation", else: rt

          case Enum.member?(values, member) do
            true ->
              url = ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/#{rt}/#{s}]

              IO.puts(
                ~s/text: #{record.responsibility_holder_txt_aggregate}\nurl: #{url}\nclause?: #{clause?}/
              )

              case clause? do
                true ->
                  [{url, record.responsibility_holder_txt_aggregate} | acc]

                false ->
                  [url | acc]
              end

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

  @spec responsibility_holder_article(list(%LATTaxa{})) :: map()
  def responsibility_holder_article(records) do
    records
    |> responsibility_holder_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :responsibility_holder_article, &1)).()
  end

  @spec responsibility_holder_article_clause(list(%LATTaxa{})) :: map()
  def responsibility_holder_article_clause(records) do
    records
    |> create_responsibility_holder_txt_aggregate_field()
    |> responsibility_holder_aggregate(true)
    |> Enum.map(&clause_text_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :responsibility_holder_article_clause, &1)).()
  end

  @spec create_responsibility_holder_txt_aggregate_field(list(%LATTaxa{})) :: list(%LATTaxa{})
  defp create_responsibility_holder_txt_aggregate_field(records) do
    records
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_keys()
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregates(:responsibility_holder_txt, records)
    |> Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_result(
      :responsibility_holder_txt_aggregate,
      records
    )
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

  @spec article_responsibility_holder(list(%LATTaxa{})) :: map()
  def article_responsibility_holder(records) do
    records
    |> Enum.filter(fn %{Responsibility_Holder_Aggregate: daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(& &1."ID", &{&1.url, &1."Responsibility_Holder_Aggregate"})
    |> Enum.sort_by(&elem(&1, 0), NaturalOrder)
    |> Enum.map(&article_responsibility_holder_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_responsibility_holder, &1)).()
  end

  @spec mod_id(%LATTaxa{}) :: %LATTaxa{}
  defp mod_id(%{ID: id} = record) do
    id = Regex.replace(~r/_*[A-Z]*$/, id, "")
    Map.put(record, :ID, id)
  end

  @spec article_responsibility_holder_field(tuple()) :: binary()
  defp article_responsibility_holder_field({_, [{url, terms}]} = _record) do
    ~s/#{url}\n#{terms |> Enum.sort() |> Enum.join("; ")}/
  end

  @spec article_responsibility_holder_clause(list(%LATTaxa{})) :: map()
  def article_responsibility_holder_clause(records) do
    records
    |> create_responsibility_holder_txt_aggregate_field()
    |> Enum.filter(fn %{Responsibility_Holder_Aggregate: daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(
      & &1."ID",
      &{&1.url, &1."Responsibility_Holder_Aggregate", &1.responsibility_holder_txt_aggregate}
    )
    |> Enum.sort_by(&elem(&1, 0), NaturalOrder)
    |> IO.inspect()
    |> Enum.map(&article_responsibility_holder_clause_field(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_responsibility_holder_clause, &1)).()
  end

  @spec article_responsibility_holder_clause_field(tuple()) :: binary()
  defp article_responsibility_holder_clause_field({_, [{url, actors_gvt, clauses}]}) do
    content =
      Enum.zip(actors_gvt, clauses)
      |> Enum.map(fn {actor, clause} -> ~s/#{actor} -> #{clause}/ end)

    ~s/#{url}\n#{Enum.join(content, "\n")}/
  end
end
