defmodule UK do
  @moduledoc """
  Parsing text copied from the plain view at [legislation.gov.uk](https://legislation.gov.uk)
  """

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
  @spec schema(part: part, type: uk_law_type) :: :ok | {:error, :file.posix()}
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
end
