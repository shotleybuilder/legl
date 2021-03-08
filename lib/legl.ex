defmodule Legl do
  @moduledoc """
  Filenames

  snippet "lib/snippet.txt"
  original "lib/original.txt" # .html copied from the web
  annotated "lib/annotated.txt" # annotated parsed content for error checking
  airtable "lib/airtable.txt" # parsed content for pasting into Airtable
  chapter "lib/chapter.txt" # chapter heading numbers
  section "lib/section.txt" # section heading numbers
  article "lib/article.txt" # article heading numbers
  article_type "lib/type.txt" # article type tags
  """

  def snippet, do: "lib/snippet.txt"
  def original, do: "lib/original.txt"
  def annotated, do: "lib/annotated.txt"
  def airtable, do: "lib/airtable.txt"
  def chapter, do: "lib/chapter.txt"
  def section, do: "lib/section.txt"
  def article, do: "lib/article.txt"
  def sub_article, do: "lib/sub_article.txt"
  def type, do: "lib/type.txt"
  def txts, do: "lib/txts.txt"

  @doc """
  Emojis
  to get the byte iex> i << 0x1F1F4 :: utf8 >>
  """

  def green_heart, do: <<225, 189, 137, 57>>
  def chapter_emoji, do: <<240, 159, 135, 179>> <> <<240, 159, 135, 180>>
  def sub_chapter_emoji, do: <<226, 155, 148>>
  def article_emoji, do: <<240, 159, 146, 156>>
  def sub_article_emoji, do: <<240, 159, 146, 153>>
  def numbered_para_emoji, do: <<226, 153, 137>>
  def amendment_emoji, do: <<240, 159, 146, 165>>
  def annex_emoji, do: <<225, 189, 131, 68>>

  def pushpin_emoji, do: <<240, 159, 147, 140>>

  def zero_length_string, do: <<226, 128, 139>>
end
