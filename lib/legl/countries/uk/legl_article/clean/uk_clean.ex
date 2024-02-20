defmodule Legl.Countries.Uk.UkClean do
  @region_regex UK.region()
  @country_regex UK.country()
  @geo_regex @region_regex <> "|" <> @country_regex
  @components %Types.Component{}
  @debug ~s[lib/legl/data_files/txt/debug.txt] |> Path.absname()
  alias Legl.Countries.Uk.AirtableArticle.UkArticleQa, as: QA
  alias Legl.Countries.Uk.AtArticle.Clean.UkBespoke

  def api_clean(opts) do
    # Working with files when no binary passed
    IO.puts("***********CLEAN***********")

    text =
      File.read!(opts.path_orig_txt)
      |> clean_original(opts)

    File.open(opts.path_clean_txt, [:write, :utf8])
    |> elem(1)
    |> IO.write(text)

    {:ok, text}
  end

  def api_clean("", _), do: {:ok, ""}

  def api_clean(binary, opts) do
    {:ok, clean_original(binary, opts)}
  end

  # PRIVATE FUNCTIONS

  defp clean_original(binary, %{type: :act, html?: true} = opts) do
    binary
    |> post_process()
    |> rm_carriage_return()
    |> UkBespoke.bespoker(opts."Name")
    |> Legl.Parser.rm_empty_lines()
    |> set_sub_clauses()
    |> collapse_amendment_text_between_quotes()
    |> opening_quotes()
    |> closing_quotes()
  end

  defp clean_original(binary, %{type: :act} = opts) do
    binary
    |> rm_between_marks()
    |> UkBespoke.bespoker(opts."Name")
    |> Legl.Parser.rm_empty_lines()
    |> collapse_amendment_text_between_quotes()
    |> collapse_amendment_text_between_quotes()
    |> close_parentheses()
    |> rm_marginal_citations()
    |> separate_part()
    |> join_empty_numbered()
    |> opening_quotes()
    |> closing_quotes()
    |> chapter_style()
    |> split_acronymed_sections(opts)
    |> numericalise_schedules(opts)
    |> rem_quotes()
    |> join_repeals()
    |> join_repeals_ii()
    |> join_derivations()
    |> collapse_table_text()
    |> rm_multi_space()
    |> period_para()
  end

  defp clean_original(binary, opts) do
    binary
    |> post_process()
    |> rm_carriage_return()
    |> UkBespoke.bespoker(opts."Name")
    |> Legl.Parser.rm_empty_lines()
    |> set_sub_clauses()
    |> collapse_amendment_text_between_quotes()
    |> opening_quotes()
    |> closing_quotes()
  end

  defp post_process(binary) do
    IO.puts("post_process/1")

    text =
      binary
      # DEAL WITH SPACES
      # rm <<194, 160>> and replace with space - putting [] around introduces a hard bug to fix!
      |> (&Regex.replace(~r/#{<<194, 160>>}+/m, &1, " ")).()
      # rm multi-spaces
      |> (&Regex.replace(~r/[ ]{2,}/m, &1, " ")).()
      # rm space at start of line
      |> String.replace(~r/\n[ ]+/, "\n")
      # rm space at end of line
      |> (&Regex.replace(~r/[ ]$/m, &1, "")).()
      # rm any space after end of tag
      |> (&Regex.replace(~r/(\[::[a-z]+::\])[ ]/m, &1, "\\g{1}")).()
      # rm space before period and other punc marks at end of line
      |> (&Regex.replace(~r/[ ]+([\.\];])$/m, &1, "\\g{1}")).()
      # rm space after ef bracket
      |> (&Regex.replace(~r/\[[ ]F/m, &1, "[F")).()
      # rm spaces before and after quotes
      |> (&Regex.replace(~r/“[ ]/m, &1, "“")).()
      |> (&Regex.replace(~r/[ ]”/m, &1, "”")).()
      # rm spaces before or after sub-para hyphen
      |> (&Regex.replace(~r/\.[ ]*—\(/m, &1, ".—(")).()
      |> (&Regex.replace(~r/\.—[ ]*\(/m, &1, ".—(")).()
      |> (&Regex.replace(~r/\.[ ]*—[ ]*\(/m, &1, ".—(")).()

      # rm spaces new lines around parenthatised numbers
      |> (&Regex.replace(~r/(.)\([ ](\d+)[ ]\)/m, &1, "\\g{1} (fn\\g{2})")).()
      # |> (&Regex.replace(~r/\([ ]\d+[ ]\)/m, &1, "")).()

      # replace carriage returns
      |> (&Regex.replace(~r/\r/m, &1, "\n")).()
      |> (&Regex.replace(~r/\n{2,}/m, &1, "\n")).()

      # join sub with empty line
      |> (&Regex.replace(~r/^(\([a-z]+\))\n/m, &1, "\\g{1} ")).()
      # rm space after [::region::]
      |> (&Regex.replace(~r/\[::region::\][ ]/m, &1, "[::region::]")).()
      # rm duped [::region::]
      |> (&Regex.replace(~r/(\[::region::\]\[::region::\])/m, &1, "[::region::]")).()

      # concatenate [::region::] above [::article::]
      |> (&Regex.replace(~r/(^\[::region::\].*)\n(^\[::article::\].*)/m, &1, "\\g{2} \\g{1}")).()

      # put in -1 for those articles & paras
      |> (&Regex.replace(
            ~r/(\[::section::\]|\[::article::\]|\[::paragraph::\])(\d+[A-Z]*)([^-\d].*?—.*?\(([A-Z]?1)\))/m,
            &1,
            "\\g{1}\\g{2}-\\g{4}\\g{3}"
          )).()

      # Concatenate [::part::] with next line
      |> (&Regex.replace(
            ~r/(\[::part::\].*)\n((?!\[::).*)\n((?!\[::).*)?/m,
            &1,
            "\\g{1} \\g{2} \\g{3}\n"
          )).()
      # join chapter
      |> (&Regex.replace(~r/(\[::chapter::\].*)\n(.*\[::region::\].*)/m, &1, "\\g{1} \\g{2}")).()
      # Concatenate [::chapter::] with next line
      |> (&Regex.replace(~r/(\[::chapter::\].*)\n((?!\[::).*)/m, &1, "\\g{1} \\g{2}")).()

      # 4E
      # [::section::]4E-1 (1)
      # text
      # [::region::]S
      # Uses a matching subpattern
      |> (&Regex.replace(
            ~r/(?'s'\d+[A-Z])\n(\[::section::\](?P=s).*)\n((?!\[::).*)\n(\[::region::\].*)?/m,
            &1,
            "\\g{2} \\g{3} \\g{4}\n"
          )).()
      # Concatenate [::section::] with next line
      # [::section::]4B
      # 4B Coal mine water discharge: powers of entry [::region::]E+W
      |> (&Regex.replace(~r/^(\[::section::\].*)\n((?!\[::).*)/m, &1, "\\g{1} \\g{2}")).()

    File.open(@debug, [:write, :utf8])

    File.write!(@debug, text)

    text =
      text
      # [::part::]2
      # [::sRef::]Regulation 48(2)
      # PART II MODIFICATIONS

      |> (&Regex.replace(
            ~r/(\[::part::\].*)\n(?:\[::sRef::\](.*)\n)?((?!\[::).*)\n((?!\[::).*)?/m,
            &1,
            "\\g{1} \\g{3} \\g{4}\n\\g{2}\n"
          )).()
      # [::part::]1 Part I
      # [::region::]U.K.
      # Organisation and Proceedings
      |> (&Regex.replace(
            ~r/(\[::part::\].*)\n(\[::region::\](.*)\n)?((?!\[::).*)\n((?!\[::).*)?/m,
            &1,
            "\\g{1} \\g{3} \\g{4} \\g{2}"
          )).()
      # [::annex::]3
      # [::sRef::]Regulation 8(2)
      # SCHEDULE 3
      # Ignition resistance test for interliner.
      |> (&Regex.replace(
            ~r/(\[::annex::\].*)\n(?:\[::sRef::\](.*)\n)?((?!\[::).*)\n((?!\[::).*)?/m,
            &1,
            "\\g{1} \\g{3} \\g{4}\n\\g{2}\n"
          )).()
      # [::annex::]1
      # [::region::]N.I.
      # Schedule 1—Amendments
      |> (&Regex.replace(
            ~r/(\[::annex::\].*)\n(\[::region::\].*\n)?((?!\[::).*)/m,
            &1,
            "\\g{1} \\g{3} \\g{4}\\g{2}\n"
          )).()
      # rm duped [::heading::]
      |> (&Regex.replace(~r/(\[::heading::\]\[::heading::\])/m, &1, "[::heading::]")).()
      # rm empty headings
      |> (&Regex.replace(~r/^\[::heading::\]\[::region::\].+?\n/m, &1, "")).()
      |> (&Regex.replace(~r/^\[::heading::\]\n/m, &1, "")).()

      # PARAGRAPHS

      # Rm p. in composite 1 [::paragraph::]1-1
      |> (&Regex.replace(~r/^\d+[ ](\[::paragraph::\])/m, &1, "\\g{1}")).()
      # Join empty paragraphs
      |> (&Regex.replace(~r/^(\[::paragraph::\][\d\.]+)\n((?!\[::).*)/m, &1, "\\g{1} \\g{2}")).()
      # Rm orphan paragraphs
      |> (&Regex.replace(~r/\[::paragraph::\][\d\.]*\n/, &1, "")).()

      # Rm Marginal Citations [::marginal_citation::]Marginal Citations
      |> (&Regex.replace(~r/^\[::marginal_citation::\].*/m, &1, "")).()

    IO.puts("...complete")
    text
  end

  defp set_sub_clauses(binary) do
    # we cannot distinguish sub clause type in the parser and all are called [::sub::]
    # change the name depending on what comes before
    String.split(binary, "\n")
    |> Enum.reduce({[], nil}, fn
      "[::article::]" <> _ = ln, {acc, _state} ->
        {[ln | acc], :article}

      "[::section::]" <> _ = ln, {acc, _state} ->
        {[ln | acc], :section}

      "[::paragraph::]" <> _ = ln, {acc, _state} ->
        {[ln | acc], :paragraph}

      "[::sub::]" <> _ = ln, {acc, state} ->
        ln =
          case state do
            :article -> String.replace(ln, "[::sub::]", "[::sub_article::]")
            :section -> String.replace(ln, "[::sub::]", "[::sub_section::]")
            :paragraph -> String.replace(ln, "[::sub::]", "[::sub_paragraph::]")
          end

        {[ln | acc], state}

      ln, {acc, state} ->
        {[ln | acc], state}
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @doc """
  Certain pieces of legislation contain content for which we are not interested.
  This function deletes lines from the clean.txt that lie between manually marked
  emojis.
  🟢 is used to mark
  """
  def rm_between_marks(binary) do
    regex = ~r/^🟢[\S\s]*?🟢$/m
    Regex.replace(regex, binary, "")
  end

  def rm_marginal_citations(binary) do
    binary
    |> (&Regex.replace(
          ~r/^Marginal[ ]Citations\n/m,
          &1,
          ""
        )).()
    |> (&Regex.replace(
          ~r/^M\d+([ ]|\.).*\n/m,
          &1,
          ""
        )).()
  end

  @spec separate_part(binary) :: binary
  def separate_part(binary),
    do:
      Regex.replace(
        ~r/^((?:PART|Part)[ ]\d+)([A-Za-z]+)/m,
        binary,
        "\\g{1} \\g{2}"
      )

  @spec separate_chapter(binary) :: binary
  def separate_chapter(binary),
    do:
      Regex.replace(
        ~r/^((?:CHAPTER|Chapter)[ ]?\d*[A-Z]?)([A-Z].*)/m,
        binary,
        "\\g{1} \\g{2}"
      )
      |> (&Regex.replace(
            ~r/^\[(F\d+)((?:CHAPTER|Chapter)[ ]?\d*[A-Z]?)([A-Z].*)/m,
            &1,
            "[🔺\\g{1}🔺 \\g{2} \\g{3}"
          )).()

  @spec separate_schedule(binary) :: binary
  def separate_schedule(binary),
    do:
      Regex.replace(
        ~r/^((?:SCHEDULES?|Schedules?)[ ]?\d*[A-Z])([A-Z].*)/m,
        binary,
        "\\g{1} \\g{2}"
      )

  @spec separate_part_chapter_schedule(binary) :: binary
  def separate_part_chapter_schedule(binary),
    do:
      Regex.replace(
        ~r/^(PART[ ]\d+)([A-Z]+)/m,
        binary,
        "\\g{1} \\g{2}"
      )
      |> (&Regex.replace(
            ~r/^(CHAPTER[ ]\d+)([A-Z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()
      |> (&Regex.replace(
            ~r/^(SCHEDULE)(S?)([A-Z a-z]*)/m,
            &1,
            "\\g{1}\\g{2}\\g{3}"
          )).()
      |> (&Regex.replace(
            ~r/^(SCHEDULE[ ]\d+)([A-Z a-z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()

  @spec collapse_amendment_text_between_quotes(binary) :: binary
  def collapse_amendment_text_between_quotes(binary) do
    # Clean up :— to —
    # there shall be substituted the following subsection:—
    binary = Regex.replace(~r/:—/, binary, "—")

    regex =
      [
        ~s/inserte?d?.*?—/,
        ~s/substituted?.*?—/,
        ~s/adde?d?—/,
        ~s/sections are—$/,
        ~s/(?:substituted|inserted) the following subsections?—/,
        ~s/(?:substituted|inserted) the following sections?—/,
        ~s/(?:substituted|inserted) the following Schedules?—/,
        ~s/(?:substituted|inserted) the following Parts?—/,
        ~s/(?:substituted|inserted) the following s?u?b?-?paragraphs?—/,
        ~s/(?:substituted|inserted) the following sections—/,
        ~s/[Tt]he following (?:provisions|sections|sub-paragraph)? ?shall be (?:substituted|inserted) (?:after|in) .*?—/,
        ~s/substituted in each case—/,
        ~s/\\(and the italic cross-heading before it\\) insert—/
      ]
      |> Enum.join("|")

    binary
    |> (&Regex.replace(
          ~r/(#{regex})(#{@region_regex})?\n(.*?)“/m,
          # ~r/(#{regex})(#{@region_regex})?([\s\S]*?)(“)/m,
          &1,
          "\\1 \\2\n⭕“\\3"
        )).()
    |> String.graphemes()
    |> Enum.reduce({[], 0}, fn char, {acc, counter} ->
      case char do
        # heavy large circle ⭕ is 11093 as codepoint or 2B55 in Hex
        # reset counter @ 10000
        "\u2B55" ->
          {[~s/\u2B55/ | acc], 10000}

        # left double quote mark “ is 8220 as codepoint or 201C in Hex
        "\u201C" ->
          {[~s/\u201C/ | acc], counter + 1}

        # right double quote mark ” is 8221 as codepoint or 201D in Hex
        # if the counter is back to 1 then we've found the matching pair
        # cross mark ❌ is 10060 as codepoint or 274C in Hex
        "\u201D" ->
          counter = counter - 1

          if counter == 10000 do
            {[~s/\u274C\u201D/ | acc], 0}
          else
            {[~s/\u201D/ | acc], counter}
          end

        _ ->
          {[char | acc], counter}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join()
    |> (&Regex.replace(
          ~r/(\r\n|\n)#{"\u2B55"}#{"\u201C"}[\s\S]*?#{"\u274C"}#{"\u201D"}/m,
          &1,
          fn x ->
            len = String.length(x)

            case len > 500 do
              true ->
                (String.slice(x, 0..199) <> "📌...📌" <> String.slice(x, (len - 199)..len))
                |> join()
                |> String.replace(~r/[ ]\[::region::\].+?[ ]/, " ")

              _ ->
                "#{join(x)}"
                |> String.replace(~r/[ ]\[::region::\].+?[ ]/, " ")
            end
          end
        )).()
  end

  def join(binary) do
    Regex.replace(
      ~r/(\r\n|\n)/m,
      binary,
      " #{Legl.pushpin_emoji()}"
    )
  end

  def join_empty_numbered(binary),
    do:
      Regex.replace(
        ~r/^(\(([a-z]+|[ivmcldx]+)\))(?:\r\n|\n)/m,
        binary,
        "\\g{1} "
      )
      # to join sections that are separated from the sub-section
      # 8\n(1) -> 8(1)
      |> (&Regex.replace(
            ~r/^(\d+\.?)\n^\(/m,
            &1,
            "\\g{1}("
          )).()

  defp opening_quotes(binary) do
    # [F44(5)"Welsh zone”
    # (3C)“"Devolved Welsh generating station””
    regex = ~s/([ \\(“]|F\\d+\\(?\\d*\\)?)\\"(\\w)/
    QA.scan_and_print(binary, regex, "Opening Quotes", true)

    binary =
      Regex.replace(
        ~r/#{regex}/m,
        binary,
        fn _, prefix, suffix ->
          ~s/#{prefix}\u201C#{suffix}/
        end
      )

    regex = ~r/^"[ ]?/m

    QA.scan_and_print(binary, regex, "Opening Quotes @ Line Start", true)
    # And opening quotes at start of line
    binary
    |> (&Regex.replace(regex, &1, "\u201C")).()
  end

  defp closing_quotes(binary) do
    regex = ~r/(.)\"/m
    QA.scan_and_print(binary, regex, "Closing Quotes", true)

    Regex.replace(
      regex,
      binary,
      fn _, prefix, suffix ->
        ~s/#{prefix}\u201D#{suffix}/
      end
    )
  end

  defp rem_quotes(binary) do
    IO.inspect(Regex.scan(~r/^.*?\"/m, binary), label: "Remaining Quotes")
    binary
  end

  def chapter_style(binary) do
    # Chapter is sometimes lowercased.  Change to uppercase
    Regex.replace(~r/^chapter/m, binary, "Chapter")

    # Chapter can sometimes have lowercased roman numerals.  Change to uppercase
    |> (&Regex.replace(
          ~r/^(CHAPTER|Chapter)[ ]?(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})/m,
          &1,
          fn _, c, g1, g2 -> "#{c} #{String.upcase(g1)}#{String.upcase(g2)}" end
        )).()
  end

  def join_repeals(binary) do
    regexes = %{
      in_flow:
        ~r/^Chapter[ ]*\tShort [Tt]itle[ ]*\tExtent of [Rr]epeal\n[\s\S]*?(?=\n^[^\t\d\[])/m,
      doc_end_one: ~r/Chapter[ ]*\tShort [Tt]itle[ ]*\tExtent of [Rr]epeal\n[\s\S]*?$/,
      doc_end_two: ~r/Chapter[ ]or[ ]number\t[Tt]itle[ ]*\tExtent of [Rr]epeal\n[\s\S]*?$/
    }

    regex =
      cond do
        Regex.match?(regexes.in_flow, binary) -> regexes.in_flow
        Regex.match?(regexes.doc_end_one, binary) -> regexes.doc_end_one
        Regex.match?(regexes.doc_end_two, binary) -> regexes.doc_end_two
        true -> nil
      end

    case regex do
      nil ->
        binary

      _ ->
        # IO.inspect(regex)
        # QA.scan_and_print(binary, regex, "Repeal", true)

        binary
        |> (&Regex.replace(
              regex,
              &1,
              fn x ->
                len = String.length(x)

                case len > 500 do
                  true ->
                    x = String.slice(x, 0..199) <> "📌...📌" <> String.slice(x, (len - 199)..len)

                    join("#{@components.table}" <> x) <> " [::region::]"

                  _ ->
                    join("#{@components.table}" <> x) <> " [::region::]"
                end
              end
            )).()
    end
  end

  def join_repeals_ii(binary) do
    title1 =
      ~s/Short [Tt]itle and chapter or title and number[ \\t]Extent of repeal or revocation/

    title2 = ~s/Short [Tt]itle[ ]*and[ ]chapter[ \\t]Extent of [Rr]epeal/
    title3 = ~s/Reference[ \\t]+Short title or title[ \\t]+Extent of repeal orrevocation/
    str = ~s/(#{title1}|#{title2}|#{title3})/

    regex1 = ~r/^#{str}\n[\s\S]*?(?=\n^(?:\(\d|Part[ ]\d))/m
    regex2 = ~r/#{str}\n[\s\S]*$/

    # IO.inspect(regex)
    # QA.scan_and_print(binary, regex, "Repeal", true)

    binary
    |> (&Regex.replace(
          regex1,
          &1,
          fn x ->
            len = String.length(x)

            case len > 500 do
              true ->
                x = String.slice(x, 0..199) <> "📌...📌" <> String.slice(x, (len - 199)..len)

                join("#{@components.table}" <> x) <> " [::region::]"

              _ ->
                join("#{@components.table}" <> x) <> " [::region::]"
            end
          end
        )).()
    |> (&Regex.replace(
          regex2,
          &1,
          fn x ->
            len = String.length(x)

            case len > 500 do
              true ->
                x = String.slice(x, 0..199) <> "📌...📌" <> String.slice(x, (len - 199)..len)

                join("#{@components.table}" <> x) <> " [::region::]"

              _ ->
                join("#{@components.table}" <> x) <> " [::region::]"
            end
          end
        )).()
  end

  def join_derivations(binary) do
    regex1 = ~r/(#{@geo_regex})[ ]?(TABLE OF DERIVATIONS)\n([\s\S]*?)$/

    regex2 = ~r/^Table of Derivations(#{@geo_regex})?\n([\s\S]*)(?=\nTextual Amendments)/m

    regex3 = ~r/Table of Derivations(#{@geo_regex})\n([\s\S]*)$/

    binary
    |> (&Regex.replace(
          regex1,
          &1,
          fn _, region, heading, txt -> derivation_text([region, heading, txt]) end
        )).()
    |> (&Regex.replace(
          regex2,
          &1,
          fn _, region, txt -> derivation_text([region, txt]) end
        )).()
    |> (&Regex.replace(
          regex3,
          &1,
          fn _, region, txt -> derivation_text([region, txt]) end
        )).()
  end

  def derivation_text([region, txt]),
    do: derivation_text([region, "Table of Derivations", txt])

  def derivation_text([region, heading, txt]) do
    len = String.length(txt)

    txt =
      case len > 500 do
        true ->
          String.slice(txt, 0..199) <> "📌...📌" <> String.slice(txt, (len - 199)..len)

        _ ->
          txt
      end

    region =
      if region != "" do
        " [::region::]#{region}"
      else
        region
      end

    txt = "#{@components.table}#{heading}#{region}\n#{txt}"

    join(txt)
  end

  @doc """
  Function to collapse tables
  Difficult to prescribe what is and isn't likely to form the text of the Table
  Mark-up the end of Table's manually with hashtag #
  """
  def collapse_table_text(binary) do
    regex = ~r/^TABLE\n([\s\S]*?)(?=[#]$)/m

    binary
    |> (&Regex.replace(
          regex,
          &1,
          fn _, txt ->
            ~s/#{join(@components.table <> "TABLE\n" <> txt)}/
          end
        )).()
  end

  def rm_multi_space(binary) do
    Regex.replace(~r/[ ]{2,}/m, binary, " ")
  end

  # ( 1 )The Secretary of State
  def close_parentheses(binary) do
    Regex.replace(~r/\([ ](\d+[A-Z]*)[ ]\)/m, binary, "(\\g{1})")
    |> (&Regex.replace(~r/\([ ]([a-z]+)[ ]\)/m, &1, "(\\g{1})")).()
    # space after closing )
    |> (&Regex.replace(~r/\)([\S])/m, &1, ") \\g{1}")).()
    # correct ) ,
    |> (&Regex.replace(~r/\)[ ]([,—\(])/m, &1, ")\\g{1}")).()
  end

  def period_para(binary) do
    Regex.replace(~r/para(s?)[ ]/m, binary, "para\\g{1}. ")
  end

  @doc """
  1ABC Foobar becomes 1 ABC Foobar
  """
  def split_acronymed_sections(binary, %{split_acronymed_sections: false} = _opts), do: binary

  def split_acronymed_sections(binary, %{split_acronymed_sections: true} = _opts) do
    Regex.replace(~r/^(\d{1,3})([A-Z]{3,})/m, binary, "\\g{1} \\g{2}")
  end

  def numericalise_schedules(binary, %{numericalise_schedules: false} = _opts), do: binary

  def numericalise_schedules(binary, %{numericalise_schedules: true} = _opts) do
    ordinals = %{
      "first" => "1",
      "second" => "2",
      "third" => "3",
      "fourth" => "4",
      "fifth" => "5",
      "sixth" => "6",
      "seventh" => "7",
      "eighth" => "8",
      "ninth" => "9",
      "tenth" => "10"
    }

    Enum.reduce(ordinals, binary, fn {k, v}, acc ->
      regex =
        ~s/^(F?\\d+)*(#{k}|#{String.upcase(k)}|#{Legl.Utility.upcaseFirst(k)})[ ](SCHEDULE|Schedule)/

      Regex.replace(
        ~r/#{regex}/m,
        acc,
        fn _match, ef, _, _ ->
          case ef do
            "" ->
              "SCHEDULE #{v}"

            _ ->
              "#{ef} SCHEDULE #{v} "
          end
        end
      )
    end)
  end

  def rm_carriage_return(binary) do
    binary
    |> (&Regex.replace(~r/\r/m, &1, "\n")).()
    |> (&Regex.replace(~r/\n{2,}/m, &1, "\n")).()
  end
end
