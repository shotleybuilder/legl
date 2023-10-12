defmodule Legl.Services.LegislationGovUk.Parsers.Amendment do
  @moduledoc """
  Use the Floki library
  https://github.com/philss/floki
  """
  def amendment_parser(html) do
    {:ok, document} = Floki.parse_document(html)
    # IO.inspect(document, limit: :infinity)
    case Floki.find(document, "tbody") do
      [] ->
        :no_records

      body ->
        # IO.inspect(body, label: "TBODY: ")
        {:ok, body}
    end
  end
end
