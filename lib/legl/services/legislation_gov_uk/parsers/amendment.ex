defmodule Legl.Services.LegislationGovUk.Parsers.Amendment do

  @moduledoc """
  Use the Floki library
  https://github.com/philss/floki
  """
  def amendment_parser(html) do
    Floki.parse_document(html)
  end

end
