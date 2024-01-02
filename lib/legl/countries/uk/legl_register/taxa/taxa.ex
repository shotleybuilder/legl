defmodule Legl.Countries.Uk.LeglRegister.Taxa do
  @moduledoc """
  Functions to orchestrate the read, transform and save of the Taxa model fields to the Legal Register Table

  LRT = Legal Register Table
  LAT = Legal Article Table

  a. UK.api/1
    User select "LRT: UPDATE"
    Runs -> Crud.Update.api_update/1

  b. Crud.Update.api_update/1

    Calls CRUD.Options.api_update_options/1

    b1. CRUD.Options.api_update_options/1
      Calls LRO.update_workflow/1
        Sets (LRO)
          :update_workflow
          :base_name
          :base_id
          :table_id
          :type_class
          :type_code
          :family
          :patch?
        Sets
          :fields
          :formula

      b1.1  LRO.update_workflow/1
        Sets
          :update_workflow -> Taxa.set_taxa/2
          :drop_fields
          :view

    GETS LRT records from Airtable

    Enumerates EACH record

    Calls Taxa.set_taxa/2

    b2. Taxa.set_taxa/2
      Copies properties from LRT opts to LRT opts
        :Name
        :type_code
        :Year
        :Number

      Calls LeglRegister.Taxa.Options.set_taxa_options/1

      c1 LeglRegister.Taxa.Options.set_taxa_options/1
        Sets
          :source
          :fields
          :opts_label

        Calls Article.Taxa.Options.set_workflow_opts/1

      c1.1 Article.Taxa.Options.set_workflow_opts/1
        Sets
          :base_name
          :base_id
          :table_id
          :Name
          :at_id
          :formula
          :taxa_workflow

      GETs LAT records

      Calls Taxa.LRTTaxa.workflow/2

    PATCHs record to Airtable


  WORKFLOW 1
  __MODULE__.set_taxa/2
  Read LRT -> Build %LR{} -> Read TAXA from LAT -> Update %LR{} -> Patch LRT

  WORKFLOW 2
  Read LRT -> Build %LR{} -> Read LAT -> Calc TAXA -> Patch LAT
                          -> Read TAXA from LAT -> Update %LR{} -> Patch LRT

  WORKFLOW 3
  Read LRT -> Build %LR{} -> Get Leg.Gov.Uk -> Parse Law -> Post LAT
                          -> Read LAT -> Calc TAXA -> Patch LAT
                          -> Read TAXA from LAT -> Update %LR{} -> Patch LRT
  """

  alias Legl.Countries.Uk.LeglRegister.Taxa.Options, as: LRTTO
  alias Legl.Countries.Uk.Article.Taxa.Options, as: LATTO
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa
  alias Legl.Services.Airtable.AtBases
  alias Legl.Services.Airtable.UkAirtable, as: AT

  @doc """
  Function to set the Taxa fields for the Legal Register Table

  lrt_opts and lat_opts because we deal with both the LRT
  and LAT and each has a base_name etc.

  Call to the function within the LRO.update_workflow() option
  """
  def set_taxa(lrt_record, lrt_opts) do
    lat_opts = [
      # Mutes user select prompt
      base_name: lrt_opts.family <> ~s/ - UK/,
      base_id: Map.get(AtBases.base_map(), lrt_opts.family <> ~s/ - UK/),
      # Uses these 3 for GET request
      type_code: lrt_record.type_code,
      Year: lrt_record."Year",
      Number: lrt_record."Number",
      # Mutes user select prompt
      taxa_workflow_selection: 0,
      # Mutes user menu prompt
      Name: false
    ]

    lat_opts =
      lat_opts
      # Sets the fields returned from LAT
      |> LRTTO.set_taxa_options()
      |> LATTO.set_workflow_opts()

    # Lets not carry extra fields we don't need
    lrt_record = Legl.Countries.Uk.LeglRegister.Helpers.clean_record(lrt_record, lrt_opts)
    # |> IO.inspect(label: "Legal Register Table - record")

    lat_articles = AT.get_legal_article_taxa_records(lat_opts)
    # |> IO.inspect(label: "lat_articles")

    lrt_record =
      LRTTaxa.workflow(lat_articles, lrt_record)
      |> IO.inspect(limit: :infinity, label: "Legal Register Table - record")

    {:ok, lrt_record}
  end
end
