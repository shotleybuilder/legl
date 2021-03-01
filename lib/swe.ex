defmodule Sweden do
  # script to process html from the Swedish legal database
  # and provide a text file that can be pasted into Airtable

  # swe.txt file is used to store the content copied from http://rkrattsbaser.gov.se/
  # swe_new.txt is for pasting into Airtable

def swe do
  txt = ~s{Förordningen är meddelad med stöd av

– 9 kap. 6 § miljöbalken i fråga om 1 kap. 3, 4, 10 och 11 §§
och 2–32 kap.,

– 9 kap. 8 § miljöbalken i fråga om 1 kap. 6 §, och

– 8 kap. 7 § regeringsformen i fråga om övriga bestämmelser.
Förordning (2016:1188).}

  txt
  #|> _m_m()
  |> rm_new_line()
  #|> numbered()
  #|> lettered()
  |> dashed_bulleted()
  #|> coloned()
  #|> backslashed()
  #|> paras()
  #|> para_numbered()
  #|> rm_new_line()
  #|> green_heart()
  #|> rm_empty_lines()
  |> (&(File.write("lib/swe_snippet.txt", &1))).()

end

def swe_show do
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
  |> rm_new_line()
  |> green_heart()
  |> rm_empty_lines()
  |> (&(File.write("lib/swe_test.txt", &1))).()
end

def swe_real do

  swe_show()

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
  Regex.replace(~r/([\da-zA-Zäöå§”\.\)\/\-\–,³])[ \t]*(?:\r\n|\n)[ \t]*(?:\d §§ )?([a-zA-Zäöå”§\(\-])/, binary, "\\g{1}💚\\g{2}")

def numbered(binary), do:
  # join numbered sub-paragraphs -> 1. 2. 3. etc.
  Regex.replace(~r/([\da-zäöå§\.\),),:])[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)(\d*\.)/, binary, "\\g{1}📌\\g{2}")

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
  Regex.replace(~r/[ \t]*(?:\r\n|\n)[ \t]*(?:\r\n|\n)([^\dA-Z])/, binary, "⛔\\g{1}")

def para_numbered(binary), do:
   # join paras that begin with a number
  Regex.replace(~r/([\da-zäöå§\.\)-:,])[ \t]*(?:\r\n|\n)[ \t]*(\d)/, binary, "\\g{1}🧡\\g{2}")

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
  |> (&(File.write("lib/swe.chapter_numbers", &1))).()
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
  |> (&(File.write("lib/swe.article_numbers", &1))).()
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
  |> (&(File.write("lib/swe.article_type", &1))).()
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
  |> (&(File.write("lib/swe.article_type", &1))).()

  schemas.sections
  |> Enum.reverse()
  |> Enum.join("\n")
  |> (&(File.write("lib/swe.sections", &1))).()
end

end
