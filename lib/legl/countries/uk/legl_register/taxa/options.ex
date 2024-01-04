defmodule Legl.Countries.Uk.LeglRegister.Taxa.Options do
  @moduledoc """
  Functions to set the options for the Taxa update
  """

  @type opts :: map()

  @default_opts [
    source: :web,
    fields: [
      # Multi Select Fields
      "Dutyholder",
      "Rights_Holder",
      "Responsibility_Holder",
      "Power_Holder",
      "Duty Actor",
      "Duty Actor Gvt",
      "Duty Type",
      "POPIMAR",

      # Aggregates
      "Duty Actor Aggregate",
      "Duty Actor Gvt Aggregate",
      "Dutyholder Aggregate",
      "Rights_Holder_Aggregate",
      "Responsibility_Holder_Aggregate",
      "Power_Holder_Aggregate",
      "Duty Type Aggregate",
      "POPIMAR Aggregate",

      # Text
      "dutyholder_txt",
      "rights_holder_txt",
      "responsibility_holder_txt",
      "power_holder_txt",

      # Generic
      "type_code",
      "Number",
      "Year",
      "ID",
      "Record_Type",
      "Text",
      "Record_ID",
      "Part",
      "Chapter",
      "Heading",
      "Section||Regulation"
    ],
    opts_label: "LAT OPTIONS"
  ]

  @spec set_taxa_options(opts()) :: opts()
  def set_taxa_options(opts \\ []) do
    # opts = Enum.into(opts, @default_opts)
    Keyword.merge(opts, @default_opts)
  end
end
