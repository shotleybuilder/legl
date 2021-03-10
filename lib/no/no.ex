defmodule Norway do
    @moduledoc """
    Parsing .html copied from https://lovdata.no/dokument/SF/forskrift/
    Norwegian alphabet:
    Æ 	æ
    Ø 	ø
    Å 	å
    """
    import Legl, only:
      [
        chapter_emoji: 0,
        sub_chapter_emoji: 0,
        article_emoji: 0,
        sub_article_emoji: 0,
        numbered_para_emoji: 0,
        amendment_emoji: 0,
        annex_emoji: 0,
        pushpin_emoji: 0,
        no_join_emoji: 0
      ]

    @doc """
    The parser which creates the annotated txt file
    Takes an optional boolean to indicate if the text to be parsed is in English
    """
    def parse(english? \\ false) do
        {:ok, binary} = File.read(Path.absname(Legl.original))
        {binary, english?}
        |> get_amendment()

        |> language_agnostic()

        |> get_chapter()
        |> get_sub_chapter()
        |> get_article()
        |> get_sub_article()
        |> get_numbered_paragraph()
        |> get_annex()
        |> rm_empty()
        #|> join_special()
        |> join()
        |> rm_tabs()
        |> rm_footer()
        |> (&(File.write(Legl.annotated, &1))).()
    end

    def language_agnostic({binary, _}), do: binary

    @doc """
    Match a chapter heading
    Chapters have these formats:
    Kapittel 1. Name
    Kapittel 1A. Name
    Kapittel 2 A. Name
    Kap. 1. Name
    Kap. I. Name
    Kapittel I – Name
    Chapter
    """
    def get_chapter(binary), do:
      Regex.replace(
        ~r/^(((?:Kapi?t?t?e?l?\.?)|(?:Chapter\.?))[ ]*(\d+)?(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})[ \–]?[A-Z]?\.?)([^\n\.]*)$/m,
        binary,
        "#{chapter_emoji()}\\g{1}\\g{6}"
      )
    @doc """
    Match a sub-chapter with Roman numbering
    Sub-chapters are unusual and have this format:
    I Name
    """
    def get_sub_chapter(binary), do: Regex.replace(
        ~r/^((XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.[ ]+[A-ZÅØ].*)/m,
        binary,
        "#{sub_chapter_emoji()}\\g{1}"
      )
    @doc """
    Match Article
    Articles have these formats
    § 1. Name
    § 1a-1.Name
    § 2-1. Name
    § 2 A-1. Name
    Section 2-3. Name
    Section 2 A-1. Name
    """
    def get_article(binary), do: Regex.replace(
          ~r/^(§[ ]+|(?:Section)[ ]+)(\d*[ ]?[A-Za-z]?\-)?(\d+\.)[ ]*([\(A-ZÅØ].*)/m,
          binary,
          "#{article_emoji()}\\g{1}\\g{2}\\g{3} \\g{4}"
        )
    @doc """
    Match Sub-Article
    Sub-articles have these formats
    § 1 a.Name
    § 1-1a.Name
    """
    def get_sub_article(binary), do: Regex.replace(
        ~r/^(§[ ]+)(\d*\-)?(\d+)[ ]?([a-z]+)\.[ ]?/m,
        binary,
        "#{sub_article_emoji()}\\g{1}\\g{2}\\g{3} \\g{4}\. "
      )
    @doc """
    Numbered paragraph
    """
    def get_numbered_paragraph(binary), do: Regex.replace(
        ~r/^(\(\d+\))/m,
        binary,
        "#{numbered_para_emoji()}\\g{1}"
      )
    @doc """
    Match an Amendment
    """
    def get_amendment({binary, false}), do:
      {
        Regex.replace(
          ~r/(^\d+)[ \t]+([Jf.|Kapittel|Kapitlene|Endret|Tilføyd|Vedlegg|Opphevet|Hele|Drette|Overskrift endret|Henvisningen].*)/m,
          binary,
          "\n#{amendment_emoji()}\\g{1} \\g{2}\n\n"
        ),
        false
      }
    def get_amendment({binary, true}), do:
      {
        Regex.replace(
          ~r/(^\d+)[ \t]+([Cf. | Chapter | Chapters | Modified | Added | Attachments | Repealed | Entire | Edit | Headline Modified | Reference].*)/m,
          binary,
          "\n️#{amendment_emoji()}\\g{1} \\g{2}\n\n"
        ),
        false
      }
    @doc """
    Match an Annex
    Annexes have these formats
    Vedlegg 1. Name
    Vedlegg X. Name
    Vedlegg. 2 Name
    Vedlegg 1: Name
    """
    def get_annex(binary), do:
      Regex.replace(
        ~r/^(((?:Vedlegg)|(?:Annex))\.?[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3}|\d+):?\.?[ ]+[A-ZÅØ].*)/m,
        binary,
        "#{annex_emoji()}\\g{1}"
      )
    @doc """
    Remove empty lines
    """
    def rm_empty(binary), do: Regex.replace(
        ~r/(?:\r\n|\n)+[ \t]*(?:\r\n|\n)+/m,
        binary,
        "\n"
    )
    @doc """
    Join lines
    """
    def join(binary) do
      Regex.replace(
        ~r/(?:\r\n|\n)(?!#{chapter_emoji()}|#{sub_chapter_emoji()}|#{article_emoji()}|#{sub_article_emoji()}|#{numbered_para_emoji()}|#{annex_emoji()})/mu,
        binary,
        "#{pushpin_emoji()}"
      )
    end
    def join_special(binary), do: Regex.replace(
        ~r/(?:\r\n|\n)(?=∑)/mu,
        binary,
        "\\g{1}"
    )
    @doc """
    Removes the footer
    """
    def rm_footer(binary), do: Regex.replace(
      ~r/(?:\r\n|\n)^Brukerveiledning.*\n/m,
      binary,
      ""
    )
    @doc """
    Remove tabs because this conflicts with Airtables use of tabs to separate into fields
    """
    def rm_tabs(binary), do: Regex.replace(
        ~r/\t/m,
        binary,
        "     "
    )

    @doc """
    Build a text file suitable for pasting into Airtable
    Chapter option: takes an integer or string chapter number, eg Norway.schemas(1), Norway.schemas("1A")
    Text Only option: only returns the text, eg Norway.schemas(nil, true), Norway.schemas("1A", true)
    English? option: for processing English texts eg Norway.schemas(nil, true, true)
    Numbering
    Chapter SubChapter  Article(sub)    Para
    1_1_1   1_1_1_1  1_1_2   1_1_2_1    1_1_2_2
    """
    def schemas(chapter \\ nil, text_only? \\ false, english? \\ false) do
        {:ok, binary} = File.read(Path.absname(Legl.annotated))
        schemas(binary, chapter, text_only?, english?)
    end
    def schemas(binary, c, t_o, e) when is_integer(c), do: schemas(binary, Integer.to_string(c), t_o, e)
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
                        Regex.match?( ~r/^#{sub_article_emoji()}/, str) -> subarticle(str, acc.record)
                        Regex.match?(~r/^#{annex_emoji()}/, str) -> annex(str, acc.record)
                        true -> para(str, acc.record)
                    end
                case c do
                    nil -> %{acc | txts: [conv_map_to_record_string(record) | acc.txts], record: record}
                    _ ->
                        case record.chapter == c do
                            true ->
                                %{acc | txts: [conv_map_to_record_string(record) | acc.txts], record: record}
                            _ -> %{acc | record: record}
                        end
                end

            end)

        Enum.count(schemas.txts) |> IO.inspect(label: "txts")

        # just want the text and not the classes?
        txts =
          case t_o do
            true ->
              Enum.map(schemas.txts, &txt_only/1)
            false -> schemas.txts
          end

        Enum.reverse(txts)
        |> Enum.join("\n")
        |> String.replace("💥️", "")
        |> (&(File.write(Legl.txts, &1))).()
    end
    defp txt_only(str) do
      case Regex.run(~r/^\w+\t[\w ]*\t[\w ]*\t[\w ]*\t[\w ]*\t(.*)[ ]*$/, str) do
        [_, capture] -> capture
        nil -> IO.inspect(str); ""
      end
    end

    defp conv_map_to_record_string(
        %{type: type, chapter: chapter, subchapter: subchapter, article: article, para: para, str: str}) do
            para = if para == 0, do: "", else: para
            ~s(#{type}\t#{chapter}\t#{subchapter}\t#{article}\t#{para}\t#{str})
    end

    # Regex.run(~r/^#{Legl.chapter_emoji()}Kapi?t?t?e?l?\.?[ ]*(\d+[ ]?[A-Z]?)?(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\./, "🇳🇴Kapittel 1. Innledende bestemmelser")
    defp chapter(str, record, e) do
      regex = ~r/^#{chapter_emoji()}((?:Kapi?t?t?e?l?\.?)|(?:Chapter\.?))[ ]*(\d+)?(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})/
      capture =
        case Regex.run(regex, str) do
          [_, _, capture, "", ""] -> capture
          [_, _, _, _, capture] -> conv_roman_numeral(capture)
        end
        str = String.replace(str, chapter_emoji(), "")
        %{record | type: "chapter", chapter: capture, subchapter: "", article: "", para: 0, str: str}
    end

    defp subchapter(str, record) do
      regex = ~r/^#{sub_chapter_emoji()}(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.[ ]/
      [_, _, capture] = Regex.run(regex, str)
      str = String.replace(str, sub_chapter_emoji(), "")
      %{record | type: "sub-chapter", subchapter: conv_roman_numeral(capture), article: "", para: 0, str: str}
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
          true -> <<_::binary-size(3), rest::binary>> = str; rest
          false -> <<_::binary-size(4), rest::binary>> = str; rest
        end

      %{record | type: "para", para: record.para + 1, str: rest}
    end

    defp annex(str, record) do
      regex = ~r/^#{annex_emoji()}(((?:Vedlegg)|(?:Annex))\.?[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3}|\d+):?\.?[ ]+[A-ZÅØ].*)/
      [_, str, _, _, capture] = Regex.run(regex, str)
      %{record | type: "annex", para: conv_roman_numeral(capture), str: str}
    end

    @roman_numerals %{
        "I" => 1,
        "II" => 2,
        "III" => 3,
        "IV" => 4,
        "V" => 5,
        "VI" => 6,
        "VII" => 7,
        "VIII" => 8,
        "IX" => 9,
        "X" => 10
    }

    defp conv_roman_numeral(numeral) do
        case Map.get(@roman_numerals, numeral) do
            nil -> numeral
            x -> x
        end
    end
end
