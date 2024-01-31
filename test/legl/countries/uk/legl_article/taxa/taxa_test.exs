defmodule Legl.Countries.Uk.LeglArticle.Taxa.TaxaTest do
  # mix test test/legl/countries/uk/legl_article/taxa/taxa_test.exs
  use ExUnit.Case

  alias Legl.Countries.Uk.Article.Taxa.LATTaxa
  alias Legl.Countries.Uk.Article.Taxa.Options

  @opts [
    source: :web,
    filesave?: false,
    view: "",
    base_name: "💙 Occupational / Personal Health and Safety - UK",
    base_id: Keyword.get(Legl.Services.Airtable.AtBases.bases(), :"11") |> elem(1),
    table_id:
      Legl.Services.Airtable.AtTables.get_table_id(
        Keyword.get(Legl.Services.Airtable.AtBases.bases(), :"11")
        |> elem(1),
        "Articles"
      )
      |> elem(1),
    Name: "UK_uksi_1992_2793",
    taxa_workflow_selection: 0
  ]

  @text File.read!(~s[lib/legl/data_files/txt/parsed.txt] |> Path.absname())

  describe "api_update_lat_taxa/2" do
    test "run" do
      opts = Map.merge(Options.set_workflow_opts(@opts), UK.airtable_default_opts())

      # opts = UK.airtable_default_opts()

      schema = UK.schema(:regulation)
      fields = UK.Regulation.fields()

      opts = Keyword.merge(Map.to_list(opts), type: :regulation, fields: fields, schema: schema)

      records = Legl.Airtable.Schema.schema(@text, opts)

      records = LATTaxa.api_update_lat_taxa_from_text(records, Enum.into(opts, %{}))
      IO.inspect(records, limit: :infinity, pretty: true)
    end
  end

  describe "api_update_lat_taxa/1" do
    test "run live" do
      LATTaxa.api_update_lat_taxa(@opts)
    end
  end

  describe "get/1" do
    test "get" do
      opts = Options.set_workflow_opts(@opts)
      records = LATTaxa.get(opts)
      IO.inspect(records, limit: :infinity, pretty: true)
    end
  end
end
