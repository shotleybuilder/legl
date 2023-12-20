defmodule Legl.Countries.Uk.LeglRegister.Taxa.Options do
  @moduledoc """
  Functions to set the options for the Taxa update
  """
  alias Legl.Countries.Uk.Article.Taxa.Options

  @type opts :: map()

  @default_opts [
    source: :web,
    fields: [
      "Dutyholder",
      "Dutyholder Gvt",
      "Duty Actor",
      "Duty Actor Gvt",
      "Duty Type",
      "POPIMAR",
      "Dutyholder Aggregate",
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
      "Section||Regulation"
    ],
    opts_label: "LAT OPTIONS"
  ]

  @spec set_taxa_options(opts()) :: opts()
  def set_taxa_options(opts \\ []) do
    # opts = Enum.into(opts, @default_opts)
    opts = Keyword.merge(opts, @default_opts)
    Options.set_workflow_opts(opts)
  end
end
