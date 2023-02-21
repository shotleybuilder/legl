defmodule Legl.Services.LegislationGovUk.Record do

  @endpoint "https://www.legislation.gov.uk"

  # @legislation_gov_uk_api is a module attribute (constant) set to the env value
  # defined in dev.exs/prod.exs/test.exs.  Allows to mock the http call

  defstruct metadata: []

  def legislation(url) do
    case Legl.Services.LegislationGovUk.Client.run!(@endpoint <> url) do

      {:ok, %{:content_type => :xml, :body => body}} ->
        { :ok,
          :xml,
          %__MODULE__{
            metadata: body.metadata
          }
        }

      {:ok, %{:content_type => :html}} ->
        { :ok,
          :html
        }

      { :error, code, error } ->
        #Some older legislation doesn't have .../made/data.xml api
        case code do
          404 ->
            if String.contains?(url, "/made/") do
              legislation(String.replace(url, "/made", "") )
            else
              { :error, code, error }
            end
          _ -> { :error, code, error }
        end

    end
  end

  def amendments_table(url) do
    case Legl.Services.LegislationGovUk.ClientAmdTbl.run!(@endpoint <> url) do
      { :ok, %{:content_type => :html, :body => body} } ->
        case Legl.Services.LegislationGovUk.Parsers.Amendment.amendment_parser(body) do
          {:ok, map} -> {:ok, :html, map}
          {:error, error} -> {:error, error}
        end
    end
  end



end
