defmodule FIN.Parser do
  @moduledoc false

  import Legl,
    only: [
      chapter_emoji: 0,
      # sub_chapter_emoji: 0,
      article_emoji: 0,
      # sub_article_emoji: 0,
      # numbered_para_emoji: 0,
      # amendment_emoji: 0,
      annex_emoji: 0
      # pushpin_emoji: 0
      # no_join_emoji: 0
    ]

  # Finnish alphabet: Å, å, Ä, ä, Ä, ä

  @spec timed_parser(String.t()) :: String.t()
  def timed_parser(binary) do
    binary
    |> Legl.Utility.parser_timer(&Legl.Parser.rm_empty_lines/1, "rm_empty_lines")
    |> Legl.Utility.parser_timer(&FIN.Parser.rm_header/1, "rm_header")
    |> Legl.Utility.parser_timer(&FIN.Parser.rm_footer/1, "rm_footer")
    |> Legl.Utility.parser_timer(&FIN.Parser.get_chapter/1, "get_chapter")
    |> Legl.Utility.parser_timer(&FIN.Parser.get_article/1, "get_article")
    |> Legl.Utility.parser_timer(&FIN.Parser.get_annex/1, "get_annex")
    |> Legl.Utility.parser_timer(&Legl.Parser.join/1, "join")
    |> Legl.Utility.parser_timer(&Legl.Parser.rm_tabs/1, "rm_tabs")
  end

  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> Legl.Parser.rm_empty_lines()
    |> rm_thin_space
    |> rm_header()
    |> rm_footer()
    |> get_chapter()
    |> get_article()
    |> get_annex()
    |> Legl.Parser.join("FIN")
    |> Legl.Parser.rm_tabs()
  end

  def rm_header(binary) do
    binary
    # |> (&Regex.replace(
    #      ~r/[[:space:][:print:]åäö›®]+^Katso tekijänoikeudellinen huomautus käyttöehdoissa\.\n/m,
    #      &1,
    #      ""
    #    )).()
    |> (&Regex.replace(
          ~r/^[[:space:][:print:]åäö›®]+Viitetiedot\n[[:blank:]]+På[ ]svenska\n/,
          &1,
          ""
        )).()
  end

  @doc """
  Replace thin spaces with normal spaces

  Thin space sometimes appears in article numbers e.g 1 §
  <<0x2009::utf8>>
  """
  def rm_thin_space(binary), do: String.replace(binary, <<0x2009::utf8>>, " ")

  def rm_footer(binary) do
    binary
    |> (&Regex.replace(~r/Muutossäädösten[ ]voimaantulo[ ]ja[ ]soveltaminen:[\s\S]+/, &1, "")).()
    |> (&Regex.replace(~r/Säädökset[ ]alkuperäisinä[\s\S]+/, &1, "")).()
    |> (&Regex.replace(~r/Sisällysluettelo[\s\S]+/, &1, "")).()
  end

  @doc """
  Parse the chapters of Regulations.

  ## Formats
  1 luku
  """
  def get_chapter(binary),
    do:
      Regex.replace(
        ~r/^(\d+[ ][[:alpha:]]?[ ]?luku.*)\n(.*)/m,
        binary,
        "#{chapter_emoji()}\\g{1} \\g{2}"
      )

  @doc """
  Parse the articles of Regulations.

  ## Formats
  1 §
  """
  def get_article(binary),
    do:
      Regex.replace(
        ~r/^(\d+[ ][[:alpha:]]?[ ]?§.*)\n(.*)/m,
        binary,
        "#{article_emoji()}\\g{1} \\g{2}"
      )

  @doc """
  Parse an annex

  Liite I\nTITLE\n
  Liite I: TITLE\n
  """

  def get_annex(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(Liite)\n(.*)\n/m,
          &1,
          "#{annex_emoji()}\\g{1} \\g{2}\n"
        )).()
    |> (&Regex.replace(
          ~r/^(Liite[ ][[:digit:]]+[[:print:]]*)\n(.*)\n/m,
          &1,
          "#{annex_emoji()}\\g{1} \\g{2}\n"
        )).()
    |> (&Regex.replace(
          ~r/^(Liite[ ][[:alpha:]]+[[:print:]]*)\n(.*)\n/m,
          &1,
          "#{annex_emoji()}\\g{1} \\g{2}\n"
        )).()
    |> (&Regex.replace(
          ~r/^(Liite[ ]?[[:alpha:]]?:[ ])(.*)\n/m,
          &1,
          "#{annex_emoji()}\\g{1} \\g{2}\n"
        )).()
    |> (&Regex.replace(
          ~r/^(Liitteet[ ])([[:alnum:]]+-?[[:alnum:]]*:[ ])(.*)\n/m,
          &1,
          "#{annex_emoji()}\\g{1}\\g{2} \\g{3}\n"
        )).()
    |> (&Regex.replace(
          ~r/^(Liitteet[ ])([[:alnum:]]+j?a?[ ]?[[:alnum:]]*:?[ ])(.*)\n/m,
          &1,
          "#{annex_emoji()}\\g{1}\\g{2} \\g{3}\n"
        )).()
  end
end
