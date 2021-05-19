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

  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> Legl.Parser.rm_top_line()
    |> Legl.Parser.rm_empty_lines()
    |> Legl.Parser.rm_leading_tabs()
    |> mark_up_contents_heading()
    |> mark_up_contents()
    |> get_artikel()
    |> get_abschnitt()
    |> get_article()
    |> get_sub_article()
    |> join_numbered()
    |> join_parenthasised()
    |> append_annex()
    |> String.replace("#{content_emoji()}", "")
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  def mark_up_contents_heading(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(Inhaltsverzeichnis.*)/m,
          &1,
          "#{content_emoji()}\\g{1}"
        )).()
  end

  def mark_up_contents(binary) do
    case Regex.match?(
           ~r/^(#{content_emoji()}[§|\d|Inhaltsverzeichnis].*)\n(§[ ]\d+\.?|Anhang[ ]\d+|\d+\.[ ]Abschnitt|Anlage[ ][A-Z]+)\n(.*)/m,
           binary
         ) do
      true ->
        Regex.replace(
          ~r/^(#{content_emoji()}[§|\d|Inhaltsverzeichnis].*)\n(§[ ]\d+\.?|Anhang[ ]\d+|\d+\.[ ]Abschnitt|Anlage[ ][A-Z]+)\n(.*)/m,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2} \\g{3}"
        )
        |> mark_up_contents()

      false ->
        case Regex.match?(
               ~r/^(#{content_emoji()}[Anlage|Teil].*)\n(?:(Anlage[ ][A-Z]+)\n(.*)|(Teil[ ]\d+:)(.*))/m,
               binary
             ) do
          true ->
            Regex.replace(
              ~r/^(#{content_emoji()}[Anlage|Teil].*)\n(?:(Anlage[ ][A-Z]+)\n(.*)|(Teil[ ]\d+:)(.*))/m,
              binary,
              "\\g{1}\n#{content_emoji()}\\g{2}\\g{4} \\g{3}\\g{5}"
            )
            |> mark_up_contents()

          false ->
            binary
        end
    end
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
    1. Abschnitt Heading
  """
  @spec get_abschnitt(String.t()) :: String.t()
  def get_abschnitt(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(\d+\.[ ]Abschnitt)\n(.*)\n/m,
          &1,
          "#{section_emoji()}\\g{1} \\g{2}\n"
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
          ~r/^(.*)\n(§[ ]\d+\.)\n/m,
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
          ~r/^(\(\d+\)[ ].*)\n/m,
          &1,
          "#{sub_article_emoji()}\\g{1}\n"
        )).()
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
  def join_parenthasised(binary) do
    binary
    |> (&Regex.replace(
          ~r/^([a-z]\))\n(.*)\n/m,
          &1,
          "\\g{1} \\g{2}\n"
        )).()
  end

  @doc """
  Gets the Annex / Appendix from the Contents and appends


  """
  def append_annex(binary) do
    binary
    |> (&Regex.scan(
          ~r/^#{content_emoji()}Anlage[ ][\d|A-Z]+[ ].*|#{content_emoji()}Anhang[ ]\d+.*/m,
          &1
        )).()
    # |> IO.inspect()
    |> Enum.reduce(binary, fn [str], acc -> acc <> "\n#{annex_emoji()}" <> str end)

    # |> (&Regex.replace(
    #      ~r/^Anlage[ ]\d+[ ].*\n/m,
    #      &1,
    #      ""
    #    )).()
  end
end
