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

  @spec leg_gov_uk(map()) :: binary()
  def leg_gov_uk(
        %{
          type_code: [type_code],
          Year: [year],
          Number: [number]
        } = record
      ) do
    leg_gov_uk(type_code, year, number, record)
  end

  @spec leg_gov_uk(map()) :: binary()
  def leg_gov_uk(
        %{
          type_code: type_code,
          Year: year,
          Number: number
        } = record
      ) do
    leg_gov_uk(type_code, year, number, record)
  end

  @spec leg_gov_uk(binary(), binary(), binary(), map()) :: binary()
  defp leg_gov_uk(type_code, year, number, %{
         Record_Type: [record_type],
         Part: p,
         Chapter: c,
         Heading: h,
         "Section||Regulation": s,
         Text: text
       }) do
    case record_type do
      "part" ->
        ~s[https://legislation.gov.uk/#{type_code}/#{year}/#{number}/part/#{p}]

      "chapter" ->
        ~s[https://legislation.gov.uk/#{type_code}/#{year}/#{number}/chapter/#{c}]

      "heading" ->
        url_encoded_heading = encode(text)

        ~s[https://legislation.gov.uk/#{type_code}/#{year}/#{number}/crossheading/#{url_encoded_heading}]

      "article" ->
        ~s[https://legislation.gov.uk/#{type_code}/#{year}/#{number}/regulation/#{s}]

      "section" ->
        ~s[https://legislation.gov.uk/#{type_code}/#{year}/#{number}/section/#{s}]

      _ ->
        ""
    end
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

  def encode(heading) do
    heading
    |> String.trim()
    |> (&Regex.replace(~r/(\\[?[Ff]\\d+[ ])/, &1, "")).()
    |> String.replace(" ", "-")
    |> String.replace(",", "")
    |> String.replace(".", "")
    |> String.replace(":", "")
    |> String.replace("]", "")
    |> String.downcase()
  end
end
