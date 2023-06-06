defmodule RUS do
  @moduledoc """
  Parsing text copied from [mevzuat](https://www.pravo.gov.ru)

  pravo.gov.ru has a .rtf download feature.
  Upload into Google docs and copy from there.  This respects
  the correct line length rather than being formatted if copying directly from pravo.gov.ru

  SEARCH http://pravo.gov.ru/proxy/ips/?start_search&fattrib=1
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
            sub: "",
            text: ""

  @impl true
  def schema do
    %AirtableSchema{
      country: :RUS,
      title_name: "заглавие",
      part: ~s/^(\\d+)[ ](.*)/,
      part_name: "chast",
      chapter: ~s/^(\\d+)[ ](.*)/,
      chapter_name: "razdel",
      section: ~s/^(\\d+)[ ](.*)/,
      section_name: "glava",
      article: ~s/^(\\d+[a-z]?-?\\d*)_?(\\d?)[ ](.*)/,
      article_name: "stat'ya",
      para_name: "stat'ya, abzats",
      sub_name: "stat'ya, abzats, podpunkt",
      annex: ~s/^([A-Z]*\\d*)[ ](.*)/,
      annex_name: "prilozheniye",
      amendment: ~s/^(\\d*)_?(\\d*)[ ](.*)/,
      amendment_name: "изменения",
      form: ~s/^(\\d+)[ ](.*)/,
      form_name: "forma",
      approval_name: "утверждение",
      table_name: "tablitsa"
    }
  end

  def clean_(source \\ "pravo") do
    clean(source)
    :ok
  end

  @doc false
  @spec clean(String.t()) :: String.t()
  def clean(source) do
    Legl.txt("original")
    |> Path.absname()
    |> File.read!()
    |> RUS.Parser.clean_original(source)
  end

  @doc """
  Parse the copied text

  Options
  :source -> "cntd" or "pravo" defaults to "pravo"
  :clean -> true = clean before parsing or false = use clean.txt
  :pattern -> :named means the articles are named 'Статья' and this is the default
  """
  @spec parse() :: :atom
  def parse(opts \\ []) do
    source = Keyword.get(opts, :source, "pravo")

    binary =
      case Keyword.get(opts, :clean, false) do
        false ->
          clean(source)

        _ ->
          Legl.txt("clean")
          |> Path.absname()
          |> File.read!()
          |> (&Kernel.binary_part(&1, 8, String.length(&1))).()
      end

    pattern = Keyword.get(opts, :pattern, :named)

    Legl.txt("annotated")
    |> Path.absname()
    |> File.write("#{RUS.Parser.parser(binary, pattern)}")

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
    {:ok, binary} = File.read(Path.absname("lib/annotated.txt"))

    chunk = Keyword.get(opts, :chunk, 200)

    binary = Schema.schema(binary, schema(), opts)

    no_of_lines = Enum.count(String.graphemes(binary), fn x -> x == "\n" end)

    cond do
      no_of_lines < chunk ->
        copy(binary)
        File.write(Legl.airtable(), binary)

      true ->
        String.split(binary, "\n")
        |> Enum.chunk_every(chunk)
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
