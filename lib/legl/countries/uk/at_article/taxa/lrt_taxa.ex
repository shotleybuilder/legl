defmodule Legl.Countries.Uk.Article.Taxa.LRTTaxa do
  @moduledoc """
  Functions to build the content of the Taxa family of fields in the Legal Register Table
  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  alias Legl.Countries.Uk.LeglRegister.Taxa.GovernedRoles, as: Actor
  alias Legl.Countries.Uk.LeglRegister.Taxa.GovernmentRoles, as: GvtActor

  alias Legl.Countries.Uk.LeglRegister.Taxa.DutyHolder
  alias Legl.Countries.Uk.LeglRegister.Taxa.RightsHolder
  alias Legl.Countries.Uk.LeglRegister.Taxa.ResponsibilityHolder
  alias Legl.Countries.Uk.LeglRegister.Taxa.PowerHolder

  alias Legl.Countries.Uk.LeglRegister.Taxa.DutyType

  alias Legl.Countries.Uk.LeglRegister.Taxa.Popimar, as: POPIMAR

  @spec workflow(list()) :: %LR{}
  def workflow(records) do
    workflow(records, %LR{})
  end

  @spec workflow(list(), %LR{}) :: %LR{}
  def workflow(records, result) do
    result
    # Governed Roles
    |> Kernel.struct(Actor.actor(records))
    |> Kernel.struct(Actor.actor_article(records))
    |> Kernel.struct(Actor.article_actor(records))
    # Government Roles
    |> Kernel.struct(GvtActor.actor_gvt(records))
    |> Kernel.struct(GvtActor.actor_gvt_article(records))
    |> Kernel.struct(GvtActor.article_actor_gvt(records))
    # Governed duties
    |> Kernel.struct(DutyHolder.dutyholder(records))
    |> Kernel.struct(DutyHolder.dutyholder_article(records))
    |> Kernel.struct(DutyHolder.article_dutyholder(records))
    |> Kernel.struct(DutyHolder.uniq_dutyholder_article(records))
    # Governed rights
    |> Kernel.struct(RightsHolder.rightsholder(records))
    |> Kernel.struct(RightsHolder.rightsholder_article(records))
    |> Kernel.struct(RightsHolder.article_rightsholder(records))
    |> Kernel.struct(RightsHolder.uniq_rightsholder_article(records))
    # Government responsibles
    |> Kernel.struct(ResponsibilityHolder.responsibility_holder(records))
    |> Kernel.struct(ResponsibilityHolder.responsibility_holder_article(records))
    |> Kernel.struct(ResponsibilityHolder.responsibility_holder_article_clause(records))
    |> Kernel.struct(ResponsibilityHolder.article_responsibility_holder(records))
    |> Kernel.struct(ResponsibilityHolder.article_responsibility_holder_clause(records))
    # Government powers
    |> Kernel.struct(PowerHolder.powerholder(records))
    |> Kernel.struct(PowerHolder.powerholder_article(records))
    |> Kernel.struct(PowerHolder.article_powerholder(records))
    |> Kernel.struct(PowerHolder.uniq_powerholder_article(records))
    # Duty Types
    |> Kernel.struct(DutyType.duty_type(records))
    |> Kernel.struct(DutyType.duty_type_article(records))
    |> Kernel.struct(DutyType.article_duty_type(records))
    |> Kernel.struct(DutyType.uniq_duty_type_article(records))
    # POPIMAR
    |> Kernel.struct(POPIMAR.popimar(records))
    |> Kernel.struct(POPIMAR.popimar_article(records))
    |> Kernel.struct(POPIMAR.article_popimar(records))
    |> Kernel.struct(POPIMAR.uniq_popimar_article(records))
  end

  def leg_gov_uk(
        %{
          type_code: [tc],
          Year: [y],
          Number: [number],
          Record_Type: ["heading"],
          Heading: h
        } = _record
      )
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
        Record_Type: ["article"],
        "Section||Regulation": s
      }) do
    ~s[https://legislation.gov.uk/#{tc}/#{y}/#{number}/regulation/#{s}]
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
end
