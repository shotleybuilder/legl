defmodule DE do
  @moduledoc """
  Parsing text copied from https://www.retsinformation.dk


  """

  # @behaviour Country
  alias Types.AirtableSchema

  @fields [
    :flow,
    :type,
    :part,
    :chapter,
    :section,
    :sub_section,
    :article,
    :para,
    :sub,
    :text
  ]

  @number_fields [
    :part,
    :chapter,
    :section,
    :sub_section,
    :article,
    :para,
    :sub
  ]

  defstruct @fields

  # @impl true
  def schema do
    %AirtableSchema{
      country: :DE,
      fields: @fields,
      number_fields: @number_fields,
      title_name: "titel",
      part_name: "teil",
      chapter_name: "kapitel",
      section: ~s/^(\\d+[a-z]*)[ ](.*)/,
      section_name: "abschnitt",
      sub_section_name: "unterabschnitt",
      article: ~s/^(\\d+[a-z]?)[ ](.*)/,
      article_name: "§",
      para_name: "§, paragraf",
      annex_name: "anhang",
      approval_name: "eingangsformel",
      footnote_name: "fußnote",
      amendment: ~s/[ ](.*)/,
      amendment_name: "§§"
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
    |> DE.Parser.clean_original()
  end

  @doc """
  Parse the copied text

  Options
  :clean -> true = clean before parsing or false = use clean.txt
  :language -> "EN" defaults to "DE"
  """
  @spec parse() :: :atom
  def parse(opts \\ []) do
    binary =
      case Keyword.get(opts, :clean, true) do
        true ->
          clean()

        _ ->
          Legl.txt("clean")
          |> Path.absname()
          |> File.read!()
          |> (&Kernel.binary_part(&1, 8, String.length(&1))).()
      end

    Legl.txt("annotated")
    |> Path.absname()
    |> File.write("#{DE.Parser.parser(binary, Keyword.get(opts, :language, "DE"))}")

    :ok
  end

  @doc """
  Create Airtable data using all fields

  Run as:
  iex>DK.airtable()

  Options as list.

  For fields, eg DE.airtable(fields: [:text])  See %DE{}
  """
  @spec airtable([]) :: :atom
  def airtable(opts \\ [fields: @fields]) do
    Legl.airtable(schema(), opts)
  end
end
