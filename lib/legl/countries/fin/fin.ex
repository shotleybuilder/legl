defmodule FIN do
  @moduledoc """
  Parsing text copied from [finlex](https://www.finlex.fi)
  """
  alias Legl.Airtable.Schema

  @doc """
  Creates an `airtable.txt` file suitable for pasting into Airtable.


  """
  def airtable() do
    {:ok, binary} = File.read(Path.absname("lib/annotated.txt"))
    File.write(Legl.airtable(), "#{Schema.schema(:fin, binary)}")
  end
end
