defmodule Legl.Countries.Uk.LeglRegister.DropFields do
  @moduledoc """
  Module for functions that control what fields are dropped when nil, "", [] or otherwise null
  """

  @default ~w[
    affecting_path
    affected_path
    enacting_laws
    enacting_text
    introductory_text
    amending_title
    text
    path
    urls
  ]a

  @drop_if_null ~w[
    Acronym
    Title_EN
    type_code
    Number
    Year
    Tags
    Type
    type_class
    Family
    Function
    publication_date
  ]a

  @metadata ~w[
    md_description
    md_total_paras
    md_images
    md_dct_valid_date
    md_attachment_paras
    md_modified
    md_restrict_start_date
    md_restrict_extent
    md_made_date
    md_enactment_date
    md_coming_into_force_date
    md_subjects
    md_schedule_paras
    si_code
    md_change_log
  ]a

  # Extent fields should be dropped when null
  @extent ~w[Geo_Extent Geo_Region Geo_Pan_Region]a

  @enact ~w[
    Enacting
    Enacted_by
    enact_error
    enacted_by_description
  ]a

  @affect ~w[
    Amending
    Revoking
    Amended_by
    Revoked_by
    🔺_stats_affects_count
    🔺_stats_self_affects_count
    🔺_stats_affected_laws_count
    🔺_stats_affects_count_per_law
    🔺_stats_affects_count_per_law_detailed

    🔻_stats_affected_by_count
    🔻_stats_self_affected_by_count
    🔻_stats_affected_by_laws_count
    🔻_stats_affected_by_count_per_law
    🔻_stats_affected_by_count_per_law_detailed

    🔺_stats_revoking_laws_count
    🔺_stats_revoking_count_per_law
    🔺_stats_revoking_count_per_law_detailed

    🔻_stats_revoked_by_laws_count
    🔻_stats_revoked_by_count_per_law
    🔻_stats_revoked_by_count_per_law_detailed

    Live?
    Live?_description
    Live?_change_log

    amending_change_log
    amended_by_change_log

    amendments_checked
  ]a

  @models ~w[
    actor
    actor_article
    article_actor

    actor_gvt
    actor_gvt_article
    article_actor_gvt

    Dutyholder
    duty_holder
    dutyholder_article
    article_dutyholder

    rights_holder
    rights_holder_article
    article_rights_holder

    responsibility_holder
    responsibility_article
    article_responsibility

    power_holder
    power_holder_article
    article_power_holder

    duty_type
    duty_type_article
    article_duty_type

    POPIMAR
    popimar_
    popimar_article
    article_popimar

    Duty\u00a0Actor
    Duty\u00a0Actor\u00a0Gvt
    Rights\u00a0Holder
    Responsibility\u00a0Holder
    Power\u00a0Holder
    Duty\u00a0Type"


  ]a

  def drop_fields(update_workflow) do
    case update_workflow do
      :new -> @models ++ @default
      :update -> @enact ++ @models ++ @default
      :changes -> @extent ++ @enact ++ @models ++ @default
      :metadata -> @extent ++ @enact ++ @affect ++ @models ++ @default
      :extent -> @metadata ++ @enact ++ @affect ++ @models ++ @default
      :enact -> @metadata ++ @extent ++ @affect ++ @models ++ @default
      :affect -> @metadata ++ @extent ++ @enact ++ @models ++ @default
      :taxa -> @metadata ++ @extent ++ @enact ++ @affect ++ @default
    end
  end

  def drop_fields, do: @models ++ @default

  def drop_if_null, do: @drop_if_null
end
