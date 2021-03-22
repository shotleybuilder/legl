defmodule UK do
  @moduledoc """
  Parsing text copied from the plain view at [legislation.gov.uk](https://legislation.gov.uk)

  Two main functions:

    * def parse
    * def schemas

  def parse
  """
  import Legl,
    only: [
      part_emoji: 0,
      chapter_emoji: 0,
      # sub_chapter_emoji: 0,
      heading_emoji: 0,
      # annex_heading_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      annex_emoji: 0
      # signed_emoji: 0,
      # pushpin_emoji: 0,
      # amendment_emoji: 0
    ]

  alias UK.Schema, as: Schema
  alias UK.Parser, as: Parser

  @parse_options %{type: :regulation, part: :both}

  @doc """
  Parser creates an annotated text file that can be quality checked by a human.

  Emojis are used as markers of different paragraph types.
  These enable the visual check and are also used by the parser.

  ## Options

  Type can be `:act` or `:regulation`, defaults to `:regulation`

  Part can be `:both`, `:law` or `:annex`, defaults to `:both`

  ## Running

  `>iex -S mix`

  `iex(1)>UK.parse()`

  or with Options

  `iex(2)>UK.parse(part: :annex, type: :regulation)`

  `iex(3)>UK.parse(:law, :regulation)`

  `iex(4)>UK.parse(:annex)`
  """

  def parse(options \\ []) when is_list(options) do
    %{type: type, part: part} = Enum.into(options, @parse_options)
    parse(part, type)
  end

  @doc false

  def parse(:both, type) do
    File.write(Legl.annotated(), "#{Parser.parser(type)}\n#{Parser.parse_annex()}")
  end

  def parse(:law, type) do
    File.write(Legl.annotated(), "#{Parser.parser(type)}")
  end

  def parse(:annex, _type) do
    File.write(Legl.annotated_annex(), "#{Parser.parse_annex()}")
  end

  @schema_options %{type: :regulation, part: :both, fields: []}

  def schemas(options \\ []) when is_list(options) do
    %{type: type, part: part, fields: fields} = Enum.into(options, @schema_options)
    schemas(type, part, fields)
  end

  def schemas(type, part, fields) when is_atom(part) do
    {:ok, binary} =
      case part do
        :annex -> File.read(Path.absname(Legl.annotated_annex()))
        :law -> File.read(Path.absname(Legl.annotated()))
        _ -> File.read(Path.absname(Legl.annotated()))
      end

    schemas(type, binary, fields)
  end

  def schemas(type, binary, fields) when is_binary(binary) do
    # First line is always the title
    [head | tail] = String.split(binary, "\n", trim: true)
    schema = %Schema{}
    txts = [%{schema | type: "title", str: head}]

    # txts = [~s(\ttitle\t\t\t\t\t\t#{head})]

    schemas =
      tail
      |> Enum.reduce(%{txts: txts, record: schema}, fn str, acc ->
        record =
          cond do
            Regex.match?(~r/^#{article_emoji()}/, str) -> article(type, str, acc.record)
            Regex.match?(~r/^#{sub_article_emoji()}/, str) -> sub_article(type, str, acc.record)
            Regex.match?(~r/^#{heading_emoji()}/, str) -> heading(type, str, acc.record)
            Regex.match?(~r/^#{annex_emoji()}/, str) -> annex(str, acc.record)
            # Regex.match?(~r/^#{annex_heading_emoji()}/, str) -> annex_heading(str, acc.record)
            Regex.match?(~r/^#{part_emoji()}/, str) -> part(type, str, acc.record)
            Regex.match?(~r/^#{chapter_emoji()}/, str) -> chapter(type, str, acc.record)
            true -> sub(str, acc.record)
          end

        %{acc | txts: [record | acc.txts], record: record}
      end)

    Enum.count(schemas.txts) |> IO.inspect(label: "txts")

    case fields do
      [] -> Enum.map(schemas.txts, &conv_map_to_record_string/1)
      _ -> limit_fields(schemas.txts, fields)
    end
    |> Enum.reverse()
    |> Enum.join("\n")
    |> (&File.write(Legl.txts(), &1)).()
  end

  defp limit_fields(records, fields) when fields != [] do
    Enum.reduce(records, [], fn record, acc ->
      str =
        Enum.reduce(fields, "", fn field, str ->
          str <> <<9>> <> Map.get(record, field)
        end)

      [str | acc]
    end)
    |> Enum.map(&String.trim/1)
    |> Enum.reverse()
    |> IO.inspect()
  end

  defp limit_fields(records, _fields), do: records

  defp conv_map_to_record_string(%Schema{
         flow: flow,
         type: type,
         part: part,
         chapter: chapter,
         subchapter: subchapter,
         article: article,
         para: para,
         sub: sub,
         str: str
       }) do
    sub = if sub == 0, do: "", else: sub
    ~s(#{flow}\t#{type}\t#{part}\t#{chapter}\t#{subchapter}\t#{article}\t#{para}\t#{sub}\t#{str})
  end

  @doc """
  Build Airtable record for an article_emoji
  Articles w/o sub-articles have a ref of " "
  """
  def article(:act, str, record) do
    str = String.replace(str, article_emoji(), "")
    [_, _, value] = Regex.run(~r/(\[F\d*[ ])?(\d+)/, str)
    %{record | type: "section", article: value, para: "", str: str}
  end

  def article(:regulation, str, record) do
    str = String.replace(str, article_emoji(), "")

    case Regex.run(~r/^(\d+)\.(#{<<226, 128, 148>>}|\-)\((\d+)\)/, str) do
      nil ->
        case record.flow do
          "post" ->
            [_, value] = Regex.run(~r/^(\d+)\./, str)
            %{record | type: "schedule, article", para: value, str: str}

          _ ->
            %{record | type: "article", para: " ", str: str}
        end

      [_, article, _, para] ->
        %{record | type: "article, sub-article", article: article, para: para, str: str}
    end
  end

  def sub_article(:act, str, record) do
    str = String.replace(str, sub_article_emoji(), "")
    [_, value] = Regex.run(~r/\((\d+)\)/, str)
    %{record | type: "sub-section", para: value, str: str}
  end

  def sub_article(:regulation, str, record) do
    str = String.replace(str, sub_article_emoji(), "")
    [_, value] = Regex.run(~r/^\((\d+)\)/, str)
    %{record | type: "sub-article", para: value, str: str}
  end

  def heading(:act, str, record) do
    str = String.replace(str, heading_emoji(), "")

    %{
      record
      | type: "section, heading",
        subchapter: increment_string(record.subchapter),
        article: "",
        para: "",
        str: str
    }
  end

  def heading(:regulation, str, record) do
    str = String.replace(str, heading_emoji(), "")

    {value, str} =
      case Regex.run(~r/^(\d+)[ ](.*)/, str) do
        [_, value, str] ->
          {value, str}

        nil ->
          IO.inspect(str)
          {"NaN", str}
      end

    article_type =
      case record.flow do
        "post" -> "schedule, heading"
        _ -> "article, heading"
      end

    %{record | type: article_type, article: value, para: "", sub: 0, str: str}
  end

  def annex(str, record) do
    str = String.replace(str, annex_emoji(), "")

    value =
      case Regex.run(~r/^SCHEDULE[ ](\d+)/, str) do
        [_, value] -> value
        nil -> ""
      end

    %{
      record
      | type: "schedule",
        chapter: "s" <> value,
        article: "",
        para: "",
        sub: 0,
        str: str,
        flow: "post"
    }
  end

  def part(type, str, record) do
    str = String.replace(str, part_emoji(), "")
    [_, value, part, i, str] = Regex.run(~r/^(\d+[ ])(PART|Part)[ ](\d|[A-Z])+[ ](.*)/, str)

    article_type =
      case record.flow do
        "post" -> "schedule, part"
        _ -> "part"
      end

    case type do
      :act ->
        %{
          record
          | type: article_type,
            part: value,
            chapter: "",
            subchapter: "",
            article: "",
            para: "",
            str: ~s/#{part} #{i} #{str}/
        }

      :regulation ->
        %{record | type: article_type, subchapter: value, article: "", para: "", str: part <> str}
    end
  end

  def chapter(_type, str, record) do
    str = String.replace(str, chapter_emoji(), "")
    [_, value] = Regex.run(~r/^Chapter[ ](\d+)/, str)
    %{record | type: "chapter", chapter: value, subchapter: "", article: "", para: "", str: str}
  end

  def sub(str, record) do
    rest =
      case Regex.match?(~r/^#{numbered_para_emoji()}/, str) do
        true ->
          <<_::binary-size(3), rest::binary>> = str
          rest

        false ->
          <<_::binary-size(4), rest::binary>> = str
          rest
      end

    %{record | type: "para", sub: record.sub + 1, str: rest}
  end

  def increment_string(b) when is_binary(b) do
    case b do
      "" -> "1"
      _ -> String.to_integer(b) |> (&(&1 + 1)).() |> Integer.to_string()
    end
  end

  @doc """
  Utility function to time the parser.
  Arose when rm_header was taking 5 seconds!  Faster now :)
  """
  def parse_timer() do
    {:ok, binary} = File.read(Path.absname(Legl.original()))
    {t, binary} = :timer.tc(UK, :rm_header, [binary])
    display_time("rm_header", t)
    {t, _binary} = :timer.tc(UK, :rm_explanatory_note, [binary])
    display_time("rm_explanatory_note", t)
  end

  defp display_time(f, t) do
    IO.puts("#{f} takes #{t} microseconds or #{t / 1_000_000} seconds")
  end
end
