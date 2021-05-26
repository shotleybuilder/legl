defmodule Legl do
  @moduledoc false

  alias Legl.Regex

  @regex %{
    :aut => %Regex{
      chapter: ~s/^Artikel[ ](\\d+)|^([A-Z]+)\.?[ ]+HAUPTSTÜCK/,
      chapter_name: "artikel",
      section: ~s/(\\d+[a-z]?)/,
      # abschnitt == sektion == section
      section_name: "sektion",
      article: ~s/^§[ ](\\d+[a-z]?)/,
      article_name: "§",
      sub_article_name: "unter §",
      annex: ~s/(?:^Anlage[ ]([\\d|A-Z]+)|^(?:Anhang|ANHANG)[ ]+(\\d*[A-Z]*))/,
      annex_name: "anhang"
    },
    :fin => %Regex{
      chapter: ~s/^(\\d+)/,
      article: ~s/^(\\d+)/
    },
    :tur => %Regex{
      part: ~s/^[A-Z]+/,
      part_name: "bölüm",
      article: ~s/^Madde[ ](\\d+)/,
      article_name: "madde",
      amendment: ~s//
    },
    :uk => %Regex{
      annex: ~s/^SCHEDULE[ ](\\d+)/,
      annex_name: "schedule"
    }
  }

  def regex, do: @regex

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

  @alphabet "abcdefghijklmnopqrstuvwyyz" |> String.split("", trim: true)

  @spec conv_roman_numeral(String.t()) :: Integer
  def conv_roman_numeral(numeral) when is_integer(numeral), do: numeral

  def conv_roman_numeral(numeral) do
    case Map.get(@roman_numerals, numeral) do
      nil -> numeral
      x -> x
    end
  end

  def conv_alphabetic_classes(letter) do
    letter = String.downcase(letter)

    Enum.find_index(@alphabet, fn x -> x == letter end)
    |> (&(&1 + 1)).()
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

  # bomb 💣
  def content_emoji, do: <<0x1F4A3::utf8>>

  # <<240, 159, 135, 179>> <> <<240, 159, 135, 180>> #norwegian flag
  def nor_flag_emoji, do: <<0x1F1F3::utf8>> <> <<0x1F1F1::utf8>>

  def uk_flag_emoji, do: <<0x1F1EC::utf8>> <> <<0x1F1E7::utf8>>

  # 🎈 balloon
  def part_emoji, do: <<0x1F388::utf8>>

  # 🧱 brick <<240, 159, 167, 177>>
  def chapter_emoji, do: <<0x1F9F1::utf8>>

  # <<226, 156, 141>> # writing hand
  def sub_chapter_emoji, do: <<0x270D::utf8>>

  # 💥 collision
  def section_emoji, do: <<0x1F4A5::utf8>>

  # 💚 <<240, 159, 146, 156>> # green heart
  def article_emoji, do: <<0x1F49A::utf8>>

  # ❤ <<240, 159, 146, 153>> # red heart
  def sub_article_emoji, do: <<0x2764::utf8>>

  # <<240, 159, 146, 156>> # spade
  def numbered_para_emoji, do: <<0x2660::utf8>>

  # <<240, 159, 146, 165>> # club
  def amendment_emoji, do: <<0x2663::utf8>>

  # ✊ clenched fist
  def annex_emoji, do: <<0x270A::utf8>>

  # star
  def heading_emoji, do: <<0x2B50::utf8>>

  # no entry
  def annex_heading_emoji, do: <<0x26D4::utf8>>

  # traffic light
  def signed_emoji, do: <<0x1F6A5::utf8>>

  # <<240, 159, 147, 140>>
  def pushpin_emoji, do: <<0x1F4CC::utf8>>

  # 👣 footprint <<240, 159, 145, 163>>
  def footnote_emoji, do: <<0x1F463::utf8>>

  def zero_length_string, do: <<226, 128, 139>>

  def no_join_emoji,
    do:
      ~s/#{chapter_emoji()}#{sub_chapter_emoji()}#{article_emoji()}#{sub_article_emoji()}#{
        numbered_para_emoji()
      }#{annex_emoji()}/
end
