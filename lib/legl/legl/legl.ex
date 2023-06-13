defmodule Legl do
  @moduledoc false

  @regex %{
    :aut => %Legl.Regex{
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
    :fin => %Legl.Regex{
      chapter: ~s/^(\\d+)/,
      article: ~s/^(\\d+)/
    },
    :tur => %Legl.Regex{
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
    :uk => %Legl.Regex{
      part: ~s/^(\\d+[ ])(PART|Part)[ ](\\d|[A-Z])+[ ](.*)/,
      part_name: "part",
      heading: ~s/^(\\d+)[ ](.*)/,
      annex: ~s/^SCHEDULE[ ](\\d+)/,
      annex_name: "schedule"
    }
  }

  def regex, do: @regex

  alias Types.Component

  @components Component.components()

  @roman ~s(I II III IV V VI VII VIII IX X XI XII XIII XIV XV)

  @doc """
  "XV XIV XIII XII XI X IX VIII VII VI V IV III II I"
  """
  def roman, do: String.split(@roman) |> Enum.reverse() |> Enum.join(" ")

  def roman_regex(), do: String.split(@roman) |> Enum.reverse() |> Enum.join("|")

  @roman_numerals String.split(@roman)
                  |> Enum.reduce({%{}, 1}, fn x, {map, inc} ->
                    {Map.put(map, x, inc), inc + 1}
                  end)
                  |> Kernel.elem(0)

  @doc """
  A mapping of roman numeral to integer value

  %{
    "I" => 1,
    "II" => 2,
    "III" => 3,
    "IV" => 4,
    "IX" => 9,
    "V" => 5,
    "VI" => 6,
    "VII" => 7,
    "VIII" => 8,
    "X" => 10,
    "XI" => 11,
    "XII" => 12,
    "XIII" => 13,
    "XIV" => 14,
    "XV" => 15
  }

  """
  def roman_numerals(), do: @roman_numerals

  @spec conv_roman_numeral(Integer | String.t()) :: Integer | String.t()
  def conv_roman_numeral(""), do: ""
  def conv_roman_numeral(numeral) when is_integer(numeral), do: numeral

  def conv_roman_numeral(numeral) do
    case Regex.match?(~r/^[0-9]*$/, numeral) do
      true ->
        numeral

      _ ->
        case Map.get(@roman_numerals, numeral) do
          nil -> numeral
          x -> x
        end
    end
  end

  @alphabet "abcdefghijklmnopqrstuvwyyz" |> String.split("", trim: true)

  def conv_alphabetic_classes(letter) do
    letter = String.downcase(letter)

    Enum.find_index(@alphabet, fn x -> x == letter end)
    |> (&(&1 + 1)).()
  end

  @spec txt(any) :: <<_::64, _::_*8>>
  def txt(name) do
    "lib/legl/data_files/csv/#{name}.txt"
  end

  def csv(name) do
    "lib/legl/data_files/csv/#{name}.csv"
  end

  def snippet, do: "lib/legl/data_files/txt/snippet.txt"

  def original, do: "lib/legl/data_files/txt/original.txt"
  def original_annex, do: "lib/legl/data_files/txt/original-annex.txt"

  @annotated Path.absname("lib/legl/data_files/txt/annotated.txt")
  def annotated_annex, do: "lib/legl/data_files/txt/annotated-annex.txt"

  def airtable, do: "lib/legl/data_files/txt/airtable.txt"
  def chapter, do: "lib/legl/data_files/txt/chapter.txt"
  def section, do: "lib/legl/data_files/txt/section.txt"
  def article, do: "lib/legl/data_files/txt/article.txt"
  def sub_article, do: "lib/legl/data_files/txt/sub_article.txt"

  def type, do: "lib/legl/data_files/txt/type.txt"
  def txts, do: "lib/legl/data_files/txt/txts.txt"

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

  def england_flag_emoji() do
    <<0x1F3F4::utf8>> <>
      <<0xE0067::utf8>> <>
      <<0xE0062::utf8>> <>
      <<0xE0065::utf8>> <> <<0xE006E::utf8>> <> <<0xE0067::utf8>> <> <<0xE007F::utf8>>
  end

  def wales_flag_emoji() do
    <<0x1F3F4::utf8>> <>
      <<0xE0067::utf8>> <>
      <<0xE0062::utf8>> <>
      <<0xE0077::utf8>> <> <<0xE006C::utf8>> <> <<0xE0073::utf8>> <> <<0xE007F::utf8>>
  end

  def scotland_flag_emoji() do
    <<0x1F3F4::utf8>> <>
      <<0xE0067::utf8>> <>
      <<0xE0062::utf8>> <>
      <<0xE0073::utf8>> <> <<0xE0063::utf8>> <> <<0xE0074::utf8>> <> <<0xE007F::utf8>>
  end

  def northern_ireland_flag_emoji() do
    <<0x1F3F4::utf8>> <>
      <<0xE0067::utf8>> <>
      <<0xE0062::utf8>> <>
      <<0xE006E::utf8>> <> <<0xE0069::utf8>> <> <<0xE0072::utf8>> <> <<0xE007F::utf8>>
  end

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

  @spec airtable(atom | %{:title_name => any, optional(any) => any}, keyword) :: :ok
  def airtable(country_schema, opts \\ []) when is_list(opts) do
    {:ok, binary} = File.read(@annotated)

    records = Legl.Airtable.Schema.schema(binary, country_schema, opts)

    if Keyword.get(opts, :tdl) == true do
      # tdl = tab delimited
      tdl =
        Enum.map(records, fn x -> conv_map_to_record_string(x, opts) end)
        |> Enum.join("\n")

      File.write(airtable(), tdl)
      manual_paste(tdl, opts)
    end

    records
  end

  defp manual_paste(binary, opts) do
    no_of_lines = Enum.count(String.graphemes(binary), fn x -> x == "\n" end)
    chunk = Keyword.get(opts, :chunk, 200)

    cond do
      no_of_lines < chunk ->
        copy(binary)

      true ->
        String.split(binary, "\n")
        |> Enum.chunk_every(chunk)
        |> Enum.map(fn x -> Enum.join(x, "\n") end)
        |> Enum.reduce("", fn str, acc ->
          copy(str)
          ExPrompt.confirm("Pasted into Airtable?")
          acc <> str
        end)

        :ok
    end
  end

  defp copy(text) do
    port = Port.open({:spawn, "xclip -selection clipboard"}, [])
    Port.command(port, text)
    Port.close(port)
    IO.puts("copied to clipboard: #{String.slice(text, 0, 10)}...")
  end

  @spec conv_map_to_record_string(map, any) :: binary
  def conv_map_to_record_string(%_{} = record, %{fields: fields} = _opts) do
    Map.from_struct(record)
    |> conv_map_to_record_string(fields)
  end

  def conv_map_to_record_string(%{sub: 0} = record, fields) when is_map(record),
    do: conv_map_to_record_string(%{record | sub: ""}, fields)

  def conv_map_to_record_string(record, fields) when is_map(record) do
    fields
    |> Enum.reduce([], fn x, acc -> [Map.get(record, x) | acc] end)
    |> Enum.reduce(
      [],
      fn
        nil, acc -> acc
        x, acc -> [x | acc]
      end
    )
    |> Enum.join("\t")
  end
end
