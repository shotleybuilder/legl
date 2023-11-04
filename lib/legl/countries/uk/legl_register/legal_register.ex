defmodule Legl.Countries.Uk.LeglRegister.LegalRegister do
  # A struct to represent a Legal Register record

  @type legal_register :: %__MODULE__{
          Name: String.t(),

          # id fields
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

          # Amending fields
          stats_amendings_count: integer(),
          stats_self_amendings_count: integer(),
          stats_amended_laws_count: integer(),
          stats_amendings_count_per_law: String.t(),
          stats_amendings_count_per_law_detailed: String.t(),

          # Amended By fields
          stats_amendments_count: integer(),
          stats_self_amending_count: integer(),
          stats_amending_laws_count: integer(),
          stats_amendments_count_per_law: String.t(),
          stats_amendments_count_per_law_detailed: String.t(),

          # New law fields
          publication_date: String.t(),

          # Change Logs fields
          "Live?_change_log": String.t(),
          md_change_log: String.t(),
          amended_by_change_log: String.t()
        }

  defstruct ~w[
    Name
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

    amendments_checked

    stats_amendings_count
    stats_self_amendings_count
    stats_amended_laws_count
    stats_amendings_count_per_law
    stats_amendings_count_per_law_detailed

    stats_amendments_count
    stats_amending_laws_count
    stats_self_amending_count
    stats_amendments_count_per_law
    stats_amendments_count_per_law_detailed

    publication_date

    Live?_change_log
    md_change_log
    amended_by_change_log
  ]a
end
