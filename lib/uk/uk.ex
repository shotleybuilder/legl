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
      annex_heading_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      annex_emoji: 0,
      signed_emoji: 0,
      pushpin_emoji: 0,
      amendment_emoji: 0
    ]

  alias UK.Schema, as: Schema

  @parse_options %{type: :regulation, part: :both}

  @doc """
  Parser creates an annotated text file that can be quality checked by a human.
  Options
  Type can be `:act` or `:regulation`, defaults to `:regulation`
  Part can be `:both`, `:law` or `:annex`, defaults to `:both`
  """

  def parse(options \\ []) when is_list(options) do
    %{type: type, part: part} = Enum.into(options, @parse_options)
    parse(part, type)
  end

  def parse(:both, type) do
    File.write(Legl.annotated(), "#{parser(type)}\n#{parse_annex()}")
  end

  def parse(:law, type) do
    File.write(Legl.annotated(), "#{parser(type)}")
  end

  def parse(:annex, _type) do
    File.write(Legl.annotated_annex(), "#{parse_annex()}")
  end

  def parser(:regulation = type) when is_atom(type) do
    {:ok, binary} = File.read(Path.absname(Legl.original()))

    binary
    |> rm_header()
    |> rm_explanatory_note
    |> rm_empties()
    |> join_empty_numbered()
    |> get_article()
    |> get_sub_article()
    |> get_part()
    |> get_signed_section()
    # get_heading() has to come after get_article
    |> get_heading(:regulation)
    |> join()
    |> rm_tabs()
  end

  def parser(:act = type) when is_atom(type) do
    {:ok, binary} = File.read(Path.absname(Legl.original()))

    binary
    |> rm_header()
    |> rm_explanatory_note
    |> rm_empties()
    |> join_empty_numbered()
    |> get_chapter()
    |> get_amendments(:act)
    # |> get_modifications(:act)
    |> get_sub_section(:act)
    # get_section() has to come after get_sub_section
    |> get_A_section(:act)
    |> get_section(:act)
    # get_heading() has to come after get_section
    |> get_heading(:act)
    |> get_part()
    |> get_signed_section()
    |> join()
    |> rm_tabs()
    |> rm_amendment(:act)
  end

  @doc """
  Separate parser for Schedules
  There is no easy way to differentiate schedule articles from the main law
  """
  def parse_annex() do
    {:ok, binary} = File.read(Path.absname(Legl.original_annex()))

    binary
    |> rm_leading_tabs_spaces()
    |> rm_header_annex()
    |> rm_empties()
    |> get_annex()
    |> get_annex_heading()
    |> join()
    |> rm_tabs()
  end

  def rm_leading_tabs_spaces(binary), do: Regex.replace(~r/^[\s\t]+/m, binary, "")

  @doc """
  Remove https://legislation.gov.uk header content
  """
  def rm_header(binary) do
    binary
    |> (&Regex.replace(~r/^[[:space:][:print:]]+PreviousNext\n+/, &1, "")).()
    # just the law w/o the schedules view
    |> (&Regex.replace(~r/^Previous: IntroductionNext: Schedule/m, &1, "")).()
    |> (&Regex.replace(~r/^[[:space:][:print:]]+Back to full view\n+/, &1, "")).()
  end

  def rm_header_annex(binary),
    do:
      Regex.replace(
        ~r/^[[:space:][:print:]]+Previous\: SignatureNext\: Explanatory Note\n+/,
        binary,
        ""
      )

  def rm_explanatory_note(binary),
    do:
      Regex.replace(
        ~r/^Explanatory Note[\s\S]+|EXPLANATORY NOTE[\s\S]+/m,
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

  @doc """

  """
  def get_chapter(binary),
    do: Regex.replace(~r/^Chapter[ ]\d+/m, binary, "#{chapter_emoji()}\\0 ")

  @doc """
  Parse Act section headings & Regulation article headings.
  * Act
  Format
  Heading
  There is an initial captialisaiton and no ending period
  """
  def get_heading(binary, :act),
    do:
      Regex.replace(
        ~r/^[A-Z][^\d\.][^\n]+[^\.](etc\.)?\n#{article_emoji()}(\d+)/m,
        binary,
        "#{heading_emoji()}\\0"
      )

  def get_heading(binary, :regulation),
    do:
      Regex.replace(
        ~r/^[^#{part_emoji()}|#{annex_emoji()}]([^\n]+)[^\.](etc\.)?\n#{article_emoji()}(\d+)/m,
        binary,
        "#{heading_emoji()}\\g{3} \\0"
      )

  @doc """
  Parse sections of Acts.  The equivalent of Regualtion articles.
  Formats:
  1Text
  """
  def get_section(binary, :act),
    do:
      Regex.replace(
        # too restrictive ~r/^(\d+)([^\n]+)([^\.])(etc\.)?(\n#{sub_article_emoji()})/m,
        ~r/^(\[?F\d\d*,?[ ])?(\d{1,3})[ ]?([A-Z|\.])([^\n]+)([^\.])(etc\.)?/m,
        binary,
        "#{article_emoji()}\\g{1}\\g{2} \\g{3}\\g{4}\\g{5}\\g{6}"
      )

  @doc """
  Parse sections of Acts.  The equivalent of Regualtion articles.
  Formats:
  1Text
  """
  def get_A_section(binary, :act),
    do:
      Regex.replace(
        # too restrictive ~r/^(\d+)([^\n]+)([^\.])(etc\.)?(\n#{sub_article_emoji()})/m,
        ~r/^(\[F\d\d?)?[ ]?(\d{1,3}A)[ ]?([A-Z\.])([^\n]+)([^\.])(etc\.)?/m,
        binary,
        "#{article_emoji()}\\g{1} \\g{2} \\g{3}\\g{4}\\g{5}\\g{6}"
      )

  @doc """
  Parse sub-sections of Acts.
  Formats:
  (1)Text
  """
  def get_sub_section(binary, :act),
    do:
      Regex.replace(
        ~r/^(\[?F?\d*\(\d+\))[ ]?([A-Z])/m,
        binary,
        "#{sub_article_emoji()}\\g{1} \\g{2}"
      )

  @doc """
  Parse the articles of Regulations.
  """
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

  @doc """
  Mark-up Schedules
  egs
  SCHEDULE 1.Name

  """
  def get_annex(binary),
    do:
      Regex.replace(
        ~r/^SCHEDULE[ ]\d+[ ]?|^THE SCHEDULE|^SCHEDULE/m,
        binary,
        "#{annex_emoji()}\\0 "
      )

  def get_annex_heading(binary),
    do:
      Regex.replace(
        ~r/^([A-Z][^\n\.]+)\n(#{annex_emoji()}.*)/m,
        binary,
        "\\g{2}#{pushpin_emoji()}\\g{1}"
      )

  @doc """
  PART and Roman Part Number concatenate when copied e.g. PART IINFORMATION

  """
  @spec get_part(String.t()) :: String.t()
  def get_part(binary) do
    part_class_scheme =
      cond do
        Regex.match?(~r/^(PART|Part)[ ]+\d/m, binary) -> "numeric"
        Regex.match?(~r/^PART[ ]+A/m, binary) -> "alphabetic"
        Regex.match?(~r/^PART[ ]+I/m, binary) -> "roman_numeric"
        true -> "no parts"
      end

    case part_class_scheme do
      "no parts" ->
        binary

      "numeric" ->
        Regex.replace(
          ~r/^(PART|Part)[ ](\d+)[ ]?([ A-Z]+)/m,
          binary,
          "#{part_emoji()}\\g{2} \\g{1} \\g{2} \\g{3}"
        )

      "alphabetic" ->
        Regex.replace(
          ~r/^PART[ ]([A-Z])[ ]?([ A-Z]+)/m,
          binary,
          fn _, value, text ->
            index = Legl.conv_alphabetic_classes(value)
            "#{part_emoji()}#{index} PART #{value} #{text}"
          end
        )

      "roman_numeric" ->
        Regex.replace(
          ~r/^PART[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3})([ A-Z]+)/m,
          binary,
          fn _, tens, units, text ->
            numeral = tens <> units

            {remaining_numeral, last_numeral} = String.split_at(numeral, -1)

            # last_numeral = String.last(numeral)
            # remaining_numeral = String.slice(numeral, 0..(String.length(numeral) - 2))

            case Dictionary.match?("#{last_numeral}#{text}") do
              true ->
                value = Legl.conv_roman_numeral(remaining_numeral)
                "#{part_emoji()}#{value} PART #{remaining_numeral} #{last_numeral}#{text}"

              false ->
                value = Legl.conv_roman_numeral(numeral)
                "#{part_emoji()}#{value} PART #{numeral} #{text}"
            end
          end
        )
    end
  end

  @doc """

  """
  def get_signed_section(binary) do
    binary
    |> (&Regex.replace(~r/^Signed by/m, &1, "#{signed_emoji()}\\0")).()
    |> (&Regex.replace(
          ~r/^Sealed with the Official Seal/m,
          &1,
          "#{signed_emoji()}\\0"
        )).()
  end

  @doc """
  Join lines unless they are 'marked-up'
  """
  def join(binary) do
    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{part_emoji()}|#{heading_emoji()}|#{chapter_emoji()}|#{
        sub_chapter_emoji()
      }|#{article_emoji()}|#{sub_article_emoji()}|#{numbered_para_emoji()}|#{annex_emoji()}|#{
        annex_heading_emoji()
      }|#{signed_emoji()}|#{amendment_emoji()})/mu,
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

  def rm_amendment(binary, :act),
    do: Regex.replace(~r/^#{amendment_emoji()}.*(?:\r\n|\n)?/m, binary, "")

  @doc """
  Revised Acts
  """
  def get_amendments(binary, :act),
    do:
      Regex.replace(
        ~r/^Textual[ ]Amendments|Extent[ ]Information|Modifications etc\.[ ]\(not altering text\)/m,
        binary,
        "#{amendment_emoji()}\\0"
      )

  @doc """
  Revised Acts
  """
  def get_modifications(binary, :act),
    do:
      Regex.replace(
        ~r/^Modifications etc\.[ ]\(not altering text\)/m,
        binary,
        "#{amendment_emoji()}\\0"
      )

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
