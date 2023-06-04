defmodule Legl.Countries.Uk.UkClean do
  @region_regex UK.region()
  @country_regex UK.country()
  @geo_regex @region_regex <> "|" <> @country_regex
  @components %Types.Component{}
  alias Legl.Countries.Uk.AirtableArticle.UkArticleQa, as: QA

  # def clean_original("CLEANED\n" <> binary, _opts) do
  #  binary |> (&IO.puts("cleaned: #{String.slice(&1, 0, 100)}...")).()
  #  binary
  # end

  def clean_original(binary, %{type: :act} = opts) do
    binary =
      binary
      # |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> rm_marginal_citations()
      |> collapse_amendment_text_between_quotes()
      |> separate_part()
      ## |> separate_chapter()
      ## |> separate_schedule()
      ## |> Legl.Parser.rm_leading_tabs()
      |> join_empty_numbered()
      |> opening_quotes()
      |> closing_quotes()
      |> chapter_style()
      |> split_acronymed_sections(opts)
      |> numericalise_schedules(opts)
      |> rem_quotes()
      |> join_repeals()
      |> join_derivations()

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    binary |> (&IO.puts("\n\ncleaned: #{String.slice(&1, 0, 100)}...")).()

    if opts.clean == true do
      binary
    else
      :ok
    end

    # clean_original(binary, opts)
  end

  def clean_original(binary, _opts) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> collapse_amendment_text_between_quotes()
      # |> separate_part_chapter_schedule()
      |> separate_part()
      |> separate_chapter()
      |> separate_schedule()
      |> join_empty_numbered()
      # |> rm_overview()
      # |> rm_footer()
      |> Legl.Parser.rm_leading_tabs()
      |> closing_quotes()

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    # clean_original(binary, opts)
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
        ~s/inserte?d?—/,
        ~s/substituted?—/,
        ~s/adde?d?—/,
        ~s/substituted the following subsections?—/,
        ~s/inserted the following subsections?—/,
        ~s/inserted the following section—/,
        ~s/inserted the following Schedule—/,
        ~s/inserted the following Part—/,
        ~s/substituted the following sections—/,
        ~s/the following provisions shall be inserted after .*?—/,
        ~s/substituted in each case—/
      ]
      |> Enum.join("|")

    binary
    |> (&Regex.replace(
          ~r/(#{regex})(#{@region_regex})?([\s\S]*?)(“)/m,
          &1,
          "\\1 \\2\n⭕\\4 \\3"
        )).()
    |> String.graphemes()
    |> Enum.reduce({[], 0}, fn char, {acc, counter} ->
      case char do
        # heavy large circle ⭕ is 11093 as codepoint or 2B55 in Hex
        # reset counter @ 10000
        "\u2B55" ->
          {[~s/\u2B55/ | acc], 10000}

        # left double quote mark is 8220 as codepoint or 201C in Hex
        "\u201C" ->
          {[~s/\u201C/ | acc], counter + 1}

        # right double quote mark is 8221 as codepoint or 201D in Hex
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

              _ ->
                "#{join(x)}"
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
        ~r/^(\(([a-z]+|[ivmcldx]+)\)|\d+\.?)(?:\r\n|\n)/m,
        binary,
        "\\g{1} "
      )

  defp opening_quotes(binary) do
    regex = ~s/([ \\(]|F\\d+)\\"(\\w)/
    QA.scan_and_print(binary, regex, "Opening Quotes", true)

    Regex.replace(
      ~r/#{regex}/m,
      binary,
      fn _, prefix, suffix ->
        ~s/#{prefix}\u201C#{suffix}/
      end
    )
  end

  defp closing_quotes(binary) do
    regex = ~s/(.)\\"([\\. \\)])/
    QA.scan_and_print(binary, regex, "Closing Quotes", true)

    Regex.replace(
      ~r/#{regex}/m,
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
    regex =
      case Regex.match?(
             ~r/^Chapter[ ]*\tShort [Tt]itle[ ]*\tExtent of [Rr]epeal\n[\s\S]*?(?=\n^[^\t\d\[])/m,
             binary
           ) do
        true ->
          ~r/^Chapter[ ]*\tShort [Tt]itle[ ]*\tExtent of [Rr]epeal\n[\s\S]*?(?=\n^[^\t\d\[])/m

        false ->
          ~r/Chapter[ ]*\tShort [Tt]itle[ ]*\tExtent of [Rr]epeal\n[\s\S]*?$/
      end

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

                join("#{@components.section}1 " <> x) <> " [::region::]"

              _ ->
                join("#{@components.section}1 " <> x) <> " [::region::]"
            end
          end
        )).()
  end

  def join_derivations(binary) do
    regex1 = ~r/(#{@geo_regex})(TABLE OF DERIVATIONS)\n([\s\S]*?)$/

    regex2 = ~r/Table of Derivations(#{@geo_regex})\n([\s\S]*)$/

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

    [
      ~s/#{@components.table_heading}#{heading} [::region::]#{region}/,
      ~s/#{join(@components.table <> txt)}/
    ]
    |> Enum.join("\n")
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
end
