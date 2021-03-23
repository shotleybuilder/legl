defmodule NO do
  @moduledoc """
  Parsing text copied from [lovdata.no](https://lovdata.no/dokument/SF/forskrift/)
  """

  #  Norwegian alphabet:
  #  Æ 	æ
  #  Ø 	ø
  #  Å 	å

  import Legl,
    only: [
      chapter_emoji: 0,
      sub_chapter_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      # amendment_emoji: 0,
      annex_emoji: 0
      # pushpin_emoji: 0,
      # no_join_emoji: 0
    ]

  @typedoc """
  Chapter number

  `1`, `"1A"`
  """
  @type chapter :: integer | String.t()

  @doc """
  Creates an annotated text file `annotated.txt` that can be quality checked by a human.

  Takes an optional boolean to indicate if the text to be parsed is in English.

  ## Running

  ```
  iex -S mix
  iex(1)> NO.parse()
  :ok
  iex(2)> NO.parse(true)
  :ok
  ```
  """
  @spec parse(:boolean) :: :ok | {:error, :file.posix()}
  def parse(english? \\ false) do
    {:ok, binary} = File.read(Path.absname(Legl.original()))

    NO.Parser.parser(binary, english?)
    |> (&File.write(Legl.annotated(), &1)).()
  end

  @doc """
  Creates a text file `airtable.txt` suitable for pasting into Airtable.

  ## Options

  ### Chapter

  Limits the output to the specified chapter.

  ```
  NO.schemas(1)
  NO.schemas("1A")
  ```

  ### Text Only

  Returns the text and omits the numbering scheme and classes.

  ```
  NO.schemas(nil, true)
  NO.schemas("1A", true)
  ```

  ### English?

  For processing English texts

  ```
  NO.schemas(nil, true, true)
  ```

  """
  @spec schemas(chapter, boolean, boolean) :: :ok | {:error, :file.posix()}
  def schemas(chapter \\ nil, text_only? \\ false, english? \\ false) do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))
    schemas(binary, chapter, text_only?, english?)
  end

  @doc false
  def schemas(binary, c, t_o, e) when is_integer(c),
    do: schemas(binary, Integer.to_string(c), t_o, e)

  def schemas(binary, c, t_o, e) do
    record = %{type: "", chapter: "", subchapter: "", article: "", para: 0, str: ""}
    # First line is always the title
    [head | tail] = String.split(binary, "\n", trim: true)
    txts = [~s(title\t\t\t\t\t#{head})]

    schemas =
      tail
      |> Enum.reduce(%{txts: txts, record: record}, fn str, acc ->
        record =
          cond do
            Regex.match?(~r/^#{chapter_emoji()}/, str) -> chapter(str, acc.record, e)
            Regex.match?(~r/^#{sub_chapter_emoji()}/, str) -> subchapter(str, acc.record)
            Regex.match?(~r/^#{article_emoji()}/, str) -> article(str, acc.record)
            Regex.match?(~r/^#{sub_article_emoji()}/, str) -> subarticle(str, acc.record)
            Regex.match?(~r/^#{annex_emoji()}/, str) -> annex(str, acc.record)
            true -> para(str, acc.record)
          end

        case c do
          nil ->
            %{acc | txts: [conv_map_to_record_string(record) | acc.txts], record: record}

          _ ->
            case record.chapter == c do
              true ->
                %{acc | txts: [conv_map_to_record_string(record) | acc.txts], record: record}

              _ ->
                %{acc | record: record}
            end
        end
      end)

    Enum.count(schemas.txts) |> IO.inspect(label: "txts")

    # just want the text and not the classes?
    txts =
      case t_o do
        true ->
          Enum.map(schemas.txts, &txt_only/1)

        false ->
          schemas.txts
      end

    Enum.reverse(txts)
    |> Enum.join("\n")
    |> String.replace("💥️", "")
    |> (&File.write(Legl.airtable(), &1)).()
  end

  defp txt_only(str) do
    case Regex.run(~r/^\w+\t[\w ]*\t[\w ]*\t[\w ]*\t[\w ]*\t(.*)[ ]*$/, str) do
      [_, capture] ->
        capture

      nil ->
        IO.inspect(str)
        ""
    end
  end

  defp conv_map_to_record_string(%{
         type: type,
         chapter: chapter,
         subchapter: subchapter,
         article: article,
         para: para,
         str: str
       }) do
    para = if para == 0, do: "", else: para
    ~s(#{type}\t#{chapter}\t#{subchapter}\t#{article}\t#{para}\t#{str})
  end

  # Regex.run(~r/^#{Legl.chapter_emoji()}Kapi?t?t?e?l?\.?[ ]*(\d+[ ]?[A-Z]?)?(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\./, "🇳🇴Kapittel 1. Innledende bestemmelser")
  defp chapter(str, record, _e) do
    regex =
      ~r/^#{chapter_emoji()}((?:Kapi?t?t?e?l?\.?)|(?:Chapter\.?))[ ]*(\d+)?(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})/

    capture =
      case Regex.run(regex, str) do
        [_, _, capture, "", ""] -> capture
        [_, _, _, _, capture] -> Legl.conv_roman_numeral(capture)
      end

    str = String.replace(str, chapter_emoji(), "")
    %{record | type: "chapter", chapter: capture, subchapter: "", article: "", para: 0, str: str}
  end

  defp subchapter(str, record) do
    regex = ~r/^#{sub_chapter_emoji()}(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.[ ]/
    [_, _, capture] = Regex.run(regex, str)
    str = String.replace(str, sub_chapter_emoji(), "")

    %{
      record
      | type: "sub-chapter",
        subchapter: Legl.conv_roman_numeral(capture),
        article: "",
        para: 0,
        str: str
    }
  end

  defp article(str, record) do
    regex =
      case Regex.match?(~r/^#{article_emoji()}(?:§[ ]+|(?:Section)[ ]+)(\d+)\./, str) do
        true -> ~r/^#{article_emoji()}(?:§[ ]+|(?:Section)[ ]+)(\d+)\./
        false -> ~r/^#{article_emoji()}(?:§[ ]+|(?:Section)[ ]+)\d+[a-z]?[ ]?[A_Z]?\-(\d+)\./
      end

    [_, capture] = Regex.run(regex, str)
    str = String.replace(str, article_emoji(), "")
    %{record | type: "article", article: capture, para: 0, str: str}
  end

  defp subarticle(str, record) do
    regex = ~r/^#{sub_article_emoji()}§[ ]+(\d+[ ]?[a-z]?)\-?(\d*[ ]?[a-z]*)\./

    capture =
      case Regex.run(regex, str) do
        [_, _, capture] -> String.replace(capture, " ", "")
        [_, capture] -> String.replace(capture, " ", "")
      end

    str = String.replace(str, sub_article_emoji(), "")
    %{record | type: "sub-article", article: capture, para: 0, str: str}
  end

  defp para(str, record) do
    rest =
      case Regex.match?(~r/^#{numbered_para_emoji()}/, str) do
        true ->
          <<_::binary-size(3), rest::binary>> = str
          rest

        false ->
          <<_::binary-size(4), rest::binary>> = str
          rest
      end

    %{record | type: "para", para: record.para + 1, str: rest}
  end

  defp annex(str, record) do
    regex =
      ~r/^#{annex_emoji()}(((?:Vedlegg)|(?:Annex))\.?[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3}|\d+):?\.?[ ]+[A-ZÅØ].*)/

    [_, str, _, _, capture] = Regex.run(regex, str)
    %{record | type: "annex", para: Legl.conv_roman_numeral(capture), str: str}
  end
end
