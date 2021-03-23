defmodule SWE.Pdf do
  @moduledoc false

  def parser(binary) do
    binary
    |> rm_page_numbers()
    |> mm()
    |> trim()
    |> rm_bullet_symbol()
    |> rm_box_symbol()
    |> chapter_heading_1()
    |> chapter_heading_2()
    |> two_line_headings()
    |> heading_b4_heading()
    |> regulation_heading()
    |> regulation_heading_2()
    |> regulation_heading_3()
    |> regulation()
    |> sub_regulation_heading()
    |> sub_regulation()
    |> numbered()
    |> lettered()
    |> dashed_bulleted()
    |> sentence
    |> join_sentence()
    |> SWE.Rkrattsbaser.rm_empty_lines()
    |> bilaga()
    |> regs_bilaga()
  end

  def mm(binary),
    # remove the last period of m.m.
    do: Regex.replace(~r/[ ]m\.m\.$/m, binary, " m,m,")

  def trim(binary), do: Regex.replace(~r/^[ ]/m, binary, "")

  def chapter_heading_1(binary),
    # match a chapter heading
    do: Regex.replace(~r/\.(?:\r\n|\n)(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")

  def chapter_heading_2(binary),
    do:
      Regex.replace(~r/[\d\.](?:\r\n|\n)(^\d+ kap\.[ ]?.*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n\n")

  def chapter(binary),
    # match a chapter heading
    do: Regex.replace(~r/(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")

  def two_line_headings(binary),
    # join headings that span 2 lines
    do: Regex.replace(~r/^(\d+[ ]§\d*[ ]*)(?:\r\n|\n)([ ]?.)/m, binary, "\\g{1} \\g{2}")

  def regulation_heading(binary),
    # match regulation heading
    do:
      Regex.replace(
        ~r/([A-Z]{1}[a-zåäö\s,]+)(?:\r\n|\n)(\d+[ ]§\d?)/,
        binary,
        "\n🧡\\g{1}\n\\g{2}"
      )

  def regulation_heading_2(binary),
    do: Regex.replace(~r/^(Ikraftträdande.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")

  def regulation_heading_3(binary),
    do:
      Regex.replace(
        ~r/^(Övergångsbestämmelser.*)(?:\r\n|\n)([A-Z\d])/um,
        binary,
        "\n🧡\\g{1}\n🔴\\g{2}"
      )

  def regulation(binary),
    # match the start of a regulation
    do: Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🔴\\g{1}")

  def sub_regulation_heading(binary),
    # match sub-regulation heading
    do:
      Regex.replace(
        ~r/([A-Z]{1}[a-zåäö\s,\.]+)(?:\r\n|\n)(\d+[ ][a-z][ ]§\d?)/,
        binary,
        "\n⛔\\g{1}\n\\g{2}"
      )

  def sub_regulation(binary),
    # match a sub-reg
    do: Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ][a-z][ ]§\d?)/m, binary, "\n🐽️\\g{1}")

  def heading_b4_heading(binary),
    # headings before headings
    do:
      Regex.replace(
        ~r/([A-Z].*[^\.])(?:\r\n|\n)([A-Z].*[^\.])(?:\r\n|\n)(\d+[ ]§)/,
        binary,
        "💦\\g{1}\n\\g{2}\n\\g{3}"
      )

  def numbered(binary),
    # match numbered lists
    do: Regex.replace(~r/(^\d+\.[ ].)/m, binary, "\n\\g{1}")

  def lettered(binary),
    # match lettered lists
    do: Regex.replace(~r/(^[ ]?[a-z]+\)[ ].)/m, binary, "\n\\g{1}")

  def bulleted(binary),
    # dashed bulleted lists
    do: Regex.replace(~r/(^\–[ ])/m, binary, "\n\\g{1}")

  def dashed_bulleted(binary),
    # dashed & bulleted lists
    do: Regex.replace(~r/(^[\•\–][ ])/m, binary, "\n\\g{1}")

  def sentence(binary),
    # sentences
    do: Regex.replace(~r/(\.[\r|\r\n])([A-Z])/m, binary, "\\g{1}\n\\g{2}")

  def join_sentence(binary),
    # join sentances
    do: Regex.replace(~r/([^\.\n])(?:\n|\r\n)([^A-Z💙🧡⛔🔴💡🐽️])/m, binary, "\\g{1} \\g{2}")

  def bilaga(binary),
    # flag bilaga
    do: Regex.replace(~r/(^Bilaga)/m, binary, "💡\\g{1}")

  def regs_bilaga(binary),
    # join the regs and bilaga
    do: Regex.replace(~r/[ \t]*(?:\r\n|\n)([^💙🧡⛔🔴💡🐽️]|\–|”)/m, binary, "📌\\g{1}")

  def rm_page_numbers(binary),
    # remove page numbers
    do: Regex.replace(~r/^\d+(?:\r\n|\n)/m, binary, "")

  def rm_bullet_symbol(binary),
    # replace weird bullet symbol 
    do: Regex.replace(~r/^\/m, binary, "-")

  def rm_box_symbol(binary),
    # replace weird box symbol 
    do: Regex.replace(~r/^[ ]/m, binary, "")

  def clean(binary) do
    binary
    |> String.replace("💚", "")
    |> String.replace("💡", "")
    |> String.replace("💙", "")
    |> String.replace("⛔", "")
    |> String.replace("🧡", "")
    |> String.replace("⚡", "")
    |> String.replace("🔴", "")
    |> String.replace("💦", "")
    |> String.replace("🐽️", "")
  end

  def chapter_numbers(pdf) do
    {:ok, binary} = File.read(Path.absname(Legl.airtable()))
    chapter_numbers(binary, pdf)
  end

  def chapter_numbers(binary, pdf) do
    regex =
      case pdf do
        x when x in ["elsak", "msb"] -> ~r/^(\d+) kap\.[ ]?.*/
        _ -> ~r/^Kap\.\s(\d+)/
      end

    chapters =
      String.split(binary, "\n", trim: true)
      |> Enum.reduce([], fn str, acc ->
        case Regex.run(regex, str) do
          [_match, capture] ->
            [capture | acc]

          nil ->
            case acc do
              [] -> ["" | acc]
              _ -> [hd(acc) | acc]
            end
        end
      end)
      |> Enum.reverse()

    Enum.count(chapters) |> IO.inspect(label: "chapter")

    Enum.join(chapters, "\n")
    |> (&File.write(Legl.chapter(), &1)).()
  end

  def schemas() do
    {:ok, binary} = File.read(Path.absname(Legl.annotated()))
    schema(binary)
  end

  def schema(binary) do
    # First line is always the title
    [_head | tail] = String.split(binary, "\n", trim: true)

    schemas =
      tail
      |> Enum.reduce(%{types: ["title"], sections: [""], section: 0}, fn str, acc ->
        {type, section} =
          cond do
            Regex.match?(~r/^(\d+[ ][a-z]*)[ ]?§[\d| ]/, str) ->
              {"article", acc.section}

            Regex.match?(~r/^Kap\.\s(\d+)/, str) ->
              {"chapter", 0}

            Regex.match?(~r/^(\d+) kap\.[ ]?.*/, str) ->
              {"chapter", 0}

            # Regex.match?(~r/^Boverkets|BOVERKETS/, str) -> {"title", acc.section}
            # Regex.match?(~r/^Elsäkerhetsverkets/, str) -> {"title", acc.section}
            # Regex.match?(~r/^[A-ZÅÄÖ][A-ZÅÄÖ]/u, str) -> {"title", acc.section}
            # Regex.match?(~r/^Arbetsmiljöverkets/, str) -> {"title", acc.section}
            Regex.match?(~r/Bilaga/, str) ->
              {"notes", acc.section + 1}

            true ->
              case List.first(acc.types) do
                "notes" -> {"notes", 0}
                _ -> {"heading", acc.section + 1}
              end
          end

        str_section =
          case section do
            0 -> ""
            _ -> Integer.to_string(section)
          end

        %{
          acc
          | :types => [type | acc.types],
            :sections => [str_section | acc.sections],
            :section => section
        }
      end)

    Enum.count(schemas.types) |> IO.inspect(label: "types")

    schemas.types
    |> Enum.reverse()
    |> Enum.join("\n")
    |> (&File.write(Legl.type(), &1)).()

    schemas.sections
    |> Enum.reverse()
    |> Enum.join("\n")
    |> (&File.write(Legl.section(), &1)).()
  end

  def article_numbers() do
    {:ok, binary} = File.read(Path.absname(Legl.airtable()))
    article_numbers(binary)
  end

  def article_numbers(binary) do
    #
    articles =
      String.split(binary, "\n", trim: true)
      |> Enum.reduce([], fn str, acc ->
        case Regex.run(~r/^(\d+[ ][a-z]*)[ ]?§[\d| ]/, str) do
          [_match, capture] ->
            [String.replace(capture, " ", "") | acc]

          nil ->
            ["" | acc]
        end
      end)
      |> Enum.reverse()

    Enum.count(articles) |> IO.inspect(label: "articles")

    Enum.join(articles, "\n")
    |> (&File.write(Legl.article(), &1)).()
  end
end
