defmodule UK do
  @moduledoc """
  Parsing .html copied form the plain view at https://legislation.gov.uk
  """
  import Legl,
    only: [
      part_emoji: 0,
      chapter_emoji: 0,
      sub_chapter_emoji: 0,
      heading_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      annex_emoji: 0,
      pushpin_emoji: 0
    ]

  @doc """
  Parser creates an annotated text file that can be quality checked by a human
  """
  def parse() do
    {:ok, binary} = File.read(Path.absname(Legl.original()))

    binary
    |> rm_header()
    |> rm_explanatory_note
    |> rm_empties()
    |> join_empty_numbered()
    |> get_article()
    # has to come after get_article
    |> get_heading()
    |> get_sub_article()
    |> get_schedule()
    |> get_part()
    |> join()
    |> rm_tabs()
    |> (&File.write(Legl.annotated(), &1)).()
  end

  @doc """
  Remove https://legislation.gov.uk header content
  """
  def rm_header(binary),
    do:
      Regex.replace(
        ~r/[\s\S]+PreviousNext(?:\r\n|\n)*/m,
        binary,
        ""
      )

  def rm_explanatory_note(binary),
    do:
      Regex.replace(
        ~r/^EXPLANATORY NOTE[\s\S]+/m,
        binary,
        ""
      )

  def rm_empties(binary),
    do:
      Regex.replace(
        ~r/(?:\r\n|\n)+[ \t]*(?:\r\n|\n)+/m,
        binary,
        "\n"
      )

  def join_empty_numbered(binary),
    do:
      Regex.replace(
        ~r/^(\(([a-z]+|[ivmcldx]+)\)|\d+\.?)(?:\r\n|\n)/m,
        binary,
        "\\g{1} "
      )

  def get_article(binary),
    do:
      Regex.replace(
        ~r/^(\d+\.[ ]+)|(\d+\.(#{<<226, 128, 148>>}|\-))/m,
        binary,
        "#{article_emoji()}\\0"
      )

  def get_sub_article(binary),
    do:
      Regex.replace(
        ~r/^\(\d+\)[ ][A-Z]/m,
        binary,
        "#{sub_article_emoji()}\\0"
      )

  def get_heading(binary),
    do:
      Regex.replace(
        ~r/^([A-Z][^\.]+)(?:\r\n|\n)#{article_emoji()}(\d+)/m,
        binary,
        "#{heading_emoji()}\\g{2} \\g{1}\n#{article_emoji()}\\g{2}"
      )

  @doc """
  Mark-up Schedules
  egs
  SCHEDULE 1.Name

  """
  def get_schedule(binary),
    do:
      Regex.replace(
        ~r/^(SCHEDULE[ ]\d+)[ ]?/m,
        binary,
        "#{annex_emoji()}\\g{1} "
      )

  @doc """

  """
  def get_part(binary),
    do:
      Regex.replace(
        ~r/^(PART[ ]\d+)[ ]?/m,
        binary,
        "#{part_emoji()}\\g{1} "
      )

  @doc """
  Join lines unless they are 'marked-up'
  """
  def join(binary) do
    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{part_emoji()}|#{heading_emoji()}|#{chapter_emoji()}|#{
        sub_chapter_emoji()
      }|#{article_emoji()}|#{sub_article_emoji()}|#{numbered_para_emoji()}|#{annex_emoji()})/mu,
      binary,
      "#{pushpin_emoji()}"
    )
  end

  @doc """
  Remove tabs because this conflicts with Airtables use of tabs to separate into fields
  """
  def rm_tabs(binary),
    do:
      Regex.replace(
        ~r/\t/m,
        binary,
        "     "
      )

  def schemas(fields \\ []) do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))
    schemas(binary, fields)
  end

  def schemas(binary, fields) do
    record = %{
      flow: "",
      type: "",
      # c also used for schedules with the "s" prefix
      chapter: "",
      # sc also used for schedule part
      subchapter: "",
      article: "",
      para: "",
      sub: 0,
      str: ""
    }

    # First line is always the title
    [head | tail] = String.split(binary, "\n", trim: true)
    txts = [%{record | type: "title", str: head}]

    # txts = [~s(\ttitle\t\t\t\t\t\t#{head})]

    schemas =
      tail
      |> Enum.reduce(%{txts: txts, record: record}, fn str, acc ->
        record =
          cond do
            Regex.match?(~r/^#{article_emoji()}/, str) -> article(str, acc.record)
            Regex.match?(~r/^#{sub_article_emoji()}/, str) -> sub_article(str, acc.record)
            Regex.match?(~r/^#{heading_emoji()}/, str) -> heading(str, acc.record)
            Regex.match?(~r/^#{annex_emoji()}/, str) -> schedule(str, acc.record)
            Regex.match?(~r/^#{part_emoji()}/, str) -> part(str, acc.record)
            true -> sub(str, acc.record)
          end

        %{acc | txts: [record | acc.txts], record: record}
      end)

    Enum.count(schemas.txts) |> IO.inspect(label: "txts")

    limit_fields(schemas.txts, fields)
    |> Enum.map(&conv_map_to_record_string/1)
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
    |> Enum.reverse()
    |> IO.inspect()
  end

  defp limit_fields(records, _fields), do: records

  defp conv_map_to_record_string(%{
         flow: flow,
         type: type,
         chapter: chapter,
         subchapter: subchapter,
         article: article,
         para: para,
         sub: sub,
         str: str
       }) do
    sub = if sub == 0, do: "", else: sub
    ~s(#{flow}\t#{type}\t#{chapter}\t#{subchapter}\t#{article}\t#{para}\t#{sub}\t#{str})
  end

  @doc """
  Build Airtable record for an article_emoji
  Articles w/o sub-articles have a ref of " "
  """
  def article(str, record) do
    str = String.replace(str, article_emoji(), "")

    {value, type} =
      case Regex.run(~r/^\d+\.(#{<<226, 128, 148>>}|\-)\((\d+)\)/, str) do
        nil ->
          case record.flow do
            "post" ->
              [_, value] = Regex.run(~r/^(\d+)\./, str)
              {value, "schedule, article"}

            _ ->
              {" ", "article"}
          end

        [_, _, capture] ->
          {capture, "article, sub-article"}
      end

    %{record | type: type, para: value, str: str}
  end

  def sub_article(str, record) do
    str = String.replace(str, sub_article_emoji(), "")
    [_, value] = Regex.run(~r/^\((\d+)\)/, str)
    %{record | type: "sub-article", para: value, str: str}
  end

  def heading(str, record) do
    str = String.replace(str, heading_emoji(), "")
    [_, value, str] = Regex.run(~r/^(\d+)[ ](.*)/, str)

    type =
      case record.flow do
        "post" -> "schedule, heading"
        _ -> "article, heading"
      end

    %{record | type: type, article: value, para: "", sub: 0, str: str}
  end

  def schedule(str, record) do
    str = String.replace(str, annex_emoji(), "")
    [_, value] = Regex.run(~r/^SCHEDULE[ ](\d+)/, str)

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

  def part(str, record) do
    str = String.replace(str, part_emoji(), "")
    [_, value] = Regex.run(~r/^PART[ ](\d+)/, str)

    type =
      case record.flow do
        "post" -> "schedule, part"
        _ -> "part"
      end

    %{record | type: type, subchapter: value, article: "", para: "", str: str}
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
end
