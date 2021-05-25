defmodule TUR do
  @moduledoc """
  Parsing text copied from [finlex](https://www.finlex.fi)
  """
  alias Legl.Airtable.Schema

  @doc false
  def clean(),
    do: TUR.Parser.clean_original(File.read!(Path.absname(Legl.original())))

  @doc false
  def parse() do
    {:ok, binary} = File.read(Path.absname(Legl.original()))
    File.write(Legl.annotated(), "#{TUR.Parser.parser(binary)}")
  end

  @doc """
  Creates an `airtable.txt` file suitable for pasting into Airtable.

  Option fields - :text, :all - defaults to :all
  """
  def airtable(fields \\ :all) do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))

    Schema.schema(:tur, binary, fields)
    |> (&File.write(Legl.airtable(), &1)).()
  end
end
