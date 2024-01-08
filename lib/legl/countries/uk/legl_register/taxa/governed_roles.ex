defmodule Legl.Countries.Uk.LeglRegister.Taxa.GovernedRoles do
  @moduledoc """
  Module to generate the content for Governed Roles fields in the Legal Register Table

  ## Field Names in the LRT
    Duty Actor - multi-select field
    duty_actor - long-text
    duty_actor_article - long-text
    article_duty_actor - long-text

  ## Field Names in the LAT
    Duty Actor
    Duty Actor Aggregate
  """
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa

  def actor(records) do
    %{
      actor: actor_uniq(records)
    }
  end

  @spec actor_uniq(list(%LATTaxa{})) :: list()
  defp actor_uniq(records) do
    Enum.map(records, fn %{"Duty Actor": value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec actor_aggregate(list(%LATTaxa{})) :: list()
  defp actor_aggregate(records) do
    records
    |> actor_uniq
    |> Enum.reduce([], fn member, col ->
      Enum.reduce(records, [], fn
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: ["section"],
          "Section||Regulation": s,
          "Duty Actor Aggregate": values
        } = _record,
        acc ->
          case Enum.member?(values, member) do
            true ->
              url = ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/section/#{s}]
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

  @spec actor_article(list(%LATTaxa{})) :: map()
  def actor_article(records) do
    records
    |> actor_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :actor_article, &1)).()
  end

  def article_actor(records) do
    records
    |> Enum.filter(fn %{"Duty Actor Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.map(&mod_id(&1))
    |> Enum.group_by(& &1."ID", &{&1.url, &1."Duty Actor Aggregate"})
    |> Enum.sort_by(&elem(&1, 0), NaturalOrder)
    |> Enum.map(&build(&1))
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_actor, &1)).()
  end

  defp mod_id(%{ID: id} = record) do
    id = Regex.replace(~r/_*[A-Z]*$/, id, "")
    Map.put(record, :ID, id)
  end

  defp build({_, [{url, terms}]} = _record) do
    ~s/#{url}\n#{terms |> Enum.sort() |> Enum.join("; ")}/
  end
end
