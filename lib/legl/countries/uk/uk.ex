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

  # @impl true
  def schema(type) do
    case type do
      :act -> %AirtableSchema{
          country: :UK,
          fields: UK.Act.fields(),
          number_fields: UK.Act.number_fields(),
          part: ~s/^(\\d+|[A-Z])[ ](.*)[ ]\\[::region::\\](.*)/,
          heading: ~s/^(\\d+)[ ](.*)[ ]\\[::region::\\](.*)/,
          section: ~s/^(\\d+[a-zA-Z]*)-?(\\d+)?[ ](.*)[ ]\\[::region::\\](.*)/,
          amendment: ~s/^([A-Z])(.*)/,
          sub_section: ~s/^(\\d+[A-Z]?)[ ](.*)/,
          amendment_name: "amendment",
          annex: ~s/(\\d*)[ ](.*)[ ]\\[::region::\\](.*)/
        }
      :regulation ->
        %AirtableSchema{
          country: :UK,
          fields: UK.Regulation.fields(),
          number_fields: UK.Regulation.number_fields(),
          part: ~s/^(\\d+|[A-Z])[ ](.*)/,
          chapter_name: "chapter",
          chapter: ~s/^(\\d+)[ ](.*)/,
          heading_name: "article, heading",
          sub_section_name: "article, heading",
          article_name: "article",
          article: ~s/^(\\d+)[ ](.*)/,
          sub_article_name: "subarticle",
          sub_article: ~s/^(\\d+)[ ](.*)/,
          para_name: "sub-article",
          para: ~s/^(\\d+)[ ](.*)/,
          signed_name: "signed",
          annex_name: "annex",
          annex: ~s/^(\\d+)[ ](.*)/,
          footnote_name: "footnote",
          amendment: ~s/[ ](.*)/,
          amendment_name: "§§"
        }
    end
  end

  @parse_default_opts %{
    type: :regulation,
    clean: true,
    parse: true
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

    binary =
      case opts.clean do
        true ->
          clean(opts.type)

        _ ->
          Legl.txt("clean")
          |> Path.absname()
          |> File.read!()
          |> (&Kernel.binary_part(&1, 8, String.length(&1))).()
      end

    case opts.parse do
      true ->
        Legl.txt("annotated")
        |> Path.absname()
        |> File.write("#{UK.Parser.parser(binary, opts.type)}")
        :ok
      _ ->
        :ok
    end
  end

  @spec clean_(:atom) :: :ok
  def clean_(type) do
    clean(type)
    :ok
  end

  @doc false
  @spec clean(:atom) :: String.t()
  def clean(type) do
    Legl.txt("original")
    |> Path.absname()
    |> File.read!()
    |> UK.Parser.clean_original(type)
  end

  @airtable_default_opts %{
    type: :regulation,
    clean: true,
    parse: true,
    csv: true,
    tdl: false, #tab delimited list
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

    `iex(1)>UK.schema()`

    or with Options

    `iex(2)>UK.schema(part: :annex, type: :regulation)`

    `iex(3)>UK.schema(:law, :regulation)`

    `iex(4)>UK.schema(:law, :act, [:article, :text])`
  """
  def airtable(name, opts \\ []) do

    opts =
      Enum.into(opts, @airtable_default_opts)
      |> Map.put(:name, name)

    # fields as a list
    # [:flow, :type, :part, :chapter, :heading, :section, :sub_section, :article, :para, :text, :region]
    fields =
      case opts.type do
        :act -> UK.Act.fields
        :regulation -> UK.Regulation.fields
      end

    Legl.airtable(
      schema(opts.type),
      Keyword.merge(Map.to_list(opts), [fields: fields])
    )

    :ok
  end

end
