defmodule FIN do
  @moduledoc """
  Parsing text copied from [finlex](https://www.finlex.fi)
  """
  alias Legl.Airtable.Schema

  @doc """

  """
  def parse() do
    {:ok, binary} = File.read(Path.absname(Legl.original()))
    File.write(Legl.annotated(), "#{FIN.Parser.parser(binary)}")
  end

  @doc """
  Creates an `airtable.txt` file suitable for pasting into Airtable.


  """
  def airtable() do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))
    File.write(Legl.airtable(), "#{Schema.schema(:fin, binary)}")
  end
end
