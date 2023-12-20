defmodule Legl.Countries.Uk.Article.Taxa.LRTTaxa do
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
    result = Kernel.struct(result, __MODULE__.DutyActorGvt.duty_actor_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyActorGvt.duty_actor_gvt_article(records))
    result = Kernel.struct(result, __MODULE__.DutyActorGvt.article_duty_actor_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.dutyholder(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.dutyholder_article(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.article_dutyholder(records))
    result = Kernel.struct(result, __MODULE__.DutyHolderGvt.dutyholder_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyHolderGvt.dutyholder_gvt_article(records))
    result = Kernel.struct(result, __MODULE__.DutyHolderGvt.article_dutyholder_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyType.duty_type(records))
    result = Kernel.struct(result, __MODULE__.DutyType.duty_type_article(records))
    result = Kernel.struct(result, __MODULE__.DutyType.article_duty_type(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.popimar(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.popimar_article(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.article_popimar(records))
    result
  end

  def leg_gov_uk(%{type_code: [tc], Year: [y], Number: [number], Heading: h} = _record) do
    case tc do
      "uksi" ->
        ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/regulation/#{h}]
    end
  end

  @spec article_taxa(tuple()) :: binary()
  def article_taxa({k, v}) do
    v =
      v
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join(", ")

    ~s/#{k}📌[#{v}]/
  end

  defmodule DutyActor do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT

    def duty_actor(records) do
      result =
        Enum.map(records, fn %{"Duty Actor Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        duty_actor: Legl.Utility.quote_list(result) |> Enum.join(","),
        "Duty Actor": result
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
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_duty_actor, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyActorGvt do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT

    def duty_actor_gvt(records) do
      result =
        Enum.map(records, fn %{"Duty Actor Gvt Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        duty_actor_gvt: Legl.Utility.quote_list(result) |> Enum.join(","),
        "Duty Actor Gvt": result
      }
    end

    def duty_actor_gvt_article(records) do
      Enum.group_by(records, & &1."Duty Actor Gvt Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.join("📌")}/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :duty_actor_gvt_article, &1)).()

      # |> IO.inspect()
    end

    def article_duty_actor_gvt(records) do
      records
      |> Enum.filter(fn %{"Duty Actor Gvt Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Duty Actor Gvt Aggregate")
      |> Enum.sort()
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_duty_actor_gvt, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyHolder do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT

    def dutyholder(records) do
      result =
        Enum.map(records, fn %{"Dutyholder Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        duty_holder: Legl.Utility.quote_list(result) |> Enum.join(","),
        Dutyholder: result
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
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.uniq() |> Enum.join("📌")}/
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
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_dutyholder, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyHolderGvt do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT

    def dutyholder_gvt(records) do
      result =
        Enum.map(records, fn %{"Dutyholder Gvt Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        duty_holder_gvt: Legl.Utility.quote_list(result) |> Enum.join(","),
        "Dutyholder Gvt": result
      }
    end

    def dutyholder_gvt_article(records) do
      Enum.group_by(records, & &1."Dutyholder Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(fn {k, v} ->
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.uniq() |> Enum.join("📌")}/
      end)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :dutyholder_gvt_article, &1)).()

      # |> IO.inspect()
    end

    def article_dutyholder_gvt(records) do
      records
      |> Enum.filter(fn %{"Dutyholder Gvt Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Dutyholder Gvt Aggregate")
      |> Enum.sort()
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_dutyholder_gvt, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyType do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT

    def duty_type(records) do
      result =
        Enum.map(records, fn %{"Duty Type Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        duty_type: Legl.Utility.quote_list(result) |> Enum.join(","),
        "Duty Type": result
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
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.uniq() |> Enum.join("📌")}/
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
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_duty_type, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule POPIMAR do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT

    def popimar(records) do
      result =
        Enum.map(records, fn %{"POPIMAR Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        popimar_: Legl.Utility.quote_list(result) |> Enum.join(","),
        POPIMAR: result
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
        ~s/[#{Enum.join(k, ", ")}]📌#{Enum.sort(v) |> Enum.uniq() |> Enum.join("📌")}/
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
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("📌📌")
      |> (&Map.put(%{}, :article_popimar, &1)).()

      # |> IO.inspect()
    end
  end
end
