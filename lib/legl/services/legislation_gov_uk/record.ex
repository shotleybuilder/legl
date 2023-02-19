defmodule Legl.Services.LegislationGovUk.Record do

  @endpoint "https://www.legislation.gov.uk"

  # @legislation_gov_uk_api is a module attribute (constant) set to the env value
  # defined in dev.exs/prod.exs/test.exs.  Allows to mock the http call

  defmodule Legislation.Response do
    defstruct metadata: []
  end

  def legislation(url) do
    case Legl.Services.LegislationGovUk.Client.run!(@endpoint <> url) do

      { :ok, %{:content_type => :xml, :body => body} } ->
        #IO.inspect(body.metadata)
        { :ok,
          :xml,
          %Legislation.Response{
            metadata: body.metadata
          }
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



end
