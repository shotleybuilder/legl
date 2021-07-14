defmodule TUR.Parser do
  @moduledoc false

  import Legl,
    only: [
      part_emoji: 0,
      heading_emoji: 0,
      content_emoji: 0,
      chapter_emoji: 0,
      section_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      # numbered_para_emoji: 0,
      amendment_emoji: 0,
      annex_emoji: 0,
      pushpin_emoji: 0,
      footnote_emoji: 0
      # no_join_emoji: 0
    ]

  # Turkish alphabet: Ç, ç, İ, Ş, ş, Ö, ö, Ü, ü
  # Ç, İ, Ş, Ö, Ü
  # Ç - <<195, 135>>
  # ç - <<195, 167>>
  # Ş, ş, Ü, ü

  @part_names ~s(BİRİNCİ İKİNCİ ÜÇÜNCÜ DÖRDÜNCÜ BEŞİNCİ ALTINCI YEDİNCİ SEKİZİNCİ DOKUZUNCU)
  @part_numbers String.split(@part_names)
                |> Enum.reduce({%{}, 1}, fn x, {map, inc} ->
                  {Map.put(map, x, inc), inc + 1}
                end)
                |> Kernel.elem(0)
  @big_hyphen <<226, 128, 147>>
  @doc """
  Builds a map of the Turkish name => numerical value

  %{
   "ALTINCI" => 6,
   "BEŞİNCİ" => 5,
   "BİRİNCİ" => 1,
   "DOKUZUNCU" => 9,
   "DÖRDÜNCÜ" => 4,
   "SEKİZİNCİ" => 8,
   "YEDİNCİ" => 7,
   "ÜÇÜNCÜ" => 3,
   "İKİNCİ" => 2
  }

  """
  def part_numbers() do
    String.split(@part_names)
    |> Enum.reduce({%{}, 1}, fn x, {map, inc} ->
      {Map.put(map, x, inc), inc + 1}
    end)
    |> Kernel.elem(0)
  end

  def part_number(text) do
    case Map.get(@part_numbers, text) do
      nil -> ""
      x -> Integer.to_string(x)
    end
  end

  @doc """
  Parses .pdf text copied from https://www.mevzuat.gov.tr/MevzuatMetin

  """
  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> get_part()
    |> get_chapter()
    |> get_heading()
    |> get_article()
    |> get_sub_article()
    |> get_ek_fikra()
    |> get_degisik()
    |> get_mulga()
    |> get_gecici_madde()
    |> get_footnote()
    # |> numeraled()
    # |> lettered()
    # |> join_sentences()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  @doc false
  def clean_original("CLEANED\n" <> binary) do
    IO.write("Clean\n")
    binary
  end

  @spec clean_original(String.t()) :: String.t()
  def clean_original(binary) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> Legl.Parser.rm_leading_tabs()
      |> Legl.Parser.rm_underline_characters()
      |> rm_page_numbers()

    # |> rm_footer()

    File.write(Legl.original(), binary)

    clean_original(binary)
  end

  def rm_page_numbers(binary) do
    Regex.replace(~r/^(\d{1,4})-?\d*\n/m, binary, "")
  end

  def get_part(binary) do
    part_names = Regex.replace(~r/[ ]/, @part_names, "|")

    binary
    |> (&Regex.replace(
          ~r/^((#{part_names})[ ]KISIM)\n(.*)/m,
          &1,
          fn _, title, part, rem -> part_emoji() <> part_number(part) <> " #{title} #{rem}" end
        )).()
  end

  def get_chapter(binary) do
    part_names = Regex.replace(~r/[ ]/, @part_names, "|")

    binary
    |> (&Regex.replace(
          ~r/^((#{part_names})[ ]BÖLÜM)\n(.*)/m,
          &1,
          fn _, title, part, rem -> chapter_emoji() <> part_number(part) <> " #{title} #{rem}" end
        )).()
  end

  def get_heading(binary) do
    Regex.replace(
      ~r/^(.*)\n((?:Madde|MADDE)[ ](\d+))/m,
      binary,
      fn _, heading, article, article_number ->
        "#{heading_emoji()}#{article_number} #{heading}\n#{article}"
      end
      # "#{heading_emoji()}\\g{1}\n\\g{2}"
    )
  end

  def get_article(binary) do
    Regex.replace(
      ~r/^(?:Madde|MADDE)[ ](\d+)\/?([A-Z]?)[ ]?[#{@big_hyphen}|-]?[ ]*\(?(\d*)/m,
      binary,
      fn
        m, art_num, "", "" ->
          article_emoji() <> "#{art_num} " <> m

        m, art_num, "", para_num ->
          article_emoji() <> "#{art_num}_#{para_num} " <> m

        m, art_num, amd_num, "" ->
          article_emoji() <> "#{art_num}#{String.downcase(amd_num)} " <> m

        m, art_num, amd_num, para_num ->
          article_emoji() <> "#{art_num}#{String.downcase(amd_num)}_#{para_num} " <> m
      end
    )
  end

  def get_sub_article(binary) do
    Regex.replace(
      ~r/^\((\d+)\)[ ]/m,
      binary,
      "#{sub_article_emoji}\\g{1} \\0"
    )
  end

  def get_ek_fikra(binary) do
    Regex.replace(
      ~r/^\(Ek[ ](?:fıkra|cümleler)[ ]?:[ ]?\d{1,2}\/\d{1,2}\/\d{4}-\d+\/\d+[ ]md\./m,
      binary,
      "#{sub_article_emoji}\\0"
    )
  end

  def get_degisik(binary) do
    Regex.replace(
      ~r/^\(Değişik[ ]?.+:[ ]\d{1,2}\/\d{1,2}\/\d{1,4}-[A-Z]*-?\d+\/\d+[ ]md\.\)/m,
      binary,
      "#{sub_article_emoji}\\0"
    )
  end

  def get_mulga(binary) do
    Regex.replace(
      ~r/^\(Mülga/m,
      binary,
      " #{pushpin_emoji()} \\0"
    )
  end

  def get_gecici_madde(binary) do
    Regex.replace(
      ~r/^(?:GEÇİCİ MADDE|Geçici Madde)[ ](\d+)[ ]*?(?:#{@big_hyphen}|-)[ ]+\(?(\d*).*/m,
      binary,
      fn
        m, art_num, para_num ->
          case is_para_num(para_num) do
            "" -> "#{amendment_emoji}#{art_num} #{m}"
            _ -> "#{amendment_emoji}#{art_num}_#{para_num} #{m}"
          end
      end
    )
  end

  defp is_para_num(str) do
    case Integer.parse(str) do
      :error -> ""
      _ -> str
    end
  end

  def get_footnote(binary) do
    Regex.replace(
      ~r/^\(\d+\)[ ]\d{1,2}\/\d{1,2}\/\d{4}[ ]/m,
      binary,
      "#{footnote_emoji()}\\0"
    )
  end

  def lettered(binary) do
    Regex.replace(
      ~r/^[a-zı]+\)[ ]/m,
      binary,
      " #{pushpin_emoji()} \\0"
    )
  end

  def numeraled(binary) do
    Regex.replace(
      ~r/^(X{0,1})(IX|IV|V?I{0,3})(\.?-?[ ])/m,
      binary,
      " #{pushpin_emoji()} \\g{1}\\g{2}\\g{3}"
    )
  end

  def join_sentences(binary) do
    Regex.replace(
      ~r/([a-z,çışöü”])\n([a-zçışöü1-9“])/m,
      binary,
      "\\g{1} \\g{2}"
    )
  end
end
