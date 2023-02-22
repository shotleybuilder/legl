defmodule Legl.Services.LegislationGovUk.Parsers.Amendment do

  @moduledoc """
  Use the Floki library
  https://github.com/philss/floki
  """
  def amendment_parser(html) do

    {:ok, document} = Floki.parse_document(html) # -> {:ok, document}
    Floki.find(document, "tbody")
    |> (&({:ok, &1})).()
  end

end
