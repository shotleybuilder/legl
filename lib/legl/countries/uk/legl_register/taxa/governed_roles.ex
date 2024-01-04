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

  def duty_actor(records) do
    result =
      Enum.map(records, fn %{"Duty Actor Aggregate": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    %{
      # duty_actor: Legl.Utility.quote_list(result) |> Enum.join(","),
      "Duty Actor": result
    }
  end

  @spec duty_actor_uniq(list(%LATTaxa{})) :: list()
  defp duty_actor_uniq(records) do
    Enum.map(records, fn %{"Duty Actor": value} ->
      value
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec duty_actor_aggregate(list(%LATTaxa{})) :: list()
  defp duty_actor_aggregate(records) do
    records
    |> duty_actor_uniq
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
      |> Enum.reverse()
    end)
  end

  def uniq_duty_actor_article(records) do
    records
    |> duty_actor_aggregate()
    |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_actor, &1)).()
  end

  @spec duty_actor_article(list(%LATTaxa{})) :: struct()
  def duty_actor_article(records) do
    records
    |> Enum.map(&LRTT.sorter(&1, :"Duty Actor Aggregate"))
    # |> IO.inspect(label: "duty_actor_article", limit: :infinity)
    |> Enum.group_by(& &1."Duty Actor Aggregate")
    |> Enum.filter(fn {k, _} -> k != [] end)
    |> Enum.map(fn {k, v} ->
      {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
    end)
    |> Enum.sort()
    |> Enum.map(&LRTT.taxa_article/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :duty_actor_article, &1)).()

    # |> IO.inspect()
  end

  def article_duty_actor(records) do
    records
    |> Enum.filter(fn %{"Duty Actor Aggregate": daa} -> daa != [] end)
    |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
    |> Enum.group_by(& &1.url, & &1."Duty Actor Aggregate")
    |> Enum.sort()
    |> Enum.map(&LRTT.article_taxa/1)
    |> Enum.join("\n\n")
    |> (&Map.put(%{}, :article_duty_actor, &1)).()

    # |> IO.inspect()
  end
end
