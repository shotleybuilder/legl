defmodule UK do
  @moduledoc """
  Parsing text copied from the plain view at [legislation.gov.uk](https://legislation.gov.uk)
  """

  alias Types.AirtableSchema

  @typedoc """
  A part of a piece of legislation.

  `:both`, `:law`, `:annex`
  """
  @type part :: atom

  @typedoc """
  The type of a piece of legislation.

  `:act`, `:regulation`
  """
  @type uk_law_type :: atom

  @region_regex "U\\.K\\.|E\\+W\\+N\\.I\\.|E\\+W\\+S|E\\+W"
  @country_regex "N\\.I\\.|S|W|E"

  def region(), do: @region_regex
  def country(), do: @country_regex

  # @impl true
  def schema(type) do
    case type do
      :act ->
        %AirtableSchema{
          country: :UK,
          fields: UK.Act.fields(),
          number_fields: UK.Act.number_fields(),
          part: ~s/^(\\d+|[A-Z])[ ](.*)[ ]\\[::region::\\](.*)/,
          heading: ~s/^([A-Z]?\\d+[A-Z]?)[ ](.*)[ ]\\[::region::\\](.*)/,
          section: ~s/^([A-Z]?\\d+[a-zA-Z]*)-?(\\d+)?[ ](.*)[ ]\\[::region::\\](.*)/,
          sub_section: ~s/^(\\d+[A-Z]?)[ ](.*)/,
          amendment: ~s/^([A-Z])(\\d+)(.*)/,
          modification: ~s/^(C)(\\d+)(.*)/,
          annex: ~s/(\\d*[A-Z]?)[ ](.*?(SCHEDULES?|Schedules?).*)[ ]\\[::region::\\](.*)/
        }

      :regulation ->
        %AirtableSchema{
          country: :UK,
          fields: UK.Regulation.fields(),
          number_fields: UK.Regulation.number_fields(),
          part: ~s/^(\\d+|[A-Z])[ ](.*)[ ]\\[::region::\\](.*)/,
          chapter_name: "chapter",
          chapter: ~s/^(\\d+)[ ](.*)/,
          heading: ~s/^(\\d+[A-Z]?)[ ](.*)[ ]\\[::region::\\](.*)/,
          heading_name: "heading",
          article: ~s/^(\\d+[a-zA-Z]*)-?(\\d+)?[ ](.*)[ ]\\[::region::\\](.*)/,
          article_name: "article",
          sub_article: ~s/^(\\d+)[ ](.*)/,
          sub_article_name: "sub-article",
          para: ~s/^(\\d+)[ ](.*)/,
          para_name: "sub-article",
          signed_name: "signed",
          annex: ~s/^(\\d*[A-Z]?)[ ](.*)[ ]\\[::region::\\](.*)/,
          annex_name: "schedule",
          footnote_name: "footnote",
          amendment: ~s/^([A-Z])(\\d+)(.*)/
        }
    end
  end

  @parse_default_opts %{
    type: :regulation,
    clean: true,
    parse: true,
    qa_list_efs: false,
    list_section_efs: false,
    qa_list_bracketed_efs: false,
    list_headings: false,
    qa_sections: true
  }

  @doc """
  Creates an annotated text file that can be quality checked by a human.

  UK Acts and Regulations (primary and secondary legislation) have to be parsed
  differently and this is set with the `:type` option.

  Laws often have 2 parts: a main content section and a section of schedules.
  Save text copied from the main content section  as `original.txt` & that copied from
  the schedules as `original_annex.txt`.  Use the `:part` option to use `:both` (which is also the default) files,
  or just `:main` for laws without schedules.

  ## Options

  :clean -> true = clean before parsing or false = use clean.txt

  Type can be `:act` or `:regulation`, defaults to `:regulation`

  Part can be `:both`, `:main` or `:annex`, defaults to `:both`

  ## Running

  `>iex -S mix`

  `iex(1)>UK.parse()`

  or with Options

  `iex(2)>UK.parse(part: :annex, type: :regulation)`

  `iex(3)>UK.parse(:main, :regulation)`

  `iex(4)>UK.parse(:annex)`
  """
  def parse(opts \\ []) do
    opts = Enum.into(opts, @parse_default_opts)

    IO.inspect(opts, label: "Options: ")

    binary =
      case opts.clean do
        true ->
          Legl.txt("original")
          |> Path.absname()
          |> File.read!()
          |> Legl.Countries.Uk.UkClean.clean_original(opts)

        _ ->
          Legl.txt("clean")
          |> Path.absname()
          |> File.read!()
          |> (&Kernel.binary_part(&1, 8, String.length(&1))).()
      end

    binary = Legl.Countries.Uk.AirtableArticle.UkAnnotations.annotations(binary, opts)

    case opts.parse do
      true ->
        Legl.txt("annotated")
        |> Path.absname()
        |> File.write("#{UK.Parser.parser(binary, opts)}")

        :ok

      _ ->
        :ok
    end
  end

  @airtable_default_opts %{
    country: :uk,
    type: :regulation,
    csv: true,
    # tab delimited list
    tdl: false,
    chunk: 200
  }

  @doc """

    Translates the annotated text file of the law into a tab-delimited text file and a csv file
    suitable for pasting / uploading directly into an Airtable grid view.

    Create Airtable data using all fields

    Run as:
    iex>UK.airtable()

    Options as list.

    For fields, eg DE.airtable(fields: [:text])  See %UK{}

    The Airtable fields are:

    * flow
    * type
    * part
    * chapter
    * subchapter
    * article
    * para
    * sub
    * text

    ## Options

    Type can be `:act` or `:regulation`, defaults to `:regulation`

    Part can be `:both`, `:law` or `:annex`, defaults to `:both`

    Fields, a list of one or more of the Airtable field names, to generate data just for those fields.
    E.g. `[:flow, :text]`  Defaults to an empty list `[]`.

    ## Running

    `>iex -S mix`

    `iex(1)>UK.airtable(name: "airtable-id", type: :regulation)`

  """
  def airtable(opts \\ []) do
    opts = Enum.into(opts, @airtable_default_opts)
    # |> Map.put(:name, name)

    IO.inspect(opts, label: "Options: ")

    # fields as a list
    # [:flow, :type, :part, :chapter, :heading, :section, :sub_section, :article, :para, :text, :region]
    fields =
      case opts.type do
        :act -> UK.Act.fields()
        :regulation -> UK.Regulation.fields()
      end

    Legl.airtable(
      schema(opts.type),
      Keyword.merge(Map.to_list(opts), fields: fields)
    )

    :ok
  end
end
