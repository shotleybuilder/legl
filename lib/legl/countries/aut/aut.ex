defmodule AUT do
  @moduledoc """
  Parsing text copied from [finlex](https://www.finlex.fi)
  """
  alias Legl.Airtable.Schema

  def clean(),
    do: AUT.Parser.clean_original(File.read!(Path.absname(Legl.original())))

  @doc """

  """
  def parse(latest? \\ true) do
    {:ok, binary} = File.read(Path.absname(Legl.original()))

    case latest? do
      true ->
        File.write("lib/annotated.txt", "#{AUT.Parser.parser_latest(binary)}")

      false ->
        File.write("lib/annotated.txt", "#{AUT.Parser.parser_latest(binary)}")
    end
  end

  @doc """
  Creates an `airtable.txt` file suitable for pasting into Airtable.


  """
  def airtable(fields \\ :all) do
    {:ok, binary} = File.read(Path.absname("lib/annotated.txt"))

    Schema.schema(:aut, binary, fields)
    # |> IO.inspect()
    |> (&File.write(Legl.airtable(), &1)).()

    # File.write(Legl.airtable(), "#{Schema.schema(:aut, binary)}")
  end
end
