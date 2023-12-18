defmodule Legl.Countries.Uk.AtArticle.AtTaxa.LRTTaxa do
  @moduledoc """
  Functions to build the content of the Taxa family of fields in the Legal Register Table
  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  @spec workflow(list()) :: %LR{}
  def workflow(records) do
    workflow(records, %LR{})
  end

  @spec workflow(list(), %LR{}) :: %LR{}
  def workflow(records, result) do
    result = Kernel.struct(result, __MODULE__.DutyActor.duty_actor(records))
    result = Kernel.struct(result, __MODULE__.DutyActor.duty_actor_article(records))
    result = Kernel.struct(result, __MODULE__.DutyActor.article_duty_actor(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.dutyholder(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.dutyholder_article(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.article_dutyholder(records))
    result = Kernel.struct(result, __MODULE__.DutyType.duty_type(records))
    result = Kernel.struct(result, __MODULE__.DutyType.duty_type_article(records))
    result = Kernel.struct(result, __MODULE__.DutyType.article_duty_type(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.popimar(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.popimar_article(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.article_popimar(records))
    result
  end

  def leg_gov_uk(
        %{type_code: [tc], Year: [y], Number: [number], "Section||Regulation": sr} = _record
      ) do
    case tc do
      "uksi" ->
        ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/regulation/#{sr}]
    end
  end

  defmodule DutyActor do
    alias Legl.Countries.Uk.AtArticle.AtTaxa.LRTTaxa, as: LRTT

    def duty_actor(records) do
      result =
        Enum.map(records, fn %{"Duty Actor Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        duty_actor: Enum.join(result, ","),
        Duty_Actor: Legl.Utility.csv_quote_enclosure(result)
      }
    end

    def duty_actor_article(records) do
      Enum.group_by(records, & &1."Duty Actor Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.join("📌")}/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :duty_actor_article, &1)).()

      # |> IO.inspect()
    end

    def article_duty_actor(records) do
      records
      |> Enum.filter(fn %{"Duty Actor Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Duty Actor Aggregate")
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/#{k}📌[#{List.flatten(v) |> Enum.sort() |> Enum.join(", ")}]/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_duty_actor, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyHolder do
    alias Legl.Countries.Uk.AtArticle.AtTaxa.LRTTaxa, as: LRTT

    def dutyholder(records) do
      result =
        Enum.map(records, fn %{"Dutyholder Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        dutyholder: Enum.join(result, ","),
        Dutyholder: Legl.Utility.csv_quote_enclosure(result)
      }
    end

    def dutyholder_article(records) do
      Enum.group_by(records, & &1."Dutyholder Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.join("📌")}/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :dutyholder_article, &1)).()

      # |> IO.inspect()
    end

    def article_dutyholder(records) do
      records
      |> Enum.filter(fn %{"Dutyholder Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Dutyholder Aggregate")
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/#{k}📌[#{List.flatten(v) |> Enum.sort() |> Enum.join(", ")}]/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_dutyholder, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyType do
    alias Legl.Countries.Uk.AtArticle.AtTaxa.LRTTaxa, as: LRTT

    def duty_type(records) do
      result =
        Enum.map(records, fn %{"Duty Type Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        duty_type: Enum.join(result, ","),
        Duty_Type: Legl.Utility.csv_quote_enclosure(result)
      }
    end

    def duty_type_article(records) do
      Enum.group_by(records, & &1."Duty Type Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.join("📌")}/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :duty_type_article, &1)).()

      # |> IO.inspect()
    end

    def article_duty_type(records) do
      records
      |> Enum.filter(fn %{"Duty Type Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Duty Type Aggregate")
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/#{k}📌[#{List.flatten(v) |> Enum.sort() |> Enum.join(", ")}]/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_duty_type, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule POPIMAR do
    alias Legl.Countries.Uk.AtArticle.AtTaxa.LRTTaxa, as: LRTT

    def popimar(records) do
      result =
        Enum.map(records, fn %{"POPIMAR Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        popimar: Enum.join(result, ","),
        POPIMAR: Legl.Utility.csv_quote_enclosure(result)
      }
    end

    def popimar_article(records) do
      Enum.group_by(records, & &1."POPIMAR Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.join("📌")}/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :popimar_article, &1)).()

      # |> IO.inspect()
    end

    def article_popimar(records) do
      records
      |> Enum.filter(fn %{"POPIMAR Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."POPIMAR Aggregate")
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/#{k}📌[#{List.flatten(v) |> Enum.sort() |> Enum.join(", ")}]/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_popimar, &1)).()

      # |> IO.inspect()
    end
  end
end
