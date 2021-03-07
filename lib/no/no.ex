defmodule Norway do
    @moduledoc """
    Parsing .html copied from https://lovdata.no/dokument/SF/forskrift/
    Norwegian alphabet:
    Æ 	æ
    Ø 	ø
    Å 	å
    """


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
        |> rm_empty()
        |> join_special()
        |> join()
        |> join_amends()
        |> rm_tabs()
        |> rm_footer()
        |> (&(File.write(Legl.annotated, &1))).()
    end

    @doc """
    Match a chapter heading -> Kapittel 1A.
    Flag with blue heart and separate as new line
    """
    def get_chapter(binary), do: Regex.replace(
        ~r/\.(?:\r\n|\n)(^Kapi?t?t?e?l?\.?[ ]*\d+[A-Z]?\.)(​\d?)([ ]*.*)(?:\r\n|\n)/m,
        binary,
        "\.\n\n🇳🇴\\g{1} \\g{3}\n\n"
    )
    @doc """
    Match a sub-chapter with Roman numbering -> I Name
    """
    def get_sub_chapter(binary), do: Regex.replace(
        ~r/\.(?:\r\n|\n)(^(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.[ ]+[A-ZÅØ].*)/m,
        binary,
        "\.\n\n⛔️\\g{1}\n\n"
    )
    @doc """
    Match Article -> § 1a-1.Name
    """
    def get_article(binary), do: Regex.replace(
        ~r/(?:\r\n|\n)(^§[ ]+\d+[a-z]?\-?\d*\.)[ ]*([\(A-ZÅØ].*)/m,
        binary,
        "\n\n💙\\g{1} \\g{2}\n\n"
    )
    @doc """
    Match Sub-Article -> § 1-1a.Name
    """
    def get_sub_article(binary), do: Regex.replace(
        ~r/(?:\r\n|\n)(^§[ ]+\d+[a-z]?\-\d+[a-z]\.)[ ]*([A-ZÅØ].*)/m,
        binary,
        "\n\n💜️\\g{1} \\g{2}\n\n"
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
    def join(binary), do: Regex.replace(
        ~r/(^[^⛔️💙💜️🇳🇴️].*)[ \t]*(?:\r\n|\n)(?=[^🐽️⛔️💙💜️🇳🇴️])/mu,
        binary,
        "\\g{1}📌"
    )
    def join_amends(binary), do: Regex.replace(
        ~r/.(?:\r\n|\n)(?=💥️)/m,
        binary,
        "\\g{1}📌"
    )
    def join_special(binary), do: Regex.replace(
        ~r/(^[^💥️⛔️💙💜️🇳🇴️].*)[ \t]*(?:\r\n|\n)(?=[∑])/mu,
        binary,
        "\\g{1}📌"
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

    def chapter_numbers() do
        {:ok, binary} = File.read(Path.absname(Legl.annotated))
        chapter_numbers(binary)
    end
    def chapter_numbers(binary) do
        regex = ~r/^🇳🇴Kapittel[ ]*(\d+[A-Z]?)\.[ ]/
        chapters =
            String.split(binary, "\n", trim: true)
            |> Enum.reduce([], fn str, acc ->
            case Regex.run(regex, str) do
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
        |> (&(File.write(Legl.chapter, &1))).()
    end

    def article_numbers() do
        {:ok, binary} = File.read(Path.absname(Legl.annotated))
        article_numbers(binary)
    end

    def article_numbers(binary) do
        regex = ~r/^💙§[ ]+\d+[a-z]?\-(\d+)\./
        articles =
            String.split(binary, "\n", trim: true)
            |> Enum.reduce([], fn str, acc ->
                case Regex.run(regex, str) do
                    [_match, capture] ->
                        [String.replace(capture, " ", "") | acc]
                    nil -> ["" | acc]
                end
            end)
            |> Enum.reverse()

        Enum.count(articles) |> IO.inspect(label: "articles")

        Enum.join(articles, "\n")
        |> (&(File.write(Legl.article, &1))).()
    end

    def sub_article_numbers() do
        {:ok, binary} = File.read(Path.absname(Legl.annotated))
        sub_article_numbers(binary)
    end
    def sub_article_numbers(binary) do
        regex = ~r/^💜️§[ ]+\d+[a-z]?\-(\d+[a-z])\./
        sub_articles =
            String.split(binary, "\n", trim: true)
            |> Enum.reduce([], fn str, acc ->
                case Regex.run(regex, str) do
                    [_match, capture] ->
                        [String.replace(capture, " ", "") | acc]
                    nil -> ["" | acc]
                end
            end)
            |> Enum.reverse()

        Enum.count(sub_articles) |> IO.inspect(label: "sub articles")

        Enum.join(sub_articles, "\n")
        |> (&(File.write(Legl.sub_article, &1))).()
    end

    @chapter ~r/^🇳🇴Kapi?t?t?e?l?\.?[ ]*(\d+[A-Z]?)\.[ ]/
    @subchapter ~r/^⛔️(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.[ ]/
    @article ~r/^💙§[ ]+(\d+)\./
    @article2 ~r/^💙§[ ]+\d+[a-z]?\-(\d+)\./
    @subarticle ~r/^#{Legl.blue_heart()}§[ ]+(\d+[a-z]?)\-?(\d*[a-z]*)\./
    #@amendment ~r/^💥️/
    @annex ~r/^🐽️Vedlegg[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3}|\d+)\./

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
                        #Regex.match?(@amendment, str) -> amendment(str, acc.record)
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
        str = String.replace(str, "🇳🇴", "")
        %{record | type: "chapter", chapter: capture, subchapter: "", article: "", para: 0, str: str}
    end

    defp subchapter(str, record) do
        [_, _, capture] = Regex.run(@subchapter, str)
        str = String.replace(str, "⛔", "")
        %{record | type: "sub-chapter", subchapter: conv_roman_numeral(capture), article: "", para: 0, str: str}
    end

    defp article(str, record, "singly") do
        [_, capture] = Regex.run(@article, str)
        str = String.replace(str, "💙", "")
        %{record | type: "heading", article: capture, para: 0, str: str}
    end

    defp article(str, record, "combi") do
        [_, capture] = Regex.run(@article2, str)
        str = String.replace(str, "💙", "")
        %{record | type: "heading", article: capture, para: 0, str: str}
    end

    defp subarticle(str, record) do
        capture =
          case Regex.run(@subarticle, str) do
            [_, capture, _] -> capture
            [_, capture] -> capture
          end
        str = String.replace(str, Legl.blue_heart(), "")
        %{record | type: "sub-article", article: capture, para: 0, str: str}
    end

    defp para(str, record) do
        %{record | type: "article", para: record.para + 1, str: str}
    end

    defp annex(str, record) do
        [_, _, capture] = Regex.run(@annex, str)
        str = String.replace(str, "🐽️", "")
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
