defmodule UK.Act do
  @fields [
    :flow,
    :type,
    :part,
    :chapter,
    :heading,
    :section,
    :sub_section,
    :article,
    :para,
    :text
  ]
  @number_fields [
    :part,
    :chapter,
    :heading,
    :section,
    :sub_section,
    :article,
    :para,
  ]
  defstruct @fields
  def fields(), do: @fields
  def number_fields(), do: @number_fields
end
defmodule UK.Regulation do
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
  def fields(), do: @fields
  def number_fields(), do: @number_fields
end
defmodule UK do
  @moduledoc """
  Parsing text copied from the plain view at [legislation.gov.uk](https://legislation.gov.uk)
  """

  alias Types.AirtableSchema

  # @impl true
  def schema(type) do
    case type do
      :act -> %AirtableSchema{
          country: :UK,
          fields: UK.Act.fields(),
          number_fields: UK.Act.number_fields(),
          heading: ~s/^(\\d+)[ ](.*)/
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

  @spec parse_new(keyword) :: :ok
  @doc """
  Parse the copied text

  Options
  :clean -> true = clean before parsing or false = use clean.txt
  """
  def parse_new(opts \\ []) do
    binary =
      case Keyword.get(opts, :clean, true) do
        true ->
          clean(Keyword.get(opts, :type, :regulation))

        _ ->
          Legl.txt("clean")
          |> Path.absname()
          |> File.read!()
          |> (&Kernel.binary_part(&1, 8, String.length(&1))).()
      end
      case Keyword.get(opts, :parse, true) do
        true ->
          Legl.txt("annotated")
          |> Path.absname()
          |> File.write("#{UK.Parser.parser(binary, Keyword.get(opts, :type, :regulation))}")
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

  @spec airtable(keyword) :: :ok
  @doc """
  Create Airtable data using all fields

  Run as:
  iex>UK.airtable()

  Options as list.

  For fields, eg DE.airtable(fields: [:text])  See %UK{}
  """
  def airtable(opts) do

    type = Keyword.get(opts, :type, :regulation)
    fields =
      case type do
        :act -> UK.Act.fields
        :regulation -> UK.Regulation.fields
      end
    struct =
      case type do
        :act -> %UK.Act{}
        :regulation -> %UK.Regulation{}
      end
    opts = Enum.into(opts, [fields: fields])
    Legl.airtable(struct, schema(type), opts)
  end

  alias UK.Parser, as: Parser
  alias UK.Schema, as: Schema

  @parse_options %{type: :regulation, part: :both}
  @schema_options %{type: :regulation, part: :both, fields: []}

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

  @doc """
  Creates an annotated text file that can be quality checked by a human.

  Emojis are used as markers of different paragraph types.
  These enable the visual check and are also used by the parser.

  UK Acts and Regulations (primary and secondary legislation) have to be parsed
  differently and this is set with the `:type` option.

  Laws often have 2 parts: a main content section and a section of schedules.
  Save text copied from the main content section  as `original.txt` & that copied from
  the schedules as `original_annex.txt`.  Use the `:part` option to use `:both` (which is also the default) files,
  or just `:main` for laws without schedules.

  ## Options

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
  @spec parse(part: part, type: uk_law_type) :: :ok | {:error, :file.posix()}
  def parse(options \\ []) when is_list(options) do
    %{type: type, part: part} = Enum.into(options, @parse_options)
    parse(part, type)
  end

  @doc false
  @spec parse(part, Atom) :: :ok | {:error, :file.posix()}
  def parse(:both, type) when is_atom(type) do
    File.write(Legl.annotated(), "#{Parser.parser(type)}\n#{Parser.parse_annex()}")
  end

  def parse(:main, type) when is_atom(type) do
    File.write(Legl.annotated(), "#{Parser.parser(type)}")
  end

  def parse(:annex, _type) do
    File.write(Legl.annotated_annex(), "#{Parser.parse_annex()}")
  end

  @doc """
  Translates the annotated text file of the law into a tab-delimited text file suitable for pasting
  directly into an Airtable grid view.

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

  def schema(options \\ []) when is_list(options) do
    %{type: type, part: part, fields: fields} = Enum.into(options, @schema_options)
    Schema.schemas(part, type, fields)
  end

  @doc false
  @spec schema(part, uk_law_type, []) :: :ok | {:error, :file.posix()}
  def schema(part, type, fields \\ []) when is_atom(part) and is_atom(type) do
    {:ok, binary} =
      case part do
        :annex -> File.read(Path.absname(Legl.annotated_annex()))
        :law -> File.read(Path.absname(Legl.annotated()))
        _ -> File.read(Path.absname(Legl.annotated()))
      end

    Schema.schemas(type, binary, fields)
  end

  def amends() do
    UK.Amend.parse_amend()
  end

  def amend_csv() do
    UK.Amend.make_csv_file()
  end
end
