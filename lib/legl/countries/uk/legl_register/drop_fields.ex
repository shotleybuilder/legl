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

  def drop_fields(update_workflow) do
    case update_workflow do
      :new -> @default
      :update -> @enact ++ @default
      :changes -> @extent ++ @enact ++ @default
      :metadata -> @extent ++ @enact ++ @affect ++ @default
      :extent -> @metadata ++ @enact ++ @affect ++ @default
      :enact -> @metadata ++ @extent ++ @affect ++ @default
      :affect -> @metadata ++ @extent ++ @enact ++ @default
    end
  end

  def drop_fields, do: @default

  def drop_if_null, do: @drop_if_null
end