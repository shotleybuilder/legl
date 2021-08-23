defmodule DE.Parser do
  alias Types.Component

  @components %Component{}
  @roman_numerals Regex.replace(~r/[ ]/, Legl.roman(), "|")

  @de_ordinals ~s(Erster
 Zweiter
 Dritter
 Vierter
 Fünfter
 Sechster
 Siebter
 Achter
 Neunter
 Zehnter
 Elfter
 Zwölfter
 Dreizehnter
 Vierzehnter
 Fünfzehnter
 Sechzehnter
 Siebzehnter
 Achtzehnter
 Neunzehnter
 Zwanzigstel)

  @regex_de_ordinals Regex.replace(~r/\n/, @de_ordinals, "")
                     |> (&Regex.replace(~r/[ ]/, &1, "|")).()

  @de_cardinal_ordinal String.split(@de_ordinals)
                       |> Enum.reduce({%{}, 1}, fn x, {map, inc} ->
                         {Map.put(map, x, inc), inc + 1}
                       end)
                       |> Kernel.elem(0)

  def ordinal_as_cardinal(ordinal) do
    case Map.get(@de_cardinal_ordinal, ordinal) do
      nil -> ""
      x -> Integer.to_string(x)
    end
  end

  @doc false
  @spec clean_original(String.t()) :: String.t()
  def clean_original("CLEANED\n" <> binary) do
    binary
    |> (&IO.puts("cleaned: #{String.slice(&1, 0, 10)}...")).()

    binary
  end

  def clean_original(binary) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      # |> rm_header()
      |> rm_overview()
      |> rm_footer()
      |> Legl.Parser.rm_leading_tabs()

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    clean_original(binary)
  end

  def rm_header(binary) do
    Regex.replace(
      ~r//s,
      binary,
      ""
    )
  end

  def rm_overview(binary) do
    Regex.replace(
      ~r/^((?:Abschnitt[ ]1|1.[ ]Abschnitt)\n.*?\n)(Nichtamtliches[ ]Inhaltsverzeichnis\n)/m,
      binary,
      "\\g{2}\\g{1}"
    )
    |> (&Regex.replace(
          ~r/^(Inhaltsübersicht|Inhaltsverzeichnis).*?Nichtamtliches Inhaltsverzeichnis\n/ms,
          &1,
          ""
        )).()
  end

  def rm_footer(binary) do
    binary
    |> (&Regex.replace(
          ~r/\n[ ]*zum Seitenanfang\n.*/s,
          &1,
          ""
        )).()
  end

  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> get_footnote()
    |> rm_toc()
    |> get_title()
    |> get_appendix()
    |> get_annex()
    |> get_part()
    |> get_chapter()
    |> get_section()
    |> get_sub_section()
    |> get_approval()
    |> get_article()
    |> get_para()
    |> get_amendment()
    |> join_sub_paras()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  def get_title(binary) do
    "#{@components.title} #{binary}"
  end

  def get_part(binary) do
    Regex.replace(
      ~r/^Teil[ ](\d+).*/m,
      binary,
      "#{@components.part}\\g{1} \\0"
    )
  end

  def get_chapter(binary) do
    Regex.replace(
      ~r/^Kapitel[ ](\d+).*/m,
      binary,
      "#{@components.chapter}\\g{1} \\0"
    )
  end

  def get_section(binary) do
    Regex.replace(
      ~r/^(#{@regex_de_ordinals})([ ]Abschnitt)/m,
      binary,
      fn _m, n, s ->
        "#{@components.section}#{ordinal_as_cardinal(n)} #{n}#{s}"
      end
    )
    |> (&Regex.replace(
          ~r/^Abschnitt[ ](\d+).*/m,
          &1,
          "#{@components.section}\\g{1} \\0"
        )).()
    |> (&Regex.replace(
          ~r/^(\d+)\.[ ]Abschnitt.*/m,
          &1,
          "#{@components.section}\\g{1} \\0"
        )).()
    |> (&Regex.replace(
          ~r/^(Part[ ])(\d+)/m,
          &1,
          fn _, s, n ->
            "#{@components.section}#{n} #{s}#{n}"
          end
        )).()
    |> (&Regex.replace(
          ~r/^(Part[ ])([A-Za-z]+)/m,
          &1,
          fn _, s, n ->
            "#{@components.section}#{UK.Parser.cardinal_as_integer(n)} #{s}#{n}"
          end
        )).()
  end

  def get_sub_section(binary) do
    Regex.replace(
      ~r/^Unterabschnitt[ ](\d+).*/m,
      binary,
      "#{@components.sub_section}\\g{1} \\0"
    )
  end

  def get_article(binary) do
    Regex.replace(
      ~r/^§[ ](\d+[a-z]*).*/m,
      binary,
      "#{@components.article}\\g{1} \\0"
    )
    |> (&Regex.replace(
          ~r/^Section[ ](\d+[a-z]*).*/m,
          &1,
          "#{@components.article}\\g{1} \\0"
        )).()
  end

  def get_para(binary) do
    Regex.replace(
      ~r/^\((\d+)\)[ ].*/m,
      binary,
      "#{@components.para}\\g{1} \\0"
    )
  end

  def get_approval(binary) do
    Regex.replace(
      ~r/^Eingangsformel|^Introductory Clause/m,
      binary,
      "#{@components.approval} \\0"
    )
  end

  #

  def get_appendix(binary) do
    Regex.replace(
      ~r/^((?:Anlage[^n]|Appendix)[ ]?(\d+|(?:#{Legl.roman_regex()})*).*?\n).*?(?=\[::|^(?:Anlage|Appendix)|\Z)/ms,
      binary,
      fn m, a, n ->
        n = Legl.conv_roman_numeral(n)

        cond do
          String.length(m) > 5000 ->
            "#{@components.annex}#{n} #{a}"

          true ->
            "#{@components.annex}#{n} #{m}"
            |> (&Regex.replace(
                  ~r/(?:\r\n|\n)(?=.)/m,
                  &1,
                  " #{Legl.pushpin_emoji()} "
                )).()
        end
      end
    )
  end

  def get_annex(binary) do
    Regex.replace(
      ~r/^((?:Anhang|Annex)[ ]?(\d|(?:#{Legl.roman_regex()})*).*?\n).*?(?=\[::|^(?:Anhang|Annex)|\Z)/ms,
      binary,
      fn m, a, n ->
        n = Legl.conv_roman_numeral(n)

        cond do
          String.length(m) > 5000 ->
            "#{@components.annex}#{n} #{a}"

          true ->
            "#{@components.annex}#{n} #{m}"
            |> (&Regex.replace(
                  ~r/(?:\r\n|\n)(?=.)/m,
                  &1,
                  " #{Legl.pushpin_emoji()} "
                )).()
        end
      end
    )
  end

  def get_footnote(binary) do
    Regex.replace(
      ~r/^Fußnote.*?(?=Nichtamtliches[ ]Inhaltsverzeichnis)/sm,
      binary,
      fn m ->
        "#{@components.footnote} #{m}"
        |> (&Regex.replace(
              ~r/(?:\r\n|\n)(?=.)/m,
              &1,
              " #{Legl.pushpin_emoji()} "
            )).()
      end
    )
  end

  def get_amendment(binary) do
    Regex.replace(
      ~r/^§§.*/m,
      binary,
      "#{@components.amendment} \\0"
    )
  end

  def rm_toc(binary) do
    Regex.replace(
      ~r/^Nichtamtliches Inhaltsverzeichnis\n|^table of contents\n/m,
      binary,
      ""
    )
  end

  def join_sub_paras(binary) do
    Regex.replace(
      ~r/^(\d+[a-z]*\.|[a-z]+\))\n(.*)/m,
      binary,
      "\\g{1} \\g{2}"
    )
  end
end
