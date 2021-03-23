defmodule SWE.Boverket do
  @moduledoc false

  def page_markers(binary),
    do:
      Regex.replace(
        ~r/([\r\n|\n]BFS[ ]\d{4}:\d[\r\n|\n][A-Z]+[ ]\d{1,4}[\r\n|\n]\d+[\r\n|\n])(.)/,
        binary,
        "\n\\g{2}"
      )
end
