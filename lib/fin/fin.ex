defmodule FIN do
  @moduledoc """
  Parsing text copied from [finlex](https://www.finlex.fi)
  """
  @doc """

  """
  def parse() do
    {:ok, binary} = File.read(Path.absname(Legl.original()))
    File.write(Legl.annotated(), "#{FIN.Parser.parser(binary)}")
  end
end
