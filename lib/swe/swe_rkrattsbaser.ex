defmodule SWE.Rkrattsbaser do
  @moduledoc false

  def parser(binary),
    do:
      binary
      |> mm()
      |> rm_new_line()
      |> numbered()
      |> lettered()
      |> dashed_bulleted()
      |> coloned()
      |> backslashed()
      |> paras()
      |> para_numbered()
      |> tabulated()
      |> rm_new_line()
      |> green_heart()
      |> rm_empty_lines()

  def mm(binary), do: Regex.replace(~r/\sm\.m\.[ \t]*(\r\n|\n)/, binary, "\\g{1}")

  def rm_new_line(binary),
    # remove \n in the middle of sentences
    do:
      Regex.replace(
        ~r/([\da-zA-Zäöå§”\.\)\/\-\–,³])[ \t]*(?:\r\n|\n)[ \t]*(?:\d §§ )?([\da-zA-Zäöå”§\(\-])/,
        binary,
        "\\g{1}💚\\g{2}"
      )

  def numbered(binary),
    # join numbered sub-paragraphs -> 1. 2. 3. etc.
    do:
      Regex.replace(
        ~r/([\da-zäöå§\.\),),:📌\-])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)(\d*\.)/,
        binary,
        "\\g{1}📌\\g{2}"
      )

  def lettered(binary),
    # join lettered sub-paragraphs - a) b) x) etc.
    do:
      Regex.replace(
        ~r/([\da-zäöå§\.\\),])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([a-z]+\))/,
        binary,
        "\\g{1}💡\\g{2}"
      )

  def dashed_bulleted(binary),
    # join dashed bulleted sub-paragraphs – – – etc.
    do:
      Regex.replace(
        ~r/([\da-zäöå\.\\),])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([\–\-]+\s)/,
        binary,
        "\\g{1}🔴\\g{2}"
      )

  def coloned(binary),
    # join named sub-paragraphs with colon -> name-x: name-y:
    do:
      Regex.replace(
        ~r/([\da-zäöå\.\\),])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([A-Za-z\-]+\:\s)/,
        binary,
        "\\g{1}💙\\g{2}"
      )

  def backslashed(binary),
    # join paras that begin and end in a backslash - used as a amendment
    do: Regex.replace(~r/(?:\r\n|\n)[ \t]*(?:\r\n|\n)(\/.*\/)/, binary, "⚡\\g{1}")

  def paras(binary),
    # join paras
    do: Regex.replace(~r/[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([^\dA-ZÅÄÖ])/, binary, "⛔\\g{1}")

  def para_numbered(binary),
    # join paras that begin with a number
    do:
      Regex.replace(~r/([\da-zäöå§\.\)-:,])[ \t]*(?:\r\n|\n)[ \t]*(\d)/, binary, "\\g{1}🧡\\g{2}")

  def tabulated(binary),
    # join paras with gap of 5 or more spaces
    do: Regex.replace(~r/[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)(.*\s{5,})/, binary, "🐽️\\g{1}")

  def green_heart(binary),
    # join paras containing a 💚
    do: Regex.replace(~r/(?:\r\n|\n)[ \t]*(?:\r\n|\n)[ \t]*([^\d].*💚.*\.)/, binary, "💦\\g{1}")

  def rm_empty_lines(binary),
    # remove empty lines
    do: Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")

  def clean(binary) do
    #  Cleans the annotated txt file of the annotations
    #  The pin emoji tells an Airtable formula where to insert new lines after the paste
    binary
    |> String.replace("💚", " ")
    |> String.replace("💡", "📌")
    |> String.replace("💙", "📌")
    |> String.replace("⛔", "📌")
    |> String.replace("🧡", "📌")
    |> String.replace("⚡", "📌")
    |> String.replace("🔴", "📌")
    |> String.replace("💦", "📌")
    |> String.replace("🐽️", "📌")
  end

  def schema(binary) do
    schemas =
      String.split(binary, "\n", trim: true)
      |> Enum.reduce(%{types: [], sections: [], section: 0}, fn str, acc ->
        {type, section} =
          cond do
            Regex.match?(~r/^(\d+[ ][a-z]*)[ ]?§[ ]/, str) ->
              {"article", acc.section}

            Regex.match?(~r/^(\d+)\skap\.\s/, str) ->
              {"chapter", 0}

            Regex.match?(~r/^SFS-nummer/, str) ->
              {"title", acc.section}

            Regex.match?(~r/Övergångsbestämmelser/, str) ->
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

  def chapter_numbers(binary) do
    # {:ok, binary} = File.read(Path.absname("lib/swe_new.txt"))
    chapters =
      String.split(binary, "\n", trim: true)
      |> Enum.reduce([], fn str, acc ->
        case Regex.run(~r/^(\d+)\skap\.\s/, str) do
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

  def article_numbers() do
    {:ok, binary} = File.read(Path.absname(Legl.airtable()))
    article_numbers(binary)
  end

  def article_numbers(binary) do
    articles =
      String.split(binary, "\n", trim: true)
      |> Enum.reduce([], fn str, acc ->
        case Regex.run(~r/^(\d+[ ][a-z]*)[ ]?§[ ]/, str) do
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

  def article_type() do
    {:ok, binary} = File.read(Path.absname(Legl.airtable()))
    article_type(binary)
  end

  def article_type(binary) do
    types =
      String.split(binary, "\n", trim: true)
      |> Enum.reduce([], fn str, acc ->
        cond do
          Regex.match?(~r/^(\d+[ ][a-z]*)[ ]?§[ ]/, str) ->
            ["article" | acc]

          Regex.match?(~r/^(\d+)\skap\.\s/, str) ->
            ["chapter" | acc]

          Regex.match?(~r/^SFS-nummer/, str) ->
            ["title" | acc]

          Regex.match?(~r/Övergångsbestämmelser/, str) ->
            ["notes" | acc]

          true ->
            case List.first(acc) do
              "notes" -> ["notes" | acc]
              _ -> ["heading" | acc]
            end
        end
      end)
      |> Enum.reverse()

    Enum.count(types) |> IO.inspect(label: "types")

    Enum.join(types, "\n")
    |> (&File.write(Legl.type(), &1)).()
  end
end
