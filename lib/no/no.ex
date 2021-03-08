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
        pushpin_emoji: 0
      ]

    @doc """
    The parser which creates the annotated txt file
    """
    def parse do
        {:ok, binary} = File.read(Path.absname(Legl.original))
        binary
        |> get_chapter()
        |> get_sub_chapter()
        |> get_article()
        |> get_sub_article()
        |> get_amendment()
        |> get_annex()
        |> get_numbered_paragraph()
        |> rm_empty()
        |> join_special()
        |> join()
        |> join_amends()
        |> rm_tabs()
        |> rm_footer()
        |> (&(File.write(Legl.annotated, &1))).()
    end

    @doc """
    Match a chapter heading
    Chapters have these formats:
    Kapittel 1.
    Kapittel 1A.
    Kap. 1.
    """
    def get_chapter(binary), do: Regex.replace(
        ~r/(^Kapi?t?t?e?l?\.?[ ]*\d+[A-Z]?\.)([ ]*.*)(?:\r\n|\n)/m,
        binary,
        "#{chapter_emoji()}\\g{1} \\g{2}\n\n"
    )
    @doc """
    Match a sub-chapter with Roman numbering -> I Name
    """
    def get_sub_chapter(binary), do: Regex.replace(
        ~r/\.(?:\r\n|\n)(^(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.[ ]+[A-ZÅØ].*)/m,
        binary,
        "\.\n\n#{sub_chapter_emoji()}\\g{1}\n\n"
    )
    @doc """
    Match Article
    Articles have these formats
    § 1. Name
    § 1a-1.Name
    § 2-1. Name
    § 2 A-1. Name
    """
    def get_article(binary), do: Regex.replace(
        ~r/^(§[ ]+\d+[a-z]?\-?[ ]?[A-Z]?\-?\d*\.)[ ]*([\(A-ZÅØ].*)/m,
        binary,
        "#{article_emoji()}\\g{1} \\g{2}\n\n"
    )
    @doc """
    Match Sub-Article -> § 1-1a.Name
    """
    def get_sub_article(binary), do: Regex.replace(
        ~r/^(§[ ]+\d+[a-z]?\-\d+[a-z]\.)[ ]*([A-ZÅØ].*)/m,
        binary,
        "#{sub_article_emoji()}\\g{1} \\g{2}"
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
    def get_amendment(binary), do: Regex.replace(
        ~r/(^\d+)[ \t]+([Jf.|Kapittel|Kapitlene|Endret|Tilføyd|Vedlegg|Opphevet|Hele|Drette|Overskrift endret|Henvisningen].*)/m,
        binary,
        "\n💥️\\g{1} \\g{2}\n\n"
    )
    @doc """
    Match an Annex -> Vedlegg X.
    """
    def get_annex(binary), do: Regex.replace(
        ~r/(^Vedlegg[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3}|\d+)\.[ ]+[A-ZÅØ].*)/m,
        binary,
        "\n🐽️\\g{1}\n"
    )
    @doc """
    Remove empty lines
    """
    def rm_empty(binary), do: Regex.replace(
        ~r/(?:\r\n|\n)+[ \t]?(?:\r\n|\n)+/m,
        binary,
        "\n"
    )
    @doc """
    Join lines
    """
    @no_join ~s/#{chapter_emoji()}#{sub_chapter_emoji()}#{article_emoji()}#{sub_article_emoji()}/

    def join(binary) do
      Regex.replace(
        ~r/(^[^#{@no_join}]\t*.*)[ \t]*(?:\r\n|\n)(?=[^#{@no_join}#{annex_emoji()}#{numbered_para_emoji()}])/m,
        binary,
        "\\g{1}#{pushpin_emoji()}"
      )
    end
    def join_amends(binary), do: Regex.replace(
        ~r/.(?:\r\n|\n)(?=#{amendment_emoji()})/m,
        binary,
        "\\g{1}#{pushpin_emoji()}"
    )
    def join_special(binary), do: Regex.replace(
        ~r/(^[^#{@no_join}#{amendment_emoji()}].*)[ \t]*(?:\r\n|\n)(?=[∑])/mu,
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

    @chapter ~r/^#{chapter_emoji()}Kapi?t?t?e?l?\.?[ ]*(\d+[A-Z]?)\.[ ]/
    @subchapter ~r/^#{sub_chapter_emoji()}(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.[ ]/
    @article ~r/^#{article_emoji()}§[ ]+(\d+)\./
    @article2 ~r/^#{article_emoji()}§[ ]+\d+[a-z]?[ ]?[A_Z]?\-(\d+)\./
    @subarticle ~r/^#{sub_article_emoji()}§[ ]+(\d+[a-z]?)\-?(\d*[a-z]*)\./
    @annex ~r/^#{annex_emoji()}Vedlegg[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3}|\d+)\./

    @doc """
    Numbering
    Chapter SubChapter  Article(sub)    Para
    1_1_1   1_1_1_1  1_1_2   1_1_2_1    1_1_2_2
    """
    def schemas(c \\ nil) do
        {:ok, binary} = File.read(Path.absname(Legl.annotated))
        schemas(binary, c)
    end
    def schemas(binary, c) do
        record = %{type: "", chapter: "", subchapter: "", article: "", para: 0, str: ""}
        # First line is always the title
        [head | tail] = String.split(binary, "\n", trim: true)
        txts = [~s(title\t\t\t\t\t#{head})]
        schemas =
            tail
            |> Enum.reduce(%{txts: txts, record: record}, fn str, acc ->
                record =
                    cond do
                        Regex.match?(@chapter, str) -> chapter(str, acc.record)
                        Regex.match?(@subchapter, str) -> subchapter(str, acc.record)
                        Regex.match?(@article, str) -> article(str, acc.record, "singly")
                        Regex.match?(@article2, str) -> article(str, acc.record, "combi")
                        Regex.match?(@subarticle, str) -> subarticle(str, acc.record)
                        Regex.match?(@annex, str) -> annex(str, acc.record)
                        true -> para(str, acc.record)
                    end
                case c do
                    nil -> %{acc | txts: [conv_map_to_record_string(record) | acc.txts], record: record}
                    _ ->
                        case record.chapter == Integer.to_string(c) do
                            true ->
                                %{acc | txts: [conv_map_to_record_string(record) | acc.txts], record: record}
                            _ -> %{acc | record: record}
                        end
                end

            end)

        Enum.count(schemas.txts) |> IO.inspect(label: "txts")

        Enum.reverse(schemas.txts)
        |> Enum.join("\n")
        |> String.replace("💥️", "")
        |> (&(File.write(Legl.txts, &1))).()
    end

    defp conv_map_to_record_string(
        %{type: type, chapter: chapter, subchapter: subchapter, article: article, para: para, str: str}) do
            para = if para == 0, do: "", else: para
            ~s(#{type}\t#{chapter}\t#{subchapter}\t#{article}\t#{para}\t#{str})
    end

    defp chapter(str, record) do
        [_, capture] = Regex.run(@chapter, str)
        str = String.replace(str, chapter_emoji(), "")
        %{record | type: "chapter", chapter: capture, subchapter: "", article: "", para: 0, str: str}
    end

    defp subchapter(str, record) do
        [_, _, capture] = Regex.run(@subchapter, str)
        str = String.replace(str, sub_chapter_emoji(), "")
        %{record | type: "sub-chapter", subchapter: conv_roman_numeral(capture), article: "", para: 0, str: str}
    end

    defp article(str, record, "singly") do
        [_, capture] = Regex.run(@article, str)
        str = String.replace(str, article_emoji(), "")
        %{record | type: "heading", article: capture, para: 0, str: str}
    end

    defp article(str, record, "combi") do
        [_, capture] = Regex.run(@article2, str)
        str = String.replace(str, article_emoji(), "")
        %{record | type: "heading", article: capture, para: 0, str: str}
    end

    defp subarticle(str, record) do
        capture =
          case Regex.run(@subarticle, str) do
            [_, capture, _] -> capture
            [_, capture] -> capture
          end
        str = String.replace(str, sub_article_emoji(), "")
        %{record | type: "sub-article", article: capture, para: 0, str: str}
    end

    defp para(str, record) do
      str = String.replace(str, numbered_para_emoji(), "")
      %{record | type: "article", para: record.para + 1, str: str}
    end

    defp annex(str, record) do
        [_, _, capture] = Regex.run(@annex, str)
        str = String.replace(str, annex_emoji(), "")
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
