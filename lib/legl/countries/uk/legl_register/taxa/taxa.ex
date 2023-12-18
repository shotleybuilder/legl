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
  alias Legl.Countries.Uk.AtArticle.AtTaxa.LRTTaxa

  @doc """
  Function to set the Taxa fields for the Legal Register Table

  lrt_opts and lat_opts because we deal with both the LRT
  and LAT and each has a base_name etc.
  """
  def set_taxa(lrt_record, lrt_opts) do
    lat_opts = [name: lrt_opts.name]
    lat_opts = Options.set_taxa_options(lat_opts)

    # Lets not carry extra fields we don't need
    lrt_record =
      Legl.Countries.Uk.LeglRegister.Helpers.clean_record(lrt_record, lrt_opts)
      |> IO.inspect(label: "lrt_record")

    {:ok, lat_articles} = Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa.get(lat_opts)

    LRTTaxa.workflow(lat_articles, lrt_record) |> IO.inspect(limit: :infinity)

    {:ok, lrt_record}
  end
end
