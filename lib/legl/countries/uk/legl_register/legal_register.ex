defmodule Legl.Countries.Uk.LeglRegister.LegalRegister do
  # A struct to represent a Legal Register record

  @type legal_register :: %__MODULE__{
          Acronym: String.t(),

          # id fields
          record_id: String.t(),
          Title_EN: String.t(),
          type_code: String.t(),
          Number: String.t(),
          Year: String.t(),

          # search fields
          Tags: list(),
          md_description: String.t(),

          # extent fields
          Geo_Extent: String.t(),
          Geo_Region: String.t(),
          Geo_Pan_Region: String.t(),

          # application fields
          Live?: String.t(),
          "Live?_description": String.t(),

          # Type fields
          Type: String.t(),
          type_class: String.t(),
          # Family fields
          Family: String.t(),
          si_code: String.t(),

          # Metadata fields
          md_total_paras: integer(),
          md_images: integer(),
          md_dct_valid_date: String.t(),
          md_restrict_start_date: String.t(),
          md_restrict_extent: String.t(),
          md_made_date: String.t(),
          md_enactment_date: String.t(),
          md_coming_into_force_date: String.t(),
          md_attachment_paras: integer(),
          md_modified: String.t(),
          md_subjects: list(),
          md_schedule_paras: integer(),

          # EcARM
          Function: list(),
          Amending: String.t(),
          Enacting: String.t(),
          Revoking: String.t(),
          Amended_by: String.t(),
          Enacted_by: String.t(),
          Revoked_by: String.t(),
          amendments_checked: String.t(),

          # Enacting fields
          enact_error: String.t(),
          enacted_by_description: String.t(),

          # Amending fields
          "🔺_stats_affects_count": integer(),
          "🔺_stats_self_affects_count": integer(),
          "🔺_stats_affected_laws_count": integer(),
          "🔺_stats_affects_count_per_law": String.t(),
          "🔺_stats_affects_count_per_law_detailed": String.t(),

          # Amended By fields
          "🔻_stats_affected_by_count": integer(),
          "🔻_stats_self_affected_by_count": integer(),
          "🔻_stats_affected_by_laws_count": integer(),
          "🔻_stats_affected_by_count_per_law": String.t(),
          "🔻_stats_affected_by_count_per_law_detailed": String.t(),

          # Live? Re[voke|peal] fields
          "🔺_stats_revoking_laws_count": integer(),
          "🔺_stats_revoking_count_per_law": String.t(),
          "🔺_stats_revoking_count_per_law_detailed": String.t(),
          "🔻_stats_revoked_by_laws_count": integer(),
          "🔻_stats_revoked_by_count_per_law": String.t(),
          "🔻_stats_revoked_by_count_per_law_detailed": String.t(),

          # New law fields
          publication_date: String.t(),

          # Change Logs fields
          "Live?_change_log": String.t(),
          md_change_log: String.t(),
          amended_by_change_log: String.t(),

          # Governed Roles
          actor: list(),
          actor_article: String.t(),
          article_actor: String.t(),

          # Government Roles
          actor_gvt: list(),
          actor_gvt_article: String.t(),
          article_actor_gvt: String.t(),

          # Duties Holder
          Dutyholder: list(),
          duty_holder: String.t(),
          dutyholder_article: String.t(),
          article_dutyholder: String.t(),

          # Rights Holder
          "Rights Holder": list(),
          rights_holder: String.t(),
          rights_holder_article: String.t(),
          article_rights_holder: String.t(),

          # Responsibilities Holder
          "Responsibility Holder": list(),
          responsibility_holder: String.t(),
          responsibility_article: String.t(),
          article_responsibility: String.t(),

          # Powers Holders
          "Power Holder": list(),
          power_holder: String.t(),
          power_holder_article: String.t(),
          article_power_holder: String.t(),

          # Duty Type
          "Duty Type": list(),
          duty_type: String.t(),
          duty_type_article: String.t(),
          article_duty_type: String.t(),

          # POPIMAR
          POPIMAR: list(),
          popimar_: String.t(),
          popimar_article: String.t(),
          article_popimar: String.t()
        }

  @struct ~w[
    Acronym

    record_id
    Title_EN
    type_code
    Number
    Year


    Tags
    md_description

    Geo_Extent
    Geo_Region
    Geo_Pan_Region

    Live?
    Live?_description

    Type
    type_class

    Family

    si_code

    md_total_paras
    md_images
    md_dct_valid_date
    md_restrict_start_date
    md_restrict_extent
    md_made_date
    md_enactment_date
    md_coming_into_force_date
    md_attachment_paras
    md_modified
    md_subjects
    md_schedule_paras

    Function
    Amended_by
    Enacted_by
    Revoked_by
    Amending
    Enacting
    Revoking

    enact_error
    enacted_by_description

    amendments_checked

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

    publication_date

    Live?_change_log
    md_change_log
    amending_change_log
    amended_by_change_log

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
  ]a

  defstruct @struct ++
              [
                :"Rights Holder",
                :"Responsibility Holder",
                :"Power Holder",
                :"Duty Type"
              ]
end
