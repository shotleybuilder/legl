defmodule Legl.Countries.Uk.LeglArticle.Taxa.TaxaTest do
  # mix test test/legl/countries/uk/legl_article/taxa/taxa_test.exs
  use ExUnit.Case

  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa

  describe "api_update_lat_taxa/1" do
    test "run live" do
      opts = [
        source: :web,
        filesave?: false,
        view: "viwke2j65Qluxdv3w",
        base_name: "💙 Occupational / Personal Health and Safety - UK",
        base_id: Map.get(Legl.Services.Airtable.AtBases.bases(), 1) |> elem(1),
        Name: "UK_WHSWR_uksi_1992_3004",
        taxa_workflow_selection: 0
      ]

      AtTaxa.api_update_lat_taxa(opts)
    end
  end
end
