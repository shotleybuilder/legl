defmodule Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess do
  @moduledoc """

  """
  alias Legl.Countries.Uk.AirtableArticle.UkRegionConversion
  alias Legl.Countries.Uk.AirtableAmendment.Amendments
  alias Legl.Countries.Uk.AirtableArticle.UkArticlePrint

  def process(records, opts) do
    opts = Enum.into(opts, %{})

    with records <- UkRegionConversion.region_conversion(records, opts),
         {:ok, records} <- Amendments.find_changes(records),
         Amendments.amendments(records, opts),
         records <- rm_amendments(records) do
      # A proxy of the Airtable table useful for debugging 'at_tabulated.txt'
      UkArticlePrint.make_tabular_txtfile(records, opts)
      |> IO.puts()

      to_csv(records, opts)
    end
  end

  def rm_amendments(records) do
    Enum.reduce(records, [], fn
      %{type: ~s/"amendment,heading"/} = _record, acc -> acc
      %{type: ~s/"amendment,textual"/} = _record, acc -> acc
      record, acc -> [record | acc]
    end)
  end

  def to_csv(records, opts) do
    opts = Map.put(opts, :type, :act_)
    Legl.Legl.LeglPrint.to_csv(records, opts)
  end
end
