defmodule SWE do
  @moduledoc """
  Scripts to process text from the Swedish legal database and pdf files from regulatory
  agencies.  The parser creates a text file that can be pasted into Airtable.

  original.txt file is used to store the text content copied from http://rkrattsbaser.gov.se/
  or pdfs and airtable.txt is for pasting into Airtable.

  ## Running

  Run the scripts in the terminal.

  Navigate into the project folder then boot interactive elixir:

  ```
  iex -S mix
  ```

  ## Note on PDFs

  Parser for .pdfs published on the following websites:

  [boverket.se](https://www.boverket.se)

  [elsakerhetsverket.se](https://www.elsakerhetsverket.se)

  [av.se](https://www.av.se)

  [transportstyrelsen.se](https://www.transportstyrelsen.se)

  Use the chrome pdf viewer to copy the content of the .pdf into the `original.txt` file.

  """

  @doc """
  Creates an annotated text file `annotated.txt` that can be quality checked by a human.

  Emojis are used as markers of different paragraph types.
  These enable the visual check and are also used by the parser.

  ## Function Parameter

  A name from the following list depending on the source of the law:

  * rkrattsbaser
  * boverket
  * elsak
  * av
  * msb
  * stemfs
  * tsfs

  ## Running

  ```
  iex -S mix
  iex(1)> SWE.parse("av")
  ```

  """

  @spec parse(String.t()) :: :ok | {:error, :file.posix()}
  def parse(source) do
    {:ok, binary} = File.read(Path.absname(Legl.original()))
    File.write("lib/annotated.txt", parse(binary, source))
  end

  @doc false
  def parse(binary, "rkrattsbaser") do
    SWE.Rkrattsbaser.parser(binary)
  end

  def parse(binary, "boverket") do
    binary
    |> SWE.Boverket.page_markers()
    |> SWE.Pdf.parser()
  end

  def parse(binary, "elsak") do
    binary
    |> SWE.Elsakerhetsverket.rm_page_markers()
    |> SWE.Elsakerhetsverket.rm_guidance()
    |> SWE.Pdf.parser()
  end

  def parse(binary, "av") do
    binary
    |> SWE.Av.rm_page_marker()
    |> SWE.Pdf.parser()
  end

  def parse(binary, "msb") do
    # remove page markers
    binary =
      Regex.replace(
        ~r/^MSBFS[ ]*(?:\r\n|\n)+[ ]?\d{4}:\d+(?:\r\n|\n)\d+(?:\r\n|\n)/m,
        binary,
        "\n"
      )

    binary = Regex.replace(~r/^MSBFS[ ]\d{4}:\d+[\r\n|\n]\d+/m, binary, "")
    binary = Regex.replace(~r/^MSBFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")

    SWE.Pdf.parser(binary)
  end

  def parse(binary, "stemfs") do
    # remove page markers
    binary = Regex.replace(~r/^STEMFS[ ]*(?:\r\n|\n)+[ ]?\d{4}:\d+(?:\r\n|\n)/m, binary, "\n")
    binary = Regex.replace(~r/^STEMFS[ ]\d{4}:\d+[\r\n|\n]\d+/m, binary, "")
    binary = Regex.replace(~r/^STEMFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")

    SWE.Pdf.parser(binary)
  end

  def parse(binary, "tsfs") do
    # remove page markers
    binary = Regex.replace(~r/^\d+(?:\r\n|\n)TSFS[ ]*\d{4}:\d+(?:\r\n|\n)/m, binary, "\n")
    # TSFS 2010:155
    binary = Regex.replace(~r/^TSFS[ ]\d{4}:\d+(?:\r\n|\n)/m, binary, "")
    binary = Regex.replace(~r/^TSFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")

    SWE.Pdf.parser(binary)
  end

  @doc """
  Creates a text file `airtable.txt` that can be pasted into Airtable.

  With additional .txt files for chapter numbers, article numbers,
  article types, section numbers.

  ## Argument

  Use `"rkrattsbaser"` when the text has been copied from that source.
  Otherwise leave empty.

  ## Running

  ```
  iex -S mix
  iex(1)> SWE.schemas()
  chapter: xx
  articles: xx
  types: xx
  :ok
  iex(2)> SWE.schemas("rkrattsbaser")
  chapter: xx
  articles: xx
  types: xx
  :ok
  ```

  """
  def schemas(source \\ "") do
    {:ok, binary} = File.read(Path.absname("lib/annotated.txt"))

    case source do
      "rkrattsbaser" ->
        binary = SWE.Rkrattsbaser.clean(binary)
        File.write(Legl.airtable(), binary)
        SWE.Rkrattsbaser.chapter_numbers(binary)
        SWE.Rkrattsbaser.article_numbers(binary)
        SWE.Rkrattsbaser.schema(binary)

      _ ->
        binary = SWE.Pdf.clean(binary)
        File.write(Legl.airtable(), binary)
        SWE.Pdf.chapter_numbers(binary)
        SWE.Pdf.article_numbers(binary)
        SWE.Pdf.schema(binary)
    end
  end
end
