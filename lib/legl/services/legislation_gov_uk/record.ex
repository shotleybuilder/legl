defmodule Legl.Services.LegislationGovUk.Record do
  require Logger

  @endpoint "https://www.legislation.gov.uk"

  # @legislation_gov_uk_api is a module attribute (constant) set to the env value
  # defined in dev.exs/prod.exs/test.exs.  Allows to mock the http call

  def legislation(url) do
    case Legl.Services.LegislationGovUk.Client.run!(@endpoint <> url) do
      {:ok, %{:content_type => :xml, :body => body}} ->
        {:ok, :xml, body.metadata}

      {:ok, %{:content_type => :html}} ->
        {:ok, :html}

      {:error, code, error} ->
        # Some older legislation doesn't have .../made/data.xml api
        case code do
          # temporary redirect
          307 ->
            if String.contains?(url, "made") != true do
              legislation(String.replace(url, "data.xml", "made/data.xml"))
            else
              {:error, code, error}
            end

          404 ->
            if String.contains?(url, "/made/") do
              legislation(String.replace(url, "/made", ""))
            else
              {:error, code, error}
            end

          _ ->
            {:error, code, error}
        end
    end
  end
end
