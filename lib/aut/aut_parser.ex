defmodule AUT.Parser do
  @moduledoc false

  import Legl,
    only: [
      content_emoji: 0,
      chapter_emoji: 0,
      section_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      # numbered_para_emoji: 0,
      # amendment_emoji: 0,
      annex_emoji: 0
      # pushpin_emoji: 0
      # no_join_emoji: 0
    ]

  # Austrian alphabet: Ä, ä, Ö, ö, Ü, ü, ẞ, ß

  @doc """
  Parses text copied from ris.bka.gv.at/GeltendeFassung.wxe

  """
  @spec parser_latest(String.t()) :: String.t()
  def parser_latest(binary) do
    binary
    |> clean_original()
    |> get_anhang()
    |> rm_anhang_content()
    |> get_haupstuck()
    |> get_abschnitt()
    |> get_article()
    |> get_sub_article()
    |> join_numbered()
    |> join_parenthesised()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  @doc false
  @spec clean_original(String.t()) :: String.t()
  def clean_original(binary) do
    binary
    |> Legl.Parser.rm_top_line()
    |> Legl.Parser.rm_empty_lines()
    |> Legl.Parser.rm_leading_tabs()
    |> Legl.Parser.rm_underline_characters()
    |> rm_header()
    |> rm_footer()
    |> AUT.TOC.rm_toc()
    |> rm()
    |> (fn x ->
          File.write(Legl.original(), x)
          x
        end).()
  end

  def rm_header(binary), do: Regex.replace(~r/.*(Langtitel)$/ms, binary, "\\g{1}")

  def rm_footer(binary), do: Regex.replace(~r/^Zum[ ]Seitenanfang[\s\S]+/m, binary, "")

  def rm(binary) do
    binary
    |> (&Regex.replace(~r/^verordnet:$\n/m, &1, "")).()
    |> (&Regex.replace(~r/^§[ ]\d+[a-z]?$\n/m, &1, "")).()
    |> (&Regex.replace(~r/^Text$\n/m, &1, "")).()
    |> (&Regex.replace(~r/^Anl\.[ ]\d+$\n/m, &1, "")).()
  end

  @doc """
  Parses text copied from https://www.ris.bka.gv.at/Dokumente/BgblAuth/

  deprecated: "Use AUT.Parser.parser_latest/1 instead"
  """
  @deprecated "Use AUT.Parser.parser_latest/1 instead"
  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> Legl.Parser.rm_top_line()
    |> Legl.Parser.rm_empty_lines()
    |> Legl.Parser.rm_leading_tabs()
    |> Legl.Parser.rm_underline_characters()
    |> AUT.TOC.mark_up_contentz()
    |> get_artikel()
    |> get_abschnitt()
    |> get_article()
    |> get_sub_article()
    |> join_numbered()
    |> join_parenthesised()
    |> append_annex()
    |> String.replace("#{content_emoji()}", "")
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  @doc """
  Haupstück means main piece in English

    From this:
    I. HAUPTSTÜCK
    Heading

    To this:
    🧱I. HAUPTSTÜCK Heading

    OR

    From this:
    I. HAUPTSTÜCK: Heading

    To this:
    🧱I. HAUPTSTÜCK: Heading
  """
  @spec get_haupstuck(String.t()) :: String.t()
  def get_haupstuck(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(\d*[A-Z]*\.[ ]+(?:Haupstück|HAUPTSTÜCK))\n(.*)|^(\d*[A-Z]*\.[ ]+(?:Haupstück|HAUPTSTÜCK):?[ ])(.*)/m,
          &1,
          "#{chapter_emoji()}\\g{1}\\g{3} \\g{2}\\g{4}"
        )).()
  end

  def get_artikel(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(Artikel[ ]\d+)\n/m,
          &1,
          "#{chapter_emoji()}\\g{1} "
        )).()
  end

  @doc """
  Abschnitt means section in English

    From this:
    1. Abschnitt
    Heading

    To this:
    💥1. Abschnitt Heading

    OR

    From this:
    1. Abschnitt: Heading

    To this:
    💥1. Abschnitt: Heading
  """
  @spec get_abschnitt(String.t()) :: String.t()
  def get_abschnitt(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(\d+\.[ ](?:Abschnitt|ABSCHNITT))\n(.*)|^(\d+\.[ ](?:Abschnitt|ABSCHNITT):[ ])(.*)|^((?:Abschnitt|ABSCHNITT|Unterabschnitt)[ ]\d+[a-z]*:)(.*)|^((?:Abschnitt|ABSCHNITT|Unterabschnitt)[ ]\d+[a-z]*)\n(.*)/m,
          &1,
          "#{section_emoji()}\\g{1}\\g{3}\\g{5}\\g{7} \\g{2}\\g{4}\\g{6}\\g{8}"
        )).()
  end

  @doc """
  Parses the articles with the article heading

  Form this:
  Heading
  § 1.

  To this:
  § 1. Heading
  """
  @spec get_article(String.t()) :: String.t()
  def get_article(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(.*)\n(§[ ]\d+[a-z]?\.)\n/m,
          &1,
          "#{article_emoji()}\\g{2} \\g{1}\n"
        )).()
  end

  @doc """
  Parses the articles with the article heading

  Form this:
  Heading
  § 1.

  To this:
  § 1. Heading
  """
  @spec get_sub_article(String.t()) :: String.t()
  def get_sub_article(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(\(\d+[a-z]?\)[ ].*)/m,
          &1,
          "#{sub_article_emoji()}\\g{1}"
        )).()
  end

  @doc """
  Parses the annex headings

  Form this:
  Anhang I
  Heading

  To this:
  Anhang I Heading
  """
  @spec get_anhang(String.t()) :: String.t()
  def get_anhang(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(ANHANG|Anhang|Anlage)([ ][A-Z]*\d*\/?\d*)\n(.*)|^(ANHANG|Anhang|Anlage)([ ][A-Z]*\d*\/?\d*)(.*)/m,
          &1,
          "#{annex_emoji()}\\g{1}\\g{2} \\g{3} \\g{4}\\g{5} \\g{6}"
        )).()
  end

  @doc """
  Parses the content between the Anhang headings
  Form this:
  ✊Anhang I Heading
  Content
  ✊Anhang II Heading
  Content

  To this:
  ✊Anhang I Heading
  ✊Anhang II Heading
  """
  @spec rm_anhang_content(String.t()) :: String.t()
  def rm_anhang_content(binary) do
    cond do
      Regex.match?(
        ~r/(#{annex_emoji()}.*\n)[^#{annex_emoji()}][\s\S]+(#{annex_emoji()}.*\n)/U,
        binary
      ) ->
        Regex.replace(
          ~r/(#{annex_emoji()}.*\n)[^#{annex_emoji()}][\s\S]+(#{annex_emoji()}.*\n)/U,
          binary,
          "\\g{1}\\g{2}"
        )
        |> rm_anhang_content()

      Regex.match?(
        ~r/(#{annex_emoji()}.*)\n[^#{annex_emoji()}][\s\S]+$/,
        binary
      ) ->
        Regex.replace(
          ~r/(#{annex_emoji()}.*)\n[^#{annex_emoji()}][\s\S]+$/,
          binary,
          "\\g{1}"
        )

      true ->
        binary
    end
  end

  @doc """
  Joins numbered sub-paragraphs

  From this:
  1.
  Subject

  To this:
  1. Subject
  """
  @spec join_numbered(String.t()) :: String.t()
  def join_numbered(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(\d+\.)\n(.*)\n/m,
          &1,
          "\\g{1} \\g{2}\n"
        )).()
  end

  @doc """
  Joins lettered sub-paragraphs

  From this:
  a)
  Subject

  To this:
  a) Subject
  """
  @spec join_numbered(String.t()) :: String.t()
  def join_parenthesised(binary) do
    binary
    |> (&Regex.replace(
          ~r/^([a-z]\))\n(.*)\n/m,
          &1,
          "\\g{1} \\g{2}\n"
        )).()
  end

  @doc """
  Gets the Annex / Appendix from the Contents and appends

  Anhang or Anlage
  """
  def append_annex(binary) do
    binary
    |> (&Regex.scan(
          ~r/^#{content_emoji()}An[hl]a[an][eg]:?[ ][\d|A-Z]+.*/m,
          &1
        )).()
    |> IO.inspect()
    |> Enum.reduce(binary, fn [str], acc -> acc <> "\n#{annex_emoji()}" <> str end)

    # |> (&Regex.replace(
    #      ~r/^Anlage[ ]\d+[ ].*\n/m,
    #      &1,
    #      ""
    #    )).()
  end
end
