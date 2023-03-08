defmodule Legl.Services.LegislationGovUk.RecordEnactingText do

  @endpoint "https://www.legislation.gov.uk"

  def enacting_text(url) do
    case Legl.Services.LegislationGovUk.ClientEnactingText.run!(@endpoint <> url) do

      {:ok, %{:content_type => :xml, :body => %{acc: acc}}} ->
        { :ok,
          :xml,
          acc
        }

      {:ok, %{:content_type => :html}} ->
        { :ok,
          :html
        }

      { :error, code, error } -> { :error, code, error }

    end
  end
end
