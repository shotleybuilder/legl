defmodule SWE.Av do
  @moduledoc false

  def rm_page_marker(binary) do
    # remove page markers
    binary = Regex.replace(~r/^\d+[ ]?(?:\r\n|\n)AFS[ ]\d{4}:\d+[\r\n|\n]?/m, binary, "")
    binary = Regex.replace(~r/^AFS[ ]\d{4}:\d+[\r\n|\n]\d+/m, binary, "")
    Regex.replace(~r/^AFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")
  end
end
