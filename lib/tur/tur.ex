defmodule TUR do
  @moduledoc """
  Parsing text copied from [mevzuat](https://www.mevzuat.gov.tr)
  """
  @behaviour Country
  alias Legl.Airtable.Schema
  alias Types.AirtableSchema

  defstruct flow: "",
            type: "",
            part: "",
            article: "",
            para: "",
            sub: 0,
            text: ""

  @impl true
  def schema do
    %AirtableSchema{
      part: ~s/^(\\d+)[ ](.*)/,
      part_name: "bölüm",
      heading: ~s/^(\\d+)[ ](.*)/,
      heading_name: "madde,  başlık",
      article: ~s/^(\\d+)_?(\\d?)[ ](.*)/,
      article_name: "madde, alt-makale",
      sub_article: ~s/^(\\d+)[ ](.*)/,
      sub_article_name: "alt-makale",
      amendment: ~s/^(\\d+)_?(\\d?)[ ](.*)/,
      amendment_name: "geçici-madde",
      amending_sub_article_name: "geçici-madde, alt-makele"
    }
  end

  @doc false
  def clean(),
    do: TUR.Parser.clean_original(File.read!(Path.absname(Legl.original())))

  @doc false
  def parse() do
    {:ok, binary} = File.read(Path.absname(Legl.original()))
    File.write(Legl.annotated(), "#{TUR.Parser.parser(binary)}")
  end

  @doc """
  Create Airtable data using all fields

  Run as:
  iex>TUR.airtable()

  Options as list.  See %TUR{}
  """
  @impl true
  @spec airtable([]) :: :atom
  def airtable(fields \\ []) when is_list(fields) do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))

    cond do
      fields == [] ->
        Schema.schema(%TUR{}, binary, schema())

      true ->
        Schema.schema(%TUR{}, binary, schema(), fields)
    end
    |> (&File.write(Legl.airtable(), &1)).()

    :ok
  end
end
