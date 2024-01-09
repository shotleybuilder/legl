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
  def set_taxa(%{Family: family} = lrt_record, lrt_opts) when family not in [nil, ""],
    do: set_taxa(lrt_record, lrt_opts, family)

  def set_taxa(lrt_record, %{family: family} = lrt_opts) when family not in [nil, ""],
    do: set_taxa(lrt_record, lrt_opts, family)

  def set_taxa(lrt_record, _) do
    IO.puts(~s{ERROR: Family Not Set\n[#{__MODULE__}.set_taxa/2]})
    {:ok, lrt_record}
  end

  def set_taxa(lrt_record, lrt_opts, family) when is_binary(family) do
    lat_opts = [
      # Mutes user select prompt
      base_name: family <> ~s/ - UK/,
      base_id: Map.get(AtBases.base_map(), family <> ~s/ - UK/),
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

    if lrt_opts.filesave? == true,
      do:
        Legl.Utility.save_structs_as_json(
          lat_articles,
          "test/legl/countries/uk/legl_register/taxa_lat_source.json"
        )

    lrt_record = LRTTaxa.workflow(lat_articles, lrt_record)
    # |> IO.inspect(limit: :infinity, label: "Legal Register Table - record")

    {:ok, lrt_record}
  end

  @doc """
  Function to set the content of LRT taxa fields

  Namely
    responsibility_holder_article_clause
    power_holder_article_clause
  """

  @spec xxx_article_clause_field(tuple()) :: binary()
  def xxx_article_clause_field({k, v}) do
    content =
      Enum.map(v, fn {url, clauses} ->
        clauses = Enum.map(clauses, &String.replace(&1, "\n ", "\n"))
        ~s/#{url}\n#{Enum.join(clauses, "\n")}/
      end)
      |> Enum.join("\n")

    ~s/[#{k}]\n#{content}/
  end

  @doc """
  Function to set the content of LRT taxa fields

  Namely:
    article_actor_gvt
    article_actor
    article_responsibility_holder
    article_power_holder
    article_duty_holder
    article_rights_holder
    article_duty_type
    article_popimar
  """

  def article_xxx_field({_, []}), do: ""

  def article_xxx_field({_, articles}) when is_list(articles) do
    articles
    |> Enum.uniq()
    |> Enum.map(&article_xxx_field_string(&1))
    |> Enum.join("\n")
  end

  def article_xxx_field_string({url, terms}) do
    ~s/#{url}\n#{terms |> Enum.sort() |> Enum.join("; ")}/
  end

  @doc """
  Function to set the content of LRT taxa fields

  Namely:
    article_responsibility_holder_clause
    article_power_holder_clause
    article_duty_holder_clause
    article_rights_holder_clause
    article_popimar_clause *not yet implemented
  """
  @spec article_xxx_clause_field(tuple()) :: binary()
  def article_xxx_clause_field({_, []}), do: ""

  def article_xxx_clause_field({_, articles}) do
    articles
    |> Enum.uniq()
    |> Enum.map(&article_xxx_clause_field(&1))
    |> Enum.join("\n")
  end

  def article_xxx_clause_field({url, _taxa, clauses}) do
    content =
      Enum.map(clauses, fn clause -> String.replace(clause, "\n ", "\n") end)
      |> Enum.join("\n")

    ~s/#{url}\n#{content}/
  end

  @doc """
  Function to sort xxx_aggregate

  """
  def natural_order_sort([]), do: []

  def natural_order_sort(values) do
    case hd(values) do
      v when is_tuple(v) ->
        Enum.sort_by(values, &elem(&1, 0), NaturalOrder)

      v when is_binary(v) ->
        Enum.sort(values, NaturalOrder)
    end
  end
end
