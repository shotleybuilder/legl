defmodule Legl.Countries.Uk.LeglRegister.Taxa do
  @moduledoc """
  Functions to orchestrate the read, transform and save of the Taxa model fields to the Legal Register Table

  LRT = Legal Register Table
  LAT = Legal Article Table

  Read LRT -> Build %LR{} -> Read TAXA from LAT -> Update %LR{} -> Patch LRT

  Read LRT -> Build %LR{} -> Read LAT -> Calc TAXA -> Patch LAT
                          -> Read TAXA from LAT -> Update %LR{} -> Patch LRT

  Read LRT -> Build %LR{} -> Get Leg.Gov.Uk -> Parse Law -> Post LAT
                          -> Read LAT -> Calc TAXA -> Patch LAT
                          -> Read TAXA from LAT -> Update %LR{} -> Patch LRT
  """

  alias Legl.Countries.Uk.LeglRegister.Taxa.Options
  alias Legl.Countries.Uk.Article.Taxa.LRTTaxa
  alias Legl.Services.Airtable.UkAirtable, as: AT

  @doc """
  Function to set the Taxa fields for the Legal Register Table

  lrt_opts and lat_opts because we deal with both the LRT
  and LAT and each has a base_name etc.
  """
  def set_taxa(lrt_record, lrt_opts) do
    lat_opts = [
      name: lrt_opts.name,
      type_code: lrt_record.type_code,
      Year: lrt_record."Year",
      Number: lrt_record."Number"
    ]

    lat_opts = Options.set_taxa_options(lat_opts)

    # Lets not carry extra fields we don't need
    lrt_record =
      Legl.Countries.Uk.LeglRegister.Helpers.clean_record(lrt_record, lrt_opts)
      |> IO.inspect(label: "Legal Register Table - record")

    lat_articles =
      AT.get_legal_article_taxa_records(lat_opts)
      |> IO.inspect(label: "lat_articles")

    lrt_record =
      LRTTaxa.workflow(lat_articles, lrt_record)
      |> IO.inspect(limit: :infinity, label: "Legal Register Table - record")

    {:ok, lrt_record}
  end
end
