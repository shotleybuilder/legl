defmodule DK do
  @moduledoc """
  Parsing text copied from https://www.retsinformation.dk


  """

  # @behaviour Country
  alias Types.AirtableSchema

  defstruct flow: "",
            type: "",
            part: "",
            chapter: "",
            section: " ",
            article: "",
            para: "",
            sub: "",
            text: ""

  # @impl true
  def schema do
    %AirtableSchema{
      country: :DK,
      title_name: "titel",
      part: ~s/^(\\d+)[ ](.*)/,
      part_name: "",
      chapter: ~s/^(\\d+)[ ](.*)/,
      chapter_name: "kapitel",
      section: ~s/^[ ](.*)/,
      section_name: "afsnit",
      article: ~s/^(\\d+[a-z]?-?\\d*)_?(\\d?)[ ](.*)/,
      article_name: "§",
      para_name: "",
      sub_name: "",
      annex: ~s/^([A-Z]*\\d*)[ ](.*)/,
      annex_name: "bilag",
      amendment: ~s/^(\\d*)_?(\\d*)[ ](.*)/,
      amendment_name: "",
      form: ~s/^(\\d+)[ ](.*)/,
      form_name: "",
      approval_name: "godkendelse",
      table_name: "",
      note_name: "noter"
    }
  end

  def clean_() do
    clean()
    :ok
  end

  @doc false
  @spec clean() :: String.t()
  def clean() do
    Legl.txt("original")
    |> Path.absname()
    |> File.read!()
    |> DK.Parser.clean_original()
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
    binary =
      case Keyword.get(opts, :clean, false) do
        false ->
          clean()

        _ ->
          Legl.txt("clean")
          |> Path.absname()
          |> File.read!()
          |> (&Kernel.binary_part(&1, 8, String.length(&1))).()
      end

    Legl.txt("annotated")
    |> Path.absname()
    |> File.write("#{DK.Parser.parser(binary)}")

    :ok
  end

  @doc """
  Create Airtable data using all fields

  Run as:
  iex>DK.airtable()

  Options as list.  See %DK{}
  """
  @spec airtable([]) :: :atom
  def airtable(opts \\ []) do
    Legl.airtable(%DK{}, schema(), opts)
  end
end
