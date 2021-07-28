defmodule RUS do
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
            section: "",
            article: "",
            para: "",
            sub: 0,
            text: ""

  @impl true
  def schema do
    %AirtableSchema{
      country: :RUS,
      part: ~s/^(\\d+)[ ](.*)/,
      part_name: "chast",
      chapter: ~s/^(\\d+)[ ](.*)/,
      chapter_name: "razdel",
      section: ~s/^(\\d+)[ ](.*)/,
      section_name: "glava",
      heading: ~s//,
      heading_name: "",
      article: ~s/^(\\d+[a-z]?-?\\d*)_?(\\d?)[ ](.*)/,
      article_name: "stat'ya",
      sub_article: ~s//,
      sub_article_name: "",
      annex: ~s/^([A-Z]+\\d+)[ ](.*)/,
      annex_name: "prilozheniye",
      amendment: ~s//,
      amendment_name: "",
      form: ~s/^(\\d+)[ ](.*)/,
      form_name: "forma",
      approval_name: "odobreniye",
      table_name: "tablitsa"
    }
  end

  def clean(true) do
    Legl.txt("original")
    |> Path.absname()
    |> File.read!()
    |> RUS.Parser.clean_original()
    |> (&IO.puts("cleaned: #{String.slice(&1, 0, 10)}...")).()
  end

  @doc false
  @spec clean() :: String.t()
  def clean(),
    do: RUS.Parser.clean_original(File.read!(Path.absname(Legl.original())))

  @doc false
  @spec parse() :: :atom
  def parse() do
    binary = clean()

    Legl.txt("annotated")
    |> Path.absname()
    |> File.write("#{RUS.Parser.parser(binary)}")

    :ok
  end

  @doc """
  Create Airtable data using all fields

  Run as:
  iex>RUS.airtable()

  Options as list.  See %RUS{}
  """
  @impl true
  @spec airtable([]) :: :atom
  def airtable(opts \\ []) when is_list(opts) do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))

    binary = Schema.schema(%RUS{}, binary, schema(), opts)

    no_of_lines = Enum.count(String.graphemes(binary), fn x -> x == "\n" end)

    cond do
      no_of_lines < 50 ->
        copy(binary)
        File.write(Legl.airtable(), binary)

      true ->
        String.split(binary, "\n")
        |> Enum.chunk_every(50)
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
