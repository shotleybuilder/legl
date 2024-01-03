defmodule Legl.Countries.Uk.LeglRegister.Taxa.Options do
  @moduledoc """
  Functions to set the options for the Taxa update
  """

  @type opts :: map()

  @default_opts [
    source: :web,
    fields: [
      "Dutyholder",
      "Rightsholder",
      "Dutyholder Gvt",
      "Duty Actor",
      "Duty Actor Gvt",
      "Duty Type",
      "POPIMAR",
      "Dutyholder Aggregate",
      "Rightsholder Aggregate",
      "Dutyholder Gvt Aggregate",
      "Duty Actor Aggregate",
      "Duty Actor Gvt Aggregate",
      "Duty Type Aggregate",
      "POPIMAR Aggregate",
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
