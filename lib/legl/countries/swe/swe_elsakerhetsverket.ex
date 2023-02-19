defmodule SWE.Elsakerhetsverket do
  @moduledoc false

  def rm_page_markers(binary),
    # remove page markers Elsakerhetsverket
    do: Regex.replace(~r/^ELSÄK-FS[\r\n|\n]\d{4}:\d+[\r\n|\n]/, binary, "")

  def rm_guidance(binary),
    # remove the guidance
    do:
      Regex.replace(~r/^(GUNNEL FÄRM)(?:\r\n|\n)(Horst Blüchert)(.*)/sm, binary, "\\g{1}\n\\g{2}")

  def regulation_heading(binary),
    do: Regex.replace(~r/^(Ikraftträdande.*)(?:\r\n|\n)([A-Z])/m, binary, "\n🧡\\g{1}\n🔴\\g{2}")
end
