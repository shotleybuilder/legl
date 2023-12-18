defmodule Legl.Countries.Uk.LeglRegister.Taxa.Options do
  @moduledoc """
  Functions to set the options for the Taxa update
  """
  alias Legl.Countries.Uk.AtArticle.AtTaxa.Options

  @type opts :: map()

  @default_opts [
    source: :web,
    fields: [
      "Dutyholder",
      "Duty Actor",
      "Duty Type",
      "POPIMAR",
      "Dutyholder Aggregate",
      "Duty Actor Aggregate",
      "Duty Type Aggregate",
      "POPIMAR Aggregate"
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
