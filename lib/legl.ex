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
      sub_article: ~s/^\\((\\d+[a-z]?)\\)/,
      sub_article_name: "unter §",
      annex: ~s/(?:^Anlage[ ]([\\d|A-Z]+)|^(?:Anhang|ANHANG)[ ]+(\\d*[A-Z]*))/,
      annex_name: "anhang"
    },
    :fin => %Regex{
      chapter: ~s/^(\\d+)/,
      article: ~s/^(\\d+)/
    },
    :tur => %Regex{
      part: ~s/^(\\d+)[ ](.*)/,
      part_name: "bölüm_part",
      heading: ~s/^(\\d+)[ ](.*)/,
      heading_name: "başlık_heading",
      article: ~s/^(?:Madde|MADDE)[ ](\\d+)[ ]#{<<226, 128, 147>>}[ ]\\((\\d+)\\)/,
      article_name: "madde_article",
      sub_article: ~s/^\\((\\d+)\\)[ ]/,
      sub_article_name: "madde-paragraf",
      amendment: ~s//
    },
    :uk => %Regex{
      part: ~s/^(\\d+[ ])(PART|Part)[ ](\\d|[A-Z])+[ ](.*)/,
      part_name: "part",
      heading: ~s/^(\\d+)[ ](.*)/,
      annex: ~s/^SCHEDULE[ ](\\d+)/,
      annex_name: "schedule"
    }
  }

  @components ~s(
    content
    part
    chapter
    section
    heading
    article
    sub_article
    numbered_para
    amendment
    annex
    signed
    footnote
    approval
    forms
    form
    table
  )
  @doc """
  A map of components as atoms

  [:content, :part, :chapter, :section, :heading, :article, :sub_article,
  :numbered_para, :amendment, :annex, :signed, :footnote, :approval, :forms,
  :form]
  """
  def component_keys do
    Enum.map(String.split(@components), fn x -> String.to_atom(x) end)
  end

  @doc """
  A map of components with annotations

  ["[::content::]", "[::part::]", "[::chapter::]", "[::section::]",
   "[::heading::]", "[::article::]", "[::sub_article::]", "[::numbered_para::]",
   "[::amendment::]", "[::annex::]", "[::signed::]", "[::footnote::]",
   "[::approval::]", "[::forms::]", "[::form::]"]

  """
  def components do
    Enum.map(String.split(@components), fn x -> "[::" <> x <> "::]" end)
  end

  def components(:regex) do
    Enum.map(String.split(@components), fn x -> x end)
  end

  @doc """
  Escaped for inclusion in regexes

  ["\\[::content::\\]", "\\[::part::\\]", "\\[::chapter::\\]",
   "\\[::section::\\]", "\\[::heading::\\]", "\\[::article::\\]",
   "\\[::sub_article::\\]", "\\[::numbered_para::\\]", "\\[::amendment::\\]",
   "\\[::annex::\\]", "\\[::signed::\\]", "\\[::footnote::\\]",
   "\\[::approval::\\]", "\\[::forms::\\]", "\\[::form::\\]"]

  """
  def components_for_regex() do
    components()
    |> Enum.map(&Elixir.Regex.escape(&1))
  end

  def mapped_components do
    Enum.zip(component_keys(), components())
    |> Enum.reduce(%{}, fn {x, y}, acc -> Map.put(acc, x, y) end)
  end

  def mapped_components_for_regex() do
    Enum.zip(component_keys(), components_for_regex())
    |> Enum.reduce(%{}, fn {x, y}, acc -> Map.put(acc, x, y) end)
  end

  def regex, do: @regex

  @roman ~s(I II III IV V VI VII VIII IX X XI XII XIII XIV XV)

  def roman, do: String.split(@roman) |> Enum.reverse() |> Enum.join(" ")

  @roman_numerals String.split(@roman)
                  |> Enum.reduce({%{}, 1}, fn x, {map, inc} ->
                    {Map.put(map, x, inc), inc + 1}
                  end)
                  |> Kernel.elem(0)

  def roman_numerals(), do: @roman_numerals

  @spec conv_roman_numeral(String.t()) :: Integer
  def conv_roman_numeral(numeral) when is_integer(numeral), do: numeral

  def conv_roman_numeral(numeral) do
    case Map.get(@roman_numerals, numeral) do
      nil -> numeral
      x -> x
    end
  end

  @alphabet "abcdefghijklmnopqrstuvwyyz" |> String.split("", trim: true)

  def conv_alphabetic_classes(letter) do
    letter = String.downcase(letter)

    Enum.find_index(@alphabet, fn x -> x == letter end)
    |> (&(&1 + 1)).()
  end

  def txt(name) do
    "lib/#{name}.txt"
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

  def emojis do
    # https://en.wikipedia.org/wiki/Dingbat

    codes = Enum.map(1..9, &Integer.to_string(&1)) ++ String.split(~s(A B C D E F))

    for n <- ["272", "273"] do
      Enum.map(codes, fn x ->
        {codepoint, _} = Integer.parse(n <> x, 16)
        # <<codepoint::utf8>>
        IO.chardata_to_string([codepoint])
      end)
    end
    |> List.flatten()
  end

  def named_emojis do
    components =
      Enum.map(String.split(@components), fn x -> (x <> "_emoji") |> String.to_atom() end)

    Enum.zip(emojis(), components)
    |> Enum.reduce(%{}, fn {x, y}, acc -> Map.put(acc, y, x) end)
  end

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

  # ⭐ <<226, 173, 144>> star
  def heading_emoji, do: <<0x2B50::utf8>>

  # no entry
  def annex_heading_emoji, do: <<0x26D4::utf8>>

  # traffic light
  def signed_emoji, do: <<0x1F6A5::utf8>>

  # <<240, 159, 147, 140>>
  def pushpin_emoji, do: <<0x1F4CC::utf8>>

  # 👣 footprint <<240, 159, 145, 163>>
  def footnote_emoji, do: <<0x1F463::utf8>>

  # ✅ WHITE HEAVY CHECK MARK <<226, 156, 133>>
  def approval_emoji, do: <<0x2705::utf8>>

  def zero_length_string, do: <<226, 128, 139>>

  def no_join_emoji,
    do:
      ~s/#{chapter_emoji()}#{sub_chapter_emoji()}#{article_emoji()}#{sub_article_emoji()}#{numbered_para_emoji()}#{annex_emoji()}/
end
