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
      pushpin_emoji: 0
      # no_join_emoji: 0
    ]

  # Turkish alphabet: Ç, ç, Ş, ş, Ü, ü
  # Ç - <<195, 135>>
  # ç - <<195, 167>>
  # Ş, ş, Ü, ü

  @part_names ~s(BİRİNCİ İKİNCİ ÜÇÜNCÜ DÖRDÜNCÜ BEŞİNCİ ALTINCI YEDİNCİ SEKİZİNCİ DOKUZUNCU)

  @doc """
  Parses .pdf text copied from https://www.mevzuat.gov.tr/MevzuatMetin

  """
  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> clean_original()
    |> get_part()
    |> get_heading()
    |> get_article()
    |> get_ek_fikra()
    |> get_degisik()
    |> get_mulga()
    |> get_revision()
    |> numeraled()
    |> lettered()
    |> join_sentences()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  @doc false
  @spec clean_original(String.t()) :: String.t()
  def clean_original(binary) do
    binary
    |> Legl.Parser.rm_empty_lines()
    |> Legl.Parser.rm_leading_tabs()
    |> Legl.Parser.rm_underline_characters()
    |> rm_page_numbers()
    # |> rm_footer()
    |> (fn x ->
          File.write(Legl.original(), x)
          x
        end).()
  end

  def rm_page_numbers(binary) do
    Regex.replace(~r/^(\d{1,4})-?\d*\n/m, binary, "")
  end

  def get_part(binary) do
    part_names = Regex.replace(~r/[ ]/, @part_names, "|")

    binary
    |> (&Regex.replace(
          ~r/^((?:#{part_names})[ ]BÖLÜM)\n(.*)/m,
          &1,
          "#{part_emoji()}\\g{1} \\g{2}"
        )).()
  end

  def get_heading(binary) do
    Regex.replace(
      ~r/^(.*)\n(Madde[ ]\d+)/m,
      binary,
      "#{heading_emoji()}\\g{1}\n\\g{2}"
    )
  end

  def get_article(binary) do
    Regex.replace(
      ~r/^Madde[ ]\d+/m,
      binary,
      "#{article_emoji()}\\0"
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

  def get_revision(binary) do
    Regex.replace(
      ~r/^\(\d+\)[ ]\d{1,2}\/\d{1,2}\/\d{4}[ ]/m,
      binary,
      "#{amendment_emoji()}\\0"
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
