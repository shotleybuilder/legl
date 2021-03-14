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

  @roman_numerals %{
    "I" => 1,
    "II" => 2,
    "III" => 3,
    "IV" => 4,
    "V" => 5,
    "VI" => 6,
    "VII" => 7,
    "VIII" => 8,
    "IX" => 9,
    "X" => 10
  }

  @spec conv_roman_numeral(String.t()) :: Integer
  def conv_roman_numeral(numeral) when is_integer(numeral), do: numeral

  def conv_roman_numeral(numeral) do
    case Map.get(@roman_numerals, numeral) do
      nil -> numeral
      x -> x
    end
  end

  def snippet, do: "lib/snippet.txt"

  def original, do: "lib/original.txt"
  def original_annex, do: "lib/original-annex.txt"

  def annotated, do: "lib/annotated.txt"
  def annotated_annex, do: "lib/annotated-annex.txt"

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
  def uk_flag_emoji, do: <<0x1F1EC::utf8>> <> <<0x1F1E7::utf8>>

  # balloon
  def part_emoji, do: <<0x1F388::utf8>>
  # <<240, 159, 135, 179>> <> <<240, 159, 135, 180>> #norwegian flag
  def chapter_emoji, do: <<0x1F1F3::utf8>> <> <<0x1F1F1::utf8>>
  # <<226, 156, 141>> # writing hand
  def sub_chapter_emoji, do: <<0x270D::utf8>>
  # <<240, 159, 146, 156>> # green heart
  def article_emoji, do: <<0x1F49A::utf8>>
  # #<<240, 159, 146, 153>> # red heart
  def sub_article_emoji, do: <<0x2764::utf8>>
  # <<240, 159, 146, 156>> # spade
  def numbered_para_emoji, do: <<0x2660::utf8>>
  # <<240, 159, 146, 165>> # club
  def amendment_emoji, do: <<0x2663::utf8>>
  # clenched fist
  def annex_emoji, do: <<0x270A::utf8>>
  # star
  def heading_emoji, do: <<0x2B50::utf8>>
  # no entry
  def annex_heading_emoji, do: <<0x26D4::utf8>>
  # traffic light
  def signed_emoji, do: <<0x1F6A5::utf8>>

  # <<240, 159, 147, 140>>
  def pushpin_emoji, do: <<0x1F4CC::utf8>>

  def zero_length_string, do: <<226, 128, 139>>

  def no_join_emoji,
    do:
      ~s/#{chapter_emoji()}#{sub_chapter_emoji()}#{article_emoji()}#{sub_article_emoji()}#{
        numbered_para_emoji()
      }#{annex_emoji()}/
end
