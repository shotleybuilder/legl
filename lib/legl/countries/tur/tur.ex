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
            chapter: "",
            article: "",
            para: "",
            sub: 0,
            text: ""

  @impl true
  def schema do
    %AirtableSchema{
      country: :tur,
      part: ~s/^(\\d+)[ ](.*)/,
      part_name: "kisim",
      chapter: ~s/^(\\d+)[ ](.*)/,
      chapter_name: "bölüm",
      heading: ~s/^(\\d+)[ ](.*)/,
      heading_name: "madde,  başlık",
      article: ~s/^(\\d+[a-z]?)_?(\\d?)[ ](.*)/,
      article_name: "madde, alt-makale",
      sub_article: ~s/^(\\d+)[ ](.*)/,
      sub_article_name: "alt-makale",
      annex: ~s/^(\\d+)[ ](.*)/,
      annex_name: "ek",
      amendment: ~s/^(\\d+)_?(\\d+)[ ](.*)/,
      amendment_name: "geçici-madde",
      amending_sub_article_name: "geçici-madde, alt-makele"
    }
  end

  @doc false
  @spec clean() :: String.t()
  def clean(),
    do: TUR.Parser.clean_original(File.read!(Path.absname(Legl.original())))

  @doc false
  @spec parse() :: :atom
  def parse() do
    binary = clean()
    File.write("lib/annotated.txt", "#{TUR.Parser.parser(binary)}")
    :ok
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
    {:ok, binary} = File.read(Path.absname("lib/annotated.txt"))

    binary =
      cond do
        fields == [] ->
          Schema.schema(%TUR{}, binary, schema())

        true ->
          Schema.schema(binary, schema(), fields)
      end

    no_of_lines = Enum.count(String.graphemes(binary), fn x -> x == "\n" end)

    cond do
      no_of_lines < 200 ->
        copy(binary)
        File.write(Legl.airtable(), binary)

      true ->
        String.split(binary, "\n")
        |> Enum.chunk_every(200)
        |> Enum.map(fn x -> Enum.join(x, "\n") end)
        |> Enum.reduce("", fn str, acc ->
          copy(str)
          ExPrompt.confirm("Pasted into Airtable?")
          acc <> str
        end)
        |> (&File.write(Legl.airtable(), &1)).()
    end

    :ok
  end

  def copy(text) do
    port = Port.open({:spawn, "xclip -selection clipboard"}, [])
    Port.command(port, text)
    Port.close(port)
    IO.puts("copied to clipboard: #{String.slice(text, 0, 10)}...")
  end
end
