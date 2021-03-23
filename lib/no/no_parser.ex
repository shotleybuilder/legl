defmodule NO.Parser do
  @moduledoc false
  import Legl,
    only: [
      chapter_emoji: 0,
      sub_chapter_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      amendment_emoji: 0,
      annex_emoji: 0,
      pushpin_emoji: 0
      # no_join_emoji: 0
    ]

  @spec parser(String.t(), :boolean) :: String.t()
  def parser(binary, english?) do
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
    # |> join_special()
    |> join()
    |> rm_tabs()
    |> rm_footer()
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
  def get_chapter(binary),
    do:
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
  def get_sub_chapter(binary),
    do:
      Regex.replace(
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
  def get_article(binary),
    do:
      Regex.replace(
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
  def get_sub_article(binary),
    do:
      Regex.replace(
        ~r/^(§[ ]+)(\d*\-)?(\d+)[ ]?([a-z]+)\.[ ]?/m,
        binary,
        "#{sub_article_emoji()}\\g{1}\\g{2}\\g{3} \\g{4}\. "
      )

  @doc """
  Numbered paragraph
  """
  def get_numbered_paragraph(binary),
    do:
      Regex.replace(
        ~r/^(\(\d+\))/m,
        binary,
        "#{numbered_para_emoji()}\\g{1}"
      )

  @doc """
  Match an Amendment
  """
  def get_amendment({binary, false}),
    do: {
      Regex.replace(
        ~r/(^\d+)[ \t]+([Jf.|Kapittel|Kapitlene|Endret|Tilføyd|Vedlegg|Opphevet|Hele|Drette|Overskrift endret|Henvisningen].*)/m,
        binary,
        "\n#{amendment_emoji()}\\g{1} \\g{2}\n\n"
      ),
      false
    }

  def get_amendment({binary, true}),
    do: {
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
  def get_annex(binary),
    do:
      Regex.replace(
        ~r/^(((?:Vedlegg)|(?:Annex))\.?[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3}|\d+):?\.?[ ]+[A-ZÅØ].*)/m,
        binary,
        "#{annex_emoji()}\\g{1}"
      )

  @doc """
  Remove empty lines
  """
  def rm_empty(binary),
    do:
      Regex.replace(
        ~r/(?:\r\n|\n)+[ \t]*(?:\r\n|\n)+/m,
        binary,
        "\n"
      )

  @doc """
  Join lines
  """
  def join(binary) do
    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{chapter_emoji()}|#{sub_chapter_emoji()}|#{article_emoji()}|#{
        sub_article_emoji()
      }|#{numbered_para_emoji()}|#{annex_emoji()})/mu,
      binary,
      "#{pushpin_emoji()}"
    )
  end

  def join_special(binary),
    do:
      Regex.replace(
        ~r/(?:\r\n|\n)(?=∑)/mu,
        binary,
        "\\g{1}"
      )

  @doc """
  Removes the footer
  """
  def rm_footer(binary),
    do:
      Regex.replace(
        ~r/(?:\r\n|\n)^Brukerveiledning.*\n/m,
        binary,
        ""
      )

  @doc """
  Remove tabs because this conflicts with Airtables use of tabs to separate into fields
  """
  def rm_tabs(binary),
    do:
      Regex.replace(
        ~r/\t/m,
        binary,
        "     "
      )
end
