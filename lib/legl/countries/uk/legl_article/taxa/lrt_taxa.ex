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
    |> Kernel.struct(DutyHolder.duty_holder(records))
    |> Kernel.struct(DutyHolder.duty_holder_article(records))
    |> Kernel.struct(DutyHolder.duty_holder_article_clause(records))
    |> Kernel.struct(DutyHolder.article_duty_holder(records))
    |> Kernel.struct(DutyHolder.article_duty_holder_clause(records))
    # Governed rights
    |> Kernel.struct(RightsHolder.rights_holder(records))
    |> Kernel.struct(RightsHolder.rights_holder_article(records))
    |> Kernel.struct(RightsHolder.rights_holder_article_clause(records))
    |> Kernel.struct(RightsHolder.article_rights_holder(records))
    |> Kernel.struct(RightsHolder.article_rights_holder_clause(records))
    # Government responsibles
    |> Kernel.struct(ResponsibilityHolder.responsibility_holder(records))
    |> Kernel.struct(ResponsibilityHolder.responsibility_holder_article(records))
    |> Kernel.struct(ResponsibilityHolder.responsibility_holder_article_clause(records))
    |> Kernel.struct(ResponsibilityHolder.article_responsibility_holder(records))
    |> Kernel.struct(ResponsibilityHolder.article_responsibility_holder_clause(records))
    # Government powers
    |> Kernel.struct(PowerHolder.power_holder(records))
    |> Kernel.struct(PowerHolder.power_holder_article(records))
    |> Kernel.struct(PowerHolder.power_holder_article_clause(records))
    |> Kernel.struct(PowerHolder.article_power_holder(records))
    |> Kernel.struct(PowerHolder.article_power_holder_clause(records))
    # Duty Types
    |> Kernel.struct(DutyType.duty_type(records))
    |> Kernel.struct(DutyType.duty_type_article(records))
    |> Kernel.struct(DutyType.article_duty_type(records))
    # POPIMAR
    |> Kernel.struct(POPIMAR.popimar(records))
    |> Kernel.struct(POPIMAR.popimar_article(records))
    |> Kernel.struct(POPIMAR.article_popimar(records))
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
