defmodule AUT do
  @moduledoc """
  Parsing text copied from [finlex](https://www.finlex.fi)
  """
  alias Legl.Airtable.Schema

  @doc """

  """
  def parse(timed? \\ false) do
    {:ok, binary} = File.read(Path.absname(Legl.original()))

    case timed? do
      true ->
        File.write(Legl.annotated(), "#{AUT.Parser.timed_parser(binary)}")

      false ->
        File.write(Legl.annotated(), "#{AUT.Parser.parser(binary)}")
    end
  end

  @doc """
  Creates an `airtable.txt` file suitable for pasting into Airtable.


  """
  def airtable() do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))
    File.write(Legl.airtable(), "#{Schema.schema(:aut, binary)}")
  end
end
