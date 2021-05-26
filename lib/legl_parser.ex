defmodule Legl.Parser do
  @moduledoc false
  import Legl,
    only: [
      part_emoji: 0,
      chapter_emoji: 0,
      sub_chapter_emoji: 0,
      section_emoji: 0,
      heading_emoji: 0,
      annex_heading_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      annex_emoji: 0,
      signed_emoji: 0,
      pushpin_emoji: 0,
      amendment_emoji: 0,
      footnote_emoji: 0
    ]

  @emojis ~s/#{part_emoji()} #{chapter_emoji()} #{sub_chapter_emoji()} #{section_emoji()} #{
            heading_emoji()
          } #{annex_heading_emoji()} #{article_emoji()} #{sub_article_emoji()} #{
            numbered_para_emoji()
          } #{annex_emoji()} #{signed_emoji()} #{pushpin_emoji()} #{amendment_emoji()} #{
            footnote_emoji()
          }/

  def rm_top_line(binary),
    do: Regex.replace(~r/^[ \t]*(?:\r\n|\n)+/, binary, "")

  def rm_empty_lines(binary),
    do:
      Regex.replace(
        ~r/(?:\r\n|\n)+[ \t]*(?:\r\n|\n)+/m,
        binary,
        "\n"
      )

  @doc """
  Join lines unless they are 'marked-up'

  Google translate for Finnish misses some pushpin_emoji.  Therefore,
  these are seperated with spaces
  """
  def join(binary, country \\ nil)

  def join(binary, "UK") do
    emojis = Regex.replace(~r/[ ]/, @emojis, "|")

    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{emojis})/mu,
      binary,
      "#{pushpin_emoji()}"
    )
  end

  def join(binary, _country) do
    emojis = Regex.replace(~r/[ ]/, @emojis, "|")

    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{emojis})/mu,
      binary,
      " #{pushpin_emoji()} "
    )
  end

  def rm_leading_tabs(binary),
    do:
      Regex.replace(
        ~r/^[[:blank:]]+/m,
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

  @doc """
  Removes two or more underline characters

  Underline is used to make underlines in text docs
  """
  def rm_underline_characters(binary) do
    Regex.replace(~r/_{3,}/m, binary, "__")
  end

  @doc """
  Removes everything after and including the `term` that appears at the beginning of a line
  """
  def rm_footer(binary, term),
    do: Regex.replace(~r/^#{term}[\s\S]+/m, binary, "")
end
