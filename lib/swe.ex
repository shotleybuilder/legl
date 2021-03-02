defmodule Sweden do
  # script to process html from the Swedish legal database
  # and provide a text file that can be pasted into Airtable

  # swe.txt file is used to store the content copied from http://rkrattsbaser.gov.se/
  # swe_new.txt is for pasting into Airtable

def swe_snippet do
txt = ~s{5 § En särskild avgift skall betalas för motordrivet fordon och
båt, vars bränsletank innehåller oljeprodukter i strid mot 2
kap. 9 §.

Avgiften uppgår för personbil, lätt lastbil och lätt buss samt
båt till 10 000 kronor. Avgiften beräknas för tunga lastbilar,
tunga bussar, traktorer och tunga terrängvagnar som är
registrerade i vägtrafikregistret på följande sätt.

Skattevikt, kilogram            Avgift, kronor

0- 3 500                        10 000

3 501-10 000                    20 000

10 001-15 000                   30 000

15 001-20 000                   40 000

20 001-                         50 000

Med skattevikt avses den vikt efter vilken fordonsskatt
beräknas enligt vägtrafikskattelagen (2006:227). Avgiften för
annat motordrivet fordon än som avses i andra stycket uppgår
till 10 000 kronor. Avgiften tas ut för varje tillfälle som
bränsletank påträffas med oljeprodukter i strid mot 2 kap. 9 §.

Har avgift påförts någon och skall sådan avgift påföras honom
för ytterligare tillfälle inom ett år från det tidigare
tillfället, tas avgiften ut med en och en halv gånger det
belopp som följer av andra eller tredje stycket.
Lag (2007:779).}

  txt
  |> _m_m()
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
  |> (&(File.write("lib/swe_snippet.txt", &1))).()

end

def swe_test do
  {:ok, binary} = File.read(Path.absname("lib/swe.txt"))
  binary
  |> _m_m()
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
  |> (&(File.write("lib/swe_test.txt", &1))).()
end

def swe_real do

  swe_test()

  {:ok, binary} = File.read(Path.absname("lib/swe_test.txt"))

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
  |> (&(File.write("lib/swe_new.txt", &1))).()

  chapter_numbers(binary)
  article_numbers(binary)
  schema(binary)

end

def schemas() do
  {:ok, binary} = File.read(Path.absname("lib/swe_new.txt"))
  chapter_numbers(binary)
  article_numbers(binary)
  schema(binary)
end

def _m_m(binary), do:
  Regex.replace(~r/\sm\.m\.[ \t]*(\r\n|\n)/, binary, "\\g{1}")

def rm_new_line(binary), do:
  # remove \n in the middle of sentences
  Regex.replace(~r/([\da-zA-Zäöå§”\.\)\/\-\–,³])[ \t]*(?:\r\n|\n)[ \t]*(?:\d §§ )?([\da-zA-Zäöå”§\(\-])/, binary, "\\g{1}💚\\g{2}")

def numbered(binary), do:
  # join numbered sub-paragraphs -> 1. 2. 3. etc.
  Regex.replace(~r/([\da-zäöå§\.\),),:📌\-])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)(\d*\.)/, binary, "\\g{1}📌\\g{2}")

def lettered(binary), do:
  # join lettered sub-paragraphs - a) b) x) etc.
  Regex.replace(~r/([\da-zäöå§\.\\),])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([a-z]+\))/, binary, "\\g{1}💡\\g{2}")

def dashed_bulleted(binary), do:
  # join dashed bulleted sub-paragraphs – – – etc.
  Regex.replace(~r/([\da-zäöå\.\\),])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([\–\-]+\s)/, binary, "\\g{1}🔴\\g{2}")

def coloned(binary), do:
  # join named sub-paragraphs with colon -> name-x: name-y:
   Regex.replace(~r/([\da-zäöå\.\\),])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([A-Za-z\-]+\:\s)/, binary, "\\g{1}💙\\g{2}")

def backslashed(binary), do:
  # join paras that begin and end in a backslash - used as a amendment
  Regex.replace(~r/(?:\r\n|\n)[ \t]*(?:\r\n|\n)(\/.*\/)/, binary, "⚡\\g{1}")

def paras(binary), do:
  # join paras
  Regex.replace(~r/[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([^\dA-ZÅÄÖ])/, binary, "⛔\\g{1}")

def para_numbered(binary), do:
   # join paras that begin with a number
  Regex.replace(~r/([\da-zäöå§\.\)-:,])[ \t]*(?:\r\n|\n)[ \t]*(\d)/, binary, "\\g{1}🧡\\g{2}")

def tabulated(binary), do:
  # join paras with gap of 5 or more spaces
  Regex.replace(~r/[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)(.*\s{5,})/, binary, "🐽️\\g{1}")

def green_heart(binary), do:
   # join paras containing a 💚
  Regex.replace(~r/(?:\r\n|\n)[ \t]*(?:\r\n|\n)[ \t]*([^\d].*💚.*\.)/, binary, "💦\\g{1}")

def rm_empty_lines(binary), do:
  # remove empty lines
  Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")


def chapter_numbers(binary) do
  #{:ok, binary} = File.read(Path.absname("lib/swe_new.txt"))
  chapters =
    String.split(binary, "\n", trim: true)
    |> Enum.reduce([], fn str, acc ->
      case Regex.run(~r/^(\d+)\skap\.\s/, str) do
        [_match, capture] -> [capture | acc]
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
  |> (&(File.write("lib/swe.chapter_numbers.txt", &1))).()
end

def article_numbers(binary) do
  #{:ok, binary} = File.read(Path.absname("lib/swe_new.txt"))
  articles =
    String.split(binary, "\n", trim: true)
    |> Enum.reduce([], fn str, acc ->
      case Regex.run(~r/^(\d+[ ][a-z]*)[ ]?§[ ]/, str) do
        [_match, capture] ->
          [String.replace(capture, " ", "") | acc]
        nil -> ["" | acc]
      end
    end)
    |> Enum.reverse()

  Enum.count(articles) |> IO.inspect(label: "articles")

  Enum.join(articles, "\n")
  |> (&(File.write("lib/swe.article_numbers.txt", &1))).()
end

def article_type(binary) do
  #{:ok, binary} = File.read(Path.absname("lib/swe_new.txt"))
  types =
    String.split(binary, "\n", trim: true)
    |> Enum.reduce([], fn str, acc ->
      cond do
        Regex.match?(~r/^(\d+[ ][a-z]*)[ ]?§[ ]/, str) -> ["article" | acc]
        Regex.match?(~r/^(\d+)\skap\.\s/, str) -> ["chapter" | acc]
        Regex.match?(~r/^SFS-nummer/, str) -> ["title" | acc]
        Regex.match?(~r/Övergångsbestämmelser/, str) -> ["notes" | acc]
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
  |> (&(File.write("lib/swe.article_type.txt", &1))).()
end

def schema(binary) do
  #{:ok, binary} = File.read(Path.absname("lib/swe_new.txt"))
  schemas =
    String.split(binary, "\n", trim: true)
    |> Enum.reduce(%{types: [], sections: [], section: 0}, fn str, acc ->
      {type, section} =
        cond do
          Regex.match?(~r/^(\d+[ ][a-z]*)[ ]?§[ ]/, str) -> {"article", acc.section}
          Regex.match?(~r/^(\d+)\skap\.\s/, str) -> {"chapter", 0}
          Regex.match?(~r/^SFS-nummer/, str) -> {"title", acc.section}
          Regex.match?(~r/Övergångsbestämmelser/, str) -> {"notes", acc.section+1}
          true ->
            case List.first(acc.types) do
              "notes" ->  {"notes", 0}
              _ -> {"heading", acc.section+1}
            end
        end
      str_section =
        case section do
          0 -> ""
          _ -> Integer.to_string(section)
        end
      %{acc | :types => [type | acc.types], :sections => [str_section | acc.sections], :section => section }
    end)

  Enum.count(schemas.types) |> IO.inspect(label: "types")

  schemas.types
  |> Enum.reverse()
  |> Enum.join("\n")
  |> (&(File.write("lib/swe.article_type.txt", &1))).()

  schemas.sections
  |> Enum.reverse()
  |> Enum.join("\n")
  |> (&(File.write("lib/swe.section_numbers.txt", &1))).()
end

end
