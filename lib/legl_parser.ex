defmodule Legl.Parser do
  @moduledoc false
  import Legl,
    only: [
      part_emoji: 0,
      chapter_emoji: 0,
      sub_chapter_emoji: 0,
      heading_emoji: 0,
      annex_heading_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      annex_emoji: 0,
      signed_emoji: 0,
      pushpin_emoji: 0,
      amendment_emoji: 0
    ]

  def rm_empty_lines(binary),
    do:
      Regex.replace(
        ~r/(?:\r\n|\n)+[ \t]*(?:\r\n|\n)+/m,
        binary,
        "\n"
      )

  @doc """
  Join lines unless they are 'marked-up'
  """
  def join(binary) do
    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{part_emoji()}|#{heading_emoji()}|#{chapter_emoji()}|#{
        sub_chapter_emoji()
      }|#{article_emoji()}|#{sub_article_emoji()}|#{numbered_para_emoji()}|#{annex_emoji()}|#{
        annex_heading_emoji()
      }|#{signed_emoji()}|#{amendment_emoji()})/mu,
      binary,
      "#{pushpin_emoji()}"
    )
  end

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
