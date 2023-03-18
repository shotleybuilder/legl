defmodule Legl.Services.LegislationGovUk.Parsers.ParserSearch do
    @moduledoc """
  Use the Floki library
  https://github.com/philss/floki
  """
  def search_parser(html) do
    {:ok, document} = Floki.parse_document(html)
    #IO.inspect(document, limit: :infinity)
    Floki.find(document, "tbody")
    #|> IO.inspect()
    |> (&({:ok, &1})).()
  end
end
