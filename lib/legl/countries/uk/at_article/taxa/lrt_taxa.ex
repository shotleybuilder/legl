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
    result = Kernel.struct(result, __MODULE__.DutyActor.uniq_duty_actor_article(records))

    result = Kernel.struct(result, __MODULE__.DutyActorGvt.duty_actor_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyActorGvt.duty_actor_gvt_article(records))
    result = Kernel.struct(result, __MODULE__.DutyActorGvt.article_duty_actor_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyActorGvt.uniq_duty_actor_gvt_article(records))

    result = Kernel.struct(result, __MODULE__.DutyHolder.dutyholder(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.dutyholder_article(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.article_dutyholder(records))
    result = Kernel.struct(result, __MODULE__.DutyHolder.uniq_dutyholder_article(records))

    result = Kernel.struct(result, __MODULE__.DutyHolderGvt.dutyholder_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyHolderGvt.dutyholder_gvt_article(records))
    result = Kernel.struct(result, __MODULE__.DutyHolderGvt.article_dutyholder_gvt(records))
    result = Kernel.struct(result, __MODULE__.DutyHolderGvt.uniq_dutyholder_gvt_article(records))

    result = Kernel.struct(result, __MODULE__.DutyType.duty_type(records))
    result = Kernel.struct(result, __MODULE__.DutyType.duty_type_article(records))
    result = Kernel.struct(result, __MODULE__.DutyType.article_duty_type(records))
    result = Kernel.struct(result, __MODULE__.DutyType.uniq_duty_type_article(records))

    result = Kernel.struct(result, __MODULE__.POPIMAR.popimar(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.popimar_article(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.article_popimar(records))
    result = Kernel.struct(result, __MODULE__.POPIMAR.uniq_popimar_article(records))
    result
  end

  def leg_gov_uk(%{type_code: [tc], Year: [y], Number: [number], Heading: h} = _record)
      when h not in [nil, ""] do
    ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/crossheading/#{h}]
  end

  def leg_gov_uk(%{
        type_code: [tc],
        Year: [y],
        Number: [number],
        Record_Type: ["section"],
        "Section||Regulation": s
      }) do
    ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/section/#{s}]
  end

  def leg_gov_uk(%{
        type_code: [tc],
        Year: [y],
        Number: [number],
        Record_Type: ["part"],
        Part: p
      }) do
    ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/part/#{p}]
  end

  def leg_gov_uk(%{
        type_code: [tc],
        Year: [y],
        Number: [number],
        Record_Type: ["chapter"],
        Part: c
      }) do
    ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/chapter/#{c}]
  end

  @spec article_taxa(tuple()) :: binary()
  def article_taxa({k, v}) do
    v =
      v
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join("; ")

    ~s/#{k}\n[#{v}]/
  end

  def taxa_article({k, v}) do
    v =
      v
      |> Enum.uniq()
      |> Enum.sort(NaturalOrder)
      |> Enum.join("\n")

    ~s/[#{Enum.join(k, "; ")}]\n#{v}/
  end

  def sorter(record, field) do
    value =
      case Map.get(record, field) do
        v when is_list(v) -> Enum.sort(v)
        v -> v
      end

    Map.put(record, field, value)
  end

  defmodule DutyActor do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
    alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa

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

    @spec duty_actor_uniq(list(%AtTaxa{})) :: list()
    defp duty_actor_uniq(records) do
      Enum.map(records, fn %{"Duty Actor": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
    end

    @spec duty_actor_aggregate(list(%AtTaxa{})) :: list()
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

    @spec duty_actor_article(list(%AtTaxa{})) :: struct()
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

  defmodule DutyActorGvt do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
    alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa

    def duty_actor_gvt(records) do
      result =
        Enum.map(records, fn %{"Duty Actor Gvt Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        # duty_actor_gvt: Legl.Utility.quote_list(result) |> Enum.join(","),
        "Duty Actor Gvt": result
      }
    end

    @spec duty_actor_gvt_uniq(list(%AtTaxa{})) :: list()
    defp duty_actor_gvt_uniq(records) do
      Enum.map(records, fn %{"Duty Actor Gvt": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
    end

    @spec duty_actor_gvt_aggregate(list(%AtTaxa{})) :: list()
    defp duty_actor_gvt_aggregate(records) do
      records
      |> duty_actor_gvt_uniq
      |> Enum.reduce([], fn member, col ->
        Enum.reduce(records, [], fn
          %{
            type_code: [tc],
            Year: [y],
            Number: [number],
            Record_Type: [rt],
            "Section||Regulation": s,
            "Duty Actor Gvt Aggregate": values
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

    def uniq_duty_actor_gvt_article(records) do
      records
      |> duty_actor_gvt_aggregate()
      |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :duty_actor_gvt, &1)).()
    end

    def duty_actor_gvt_article(records) do
      records
      |> Enum.map(&LRTT.sorter(&1, :"Duty Actor Gvt Aggregate"))
      |> Enum.group_by(& &1."Duty Actor Gvt Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(&LRTT.taxa_article/1)
      |> Enum.join("\n\n")
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
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :article_duty_actor_gvt, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyHolder do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
    alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa

    def dutyholder(records) do
      result =
        Enum.map(records, fn %{"Dutyholder Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        # duty_holder: Legl.Utility.quote_list(result) |> Enum.join(","),
        Dutyholder: result
      }
    end

    @spec dutyholder_uniq(list(%AtTaxa{})) :: list()
    defp dutyholder_uniq(records) do
      Enum.map(records, fn %{Dutyholder: value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
    end

    @spec dutyholder_aggregate(list(%AtTaxa{})) :: list()
    defp dutyholder_aggregate(records) do
      records
      |> dutyholder_uniq
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

    def uniq_dutyholder_article(records) do
      records
      |> dutyholder_aggregate()
      |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :duty_holder, &1)).()
    end

    def dutyholder_article(records) do
      records
      |> Enum.map(&LRTT.sorter(&1, :"Dutyholder Aggregate"))
      |> Enum.group_by(& &1."Dutyholder Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(&LRTT.taxa_article/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :dutyholder_article, &1)).()

      # |> IO.inspect()
    end

    def article_dutyholder(records) do
      records
      |> Enum.filter(fn %{"Dutyholder Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Dutyholder Aggregate")
      |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :article_dutyholder, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyHolderGvt do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
    alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa

    def dutyholder_gvt(records) do
      result =
        Enum.map(records, fn %{"Dutyholder Gvt Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        # duty_holder_gvt: Legl.Utility.quote_list(result) |> Enum.join(","),
        "Dutyholder Gvt": result
      }
    end

    @spec dutyholder_gvt_uniq(list(%AtTaxa{})) :: list()
    defp dutyholder_gvt_uniq(records) do
      Enum.map(records, fn %{"Dutyholder Gvt": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
    end

    @spec dutyholder_gvt_aggregate(list(%AtTaxa{})) :: list()
    defp dutyholder_gvt_aggregate(records) do
      records
      |> dutyholder_gvt_uniq
      |> Enum.reduce([], fn member, col ->
        Enum.reduce(records, [], fn
          %{
            type_code: [tc],
            Year: [y],
            Number: [number],
            Record_Type: [rt],
            "Section||Regulation": s,
            "Dutyholder Gvt Aggregate": values
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

    def uniq_dutyholder_gvt_article(records) do
      records
      |> dutyholder_gvt_aggregate()
      |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :duty_holder_gvt, &1)).()
    end

    def dutyholder_gvt_article(records) do
      records
      |> Enum.map(&LRTT.sorter(&1, :"Dutyholder Gvt Aggregate"))
      |> Enum.group_by(& &1."Dutyholder Gvt Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(&LRTT.taxa_article/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :dutyholder_gvt_article, &1)).()

      # |> IO.inspect()
    end

    def article_dutyholder_gvt(records) do
      records
      |> Enum.filter(fn %{"Dutyholder Gvt Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Dutyholder Gvt Aggregate")
      |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :article_dutyholder_gvt, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule DutyType do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
    alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa

    def duty_type(records) do
      result =
        Enum.map(records, fn %{"Duty Type Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        # duty_type: Legl.Utility.quote_list(result) |> Enum.join(","),
        "Duty Type": result
      }
    end

    @spec duty_type_uniq(list(%AtTaxa{})) :: list()
    defp duty_type_uniq(records) do
      Enum.map(records, fn %{"Duty Type": value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
    end

    @spec duty_type_aggregate(list(%AtTaxa{})) :: list()
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
        |> Enum.reverse()
      end)
    end

    def uniq_duty_type_article(records) do
      records
      |> duty_type_aggregate()
      |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :duty_type, &1)).()
    end

    def duty_type_article(records) do
      records
      |> Enum.map(&LRTT.sorter(&1, :"Duty Type Aggregate"))
      |> Enum.group_by(& &1."Duty Type Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(&LRTT.taxa_article/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :duty_type_article, &1)).()

      # |> IO.inspect()
    end

    def article_duty_type(records) do
      records
      |> Enum.filter(fn %{"Duty Type Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."Duty Type Aggregate")
      |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :article_duty_type, &1)).()

      # |> IO.inspect()
    end
  end

  defmodule POPIMAR do
    alias Legl.Countries.Uk.Article.Taxa.LRTTaxa, as: LRTT
    alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa

    def popimar(records) do
      result =
        Enum.map(records, fn %{"POPIMAR Aggregate": value} ->
          value
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      %{
        # popimar_: Legl.Utility.quote_list(result) |> Enum.join(","),
        POPIMAR: result
      }
    end

    @spec popimar_uniq(list(%AtTaxa{})) :: list()
    defp popimar_uniq(records) do
      Enum.map(records, fn %{POPIMAR: value} ->
        value
      end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
    end

    @spec popimar_aggregate(list(%AtTaxa{})) :: list()
    defp popimar_aggregate(records) do
      records
      |> popimar_uniq
      |> Enum.reduce([], fn member, col ->
        Enum.reduce(records, [], fn
          %{
            type_code: [tc],
            Year: [y],
            Number: [number],
            Record_Type: [rt],
            "Section||Regulation": s,
            "POPIMAR Aggregate": values
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

    def uniq_popimar_article(records) do
      records
      |> popimar_aggregate()
      |> Enum.map(fn {k, v} -> ~s/[#{k}]\n#{Enum.join(v, "\n")}/ end)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :popimar_, &1)).()
    end

    def popimar_article(records) do
      records
      |> Enum.map(&LRTT.sorter(&1, :"Duty Actor Aggregate"))
      |> Enum.group_by(& &1."POPIMAR Aggregate")
      |> Enum.filter(fn {k, _} -> k != [] end)
      |> Enum.map(fn {k, v} ->
        {k, Enum.map(v, &LRTT.leg_gov_uk/1)}
      end)
      |> Enum.sort()
      |> Enum.map(&LRTT.taxa_article/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :popimar_article, &1)).()

      # |> IO.inspect()
    end

    def article_popimar(records) do
      records
      |> Enum.filter(fn %{"POPIMAR Aggregate": daa} -> daa != [] end)
      |> Enum.map(fn record -> Map.put(record, :url, LRTT.leg_gov_uk(record)) end)
      |> Enum.group_by(& &1.url, & &1."POPIMAR Aggregate")
      |> Enum.sort_by(&elem(&1, 0), {:asc, NaturalOrder})
      |> Enum.map(&LRTT.article_taxa/1)
      |> Enum.join("\n\n")
      |> (&Map.put(%{}, :article_popimar, &1)).()

      # |> IO.inspect()
    end
  end
end
