defmodule RUS.Parser do
  @moduledoc false

  # RUSkish alphabet: Ç, ç, İ, Ş, ş, Ö, ö, Ü, ü
  # Ç, İ, Ş, Ö, Ü
  # Ç - <<195, 135>>
  # ç - <<195, 167>>
  # Ş, ş, Ü, ü

  # @emojis Legl.named_emojis()
  alias Types.Component
  @components %Component{}

  def component_for_regex(name) when is_atom(name) do
    Legl.mapped_components() |> Map.get(name) |> Regex.escape()
  end

  @part_names ~s(ПЕРВАЯ СЕКОНД ТРЕТЬЯ ЧЕТВЕРТАЯ ФИФТХ ШЕСТАЯ)
  @part_numbers String.split(@part_names)
                |> Enum.reduce({%{}, 1}, fn x, {map, inc} ->
                  {Map.put(map, x, inc), inc + 1}
                end)
                |> Kernel.elem(0)

  @roman_numerals Regex.replace(~r/[ ]/, Legl.roman(), "|")
  @doc """
  Builds a map of the Russian name => numerical value


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

  @doc false
  @spec clean_original(String.t(), String.t()) :: String.t()
  def clean_original("CLEANED\n" <> binary, _) do
    binary
    |> (&IO.puts("cleaned: #{String.slice(&1, 0, 10)}...")).()

    binary
  end

  def clean_original(binary, source) do
    binary =
      case source do
        "cntd" ->
          binary
          |> Legl.Parser.rm_empty_lines()
          |> rm_header()
          |> rm_footer()
          |> rm_makers_clause()
          |> (&Kernel.<>("CLEANED", &1)).()
          |> Legl.Parser.rm_leading_tabs()

        _ ->
          binary
          |> Legl.Parser.rm_empty_lines()
          |> (&Kernel.<>("CLEANED\n", &1)).()
          |> Legl.Parser.rm_leading_tabs()
      end

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    clean_original(binary, nil)
  end

  def rm_header(binary) do
    Regex.replace(
      ~r/.*?Попробовать бесплатно/s,
      binary,
      ""
    )
  end

  def rm_makers_clause(binary) do
    Regex.replace(
      ~r/^_+\n.*\n-[ ]Примечание изготовителя базы данных\.\n_+\n/m,
      binary,
      ""
    )
  end

  def rm_footer(binary) do
    binary
    |> (&Regex.replace(
          ~r/\nРедакция документа с учетом.*|\nЭлектронный текст документа.*|\nТекст документа.*/s,
          &1,
          ""
        )).()

    # |> (&Regex.replace(
    #      ~r/^(регистрационный[ ]N[ ]\d+).*/sm,
    #      &1,
    #      "\\g{1}"
    #    )).()
  end

  @doc """
  Parses .pdf text copied from https://www.mevzuat.gov.tr/MevzuatMetin

  """
  @spec parser(String.t(), Atom) :: String.t()
  def parser(binary, pattern) do
    binary
    |> get_amendments()
    |> get_title()
    |> get_part()
    |> get_chapter()
    |> get_section()
    |> get_annex()
    |> get_form()
    |> get_form_para()
    |> get_article(pattern)
    |> get_para()
    |> get_sub()
    |> get_table()
    |> get_approval()
    |> join_title()
    |> join_amendments()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  def get_amendments(binary) do
    case Regex.run(
           ~r/Информация об изменяющих документах\n_*\n([\s\S]*?)_+/,
           binary
         ) do
      [_, group] ->
        Legl.txt("amendments")
        |> Path.absname()
        |> File.write(group)

        Regex.replace(
          ~r/Информация об изменяющих документах\n_*\n[\s\S]*?_+/,
          binary,
          ""
        )

      _ ->
        binary
    end
  end

  def join_amendments(binary) do
    str =
      Legl.txt("amendments")
      |> Path.absname()
      |> File.read!()

    case String.length(str) do
      0 ->
        binary

      _ ->
        String.replace_suffix(binary, "", "\n" <> @components[:amendment] <> " " <> str)
    end
  end

  def get_title(binary) do
    case Regex.run(
           ~r/.*?(?=^I\.[ ])/ms,
           binary
         ) do
      [match] ->
        Legl.txt("title")
        |> Path.absname()
        |> File.write(match)

        Regex.replace(
          ~r/.*?(?=^I\.[ ])/ms,
          binary,
          ""
        )

      _ ->
        Legl.txt("title")
        |> Path.absname()
        |> File.write("")

        binary
    end
  end

  def join_title(binary) do
    Legl.txt("title")
    |> Path.absname()
    |> File.read!()
    |> (&String.replace_prefix(binary, "", &1)).()
  end

  def get_part(binary) do
    part_names = Regex.replace(~r/[ ]/, @part_names, "|")

    binary
    |> (&Regex.replace(
          ~r/^ЧАСТЬ[ ](#{part_names})/m,
          &1,
          fn match, part -> "#{@components[:part]}#{part_number(part)} #{match}" end
        )).()
    |> (&Regex.replace(
          ~r/^(#{@roman_numerals})\.[ ].*/m,
          &1,
          fn match, part ->
            "#{@components[:part]}#{Legl.conv_roman_numeral(part)} #{match}"
          end
        )).()
  end

  @doc """
  Chapter Parser

  Раздел (razdel) is chapter in the cyrillic alphabet
  """
  def get_chapter(binary) do
    roman_numerals = Regex.replace(~r/[ ]/, Legl.roman(), "|")

    Regex.replace(
      ~r/^(?:РАЗДЕЛ|Раздел|ГЛАВА)[ ](#{roman_numerals})\.?_?(\d*)[ ]?.*/m,
      binary,
      fn
        match, chapter, "" ->
          "#{@components[:chapter]}#{Legl.conv_roman_numeral(chapter)} #{match}"

        match, chapter, section ->
          "#{@components[:section]}#{section} #{match}"
      end
    )
  end

  @doc """
  Section parser

  Глава (glava) is seciton in the cyrillic alphabet
  """
  def get_section(binary) do
    Regex.replace(
      ~r/^(?:ГЛАВА|Глава)[ ](\d+).*/m,
      binary,
      fn match, section -> "#{@components[:section]}#{section} #{match}" end
    )
  end

  @doc """
  Parse an article paragraph

  :named articles are prefixed with Статья. This is the default
  """

  def get_article(binary, :named) do
    amended_binary = amended_article(binary)

    Regex.replace(
      ~r/^Статья[ ](\d+-?\d*)_?(\d*).*/m,
      amended_binary,
      fn
        m, art_num, "" ->
          "#{@components[:article]}#{art_num} #{m}"

        m, art_num, para_num ->
          "#{@components[:para]}#{para_num} #{m}"
      end
    )
  end

  def get_article(binary, _) do
    Regex.replace(
      ~r/^(\d+)\.[ ].*/m,
      binary,
      fn
        m, art_num ->
          "#{@components[:article]}#{art_num} #{m}"
      end
    )
    |> (&Regex.replace(
          ~r/^\d+\.(\d+)\.[ ].*/m,
          &1,
          fn
            m, art_num ->
              "#{@components[:para]}#{art_num} #{m}"
          end
        )).()
  end

  def get_para(binary) do
    Regex.replace(
      ~r/^\d+\.\d+\.(\d+)\.[ ].*/m,
      binary,
      "#{@components[:para]}\\g{1} \\0"
    )
  end

  def get_sub(binary) do
    Regex.replace(
      ~r/^(\d+)\.(\d+)\.(\d+)\.[ ].*/m,
      binary,
      "#{@components[:sub]}\\g{1}_\\g{2}_\\g{3} \\0"
    )
  end

  def amended_article(binary) do
    Regex.scan(~r/^Статья[ ](\d+)(.*)/m, binary)
    # |> IO.inspect()
    |> Enum.reduce({binary, 0}, fn [_k, v, t], {acc, previous} ->
      current = String.to_integer(v)

      cond do
        current == previous + 1 ->
          {acc, current}

        String.length(v) - String.length(Integer.to_string(previous)) == 0 ->
          {acc, current}

        true ->
          size = String.length(v) - String.length(Integer.to_string(previous))

          rev = Regex.replace(~r/\d{#{size}}$/, v, "-\\0")

          Regex.replace(
            ~r/^Статья[ ]#{v}#{t}/m,
            acc,
            "Статья #{rev}#{t}"
          )
          |> (&{&1, previous}).()
      end
    end)
    # |> IO.inspect()
    |> elem(0)

    # |> IO.inspect()
  end

  def get_approval(binary) do
    Regex.replace(
      ~r/^Президент|Председатель[ ]Совета[ ]Министров/m,
      binary,
      "#{@components[:approval]} \\0"
    )
  end

  def get_annex(binary) do
    Regex.replace(
      ~r/^Приложение[ ]N[ ](\d+)/m,
      binary,
      fn m, v -> "#{@components[:annex]}N#{v} #{m}" end
    )
    |> (&Regex.replace(
          ~r/^Предписание\n|^НОРМЫ\n/m,
          &1,
          "#{@components[:annex]} \\0"
        )).()
  end

  def get_form(binary) do
    Regex.replace(
      ~r/^Форма[ ](\d+)/m,
      binary,
      fn m, v -> "#{@components[:form]}#{v} #{m}" end
    )
  end

  def get_form_para(binary) do
    Regex.replace(
      ~r/#{component_for_regex(:form)}[\s\S]*?(?=\n#{component_for_regex(:form)}|\n#{component_for_regex(:annex)}|$)/,
      binary,
      fn m ->
        # IO.inspect(m, limit: :infinity)
        String.replace(m, "\n", " #{Legl.pushpin_emoji()} ") |> (&Kernel.<>(&1, " \n")).()
      end
    )
  end

  def get_table(binary) do
    Regex.replace(
      ~r/^Таблица[ ](\d+)/m,
      binary,
      "#{@components[:table]}\\g{1} \\0"
    )
  end
end
