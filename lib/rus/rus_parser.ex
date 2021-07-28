defmodule RUS.Parser do
  @moduledoc false

  # RUSkish alphabet: Ç, ç, İ, Ş, ş, Ö, ö, Ü, ü
  # Ç, İ, Ş, Ö, Ü
  # Ç - <<195, 135>>
  # ç - <<195, 167>>
  # Ş, ş, Ü, ü

  # @emojis Legl.named_emojis()
  @components Legl.mapped_components()

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
  def clean_original("CLEANED\n" <> binary) do
    IO.write("Clean\n")
    binary
  end

  @spec clean_original(String.t()) :: String.t()
  def clean_original(binary) do
    binary =
      binary
      |> Legl.Parser.rm_empty_lines()
      # |> rm_header()
      # |> rm_footer()
      # |> rm_makers_clause()
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_leading_tabs()

    # |> Legl.Parser.rm_underline_characters()
    # |> rm_page_numbers()

    # |> rm_footer()

    File.write(Legl.original(), binary)

    clean_original(binary)
  end

  def rm_header(binary) do
    Regex.replace(
      ~r/.*?Текст/s,
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
          ~r/\nРедакция документа с учетом.*|\nЭлектронный текст документа.*/s,
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
  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> get_amendments()
    |> get_part()
    |> get_chapter()
    |> get_section()
    |> get_annex()
    |> get_form()
    |> get_form_para()
    |> get_article()
    |> get_table()
    |> get_approval()
    |> Legl.Parser.join()
  end

  def get_amendments(binary) do
    case Regex.run(
           ~r/Информация об изменяющих документах\n_*\n[\s\S]*?_+/,
           binary
         ) do
      [match] ->
        File.write(Legl.snippet(), match)

      _ ->
        nil
    end

    Regex.replace(
      ~r/Информация об изменяющих документах.*(?=Государственной Думой)/s,
      binary,
      ""
    )
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

  def get_chapter(binary) do
    roman_numerals = Regex.replace(~r/[ ]/, Legl.roman(), "|") |> IO.inspect()

    Regex.replace(
      ~r/^(?:РАЗДЕЛ|ГЛАВА)[ ](#{roman_numerals})\.?[ ]?.*/m,
      binary,
      fn match, chapter ->
        IO.puts(chapter)
        "#{@components[:chapter]}#{Legl.conv_roman_numeral(chapter)} #{match}"
      end
    )
  end

  def get_section(binary) do
    Regex.replace(
      ~r/^ГЛАВА[ ](\d+).*/m,
      binary,
      fn match, section -> "#{@components[:section]}#{section} #{match}" end
    )
  end

  def get_article(binary) do
    case Regex.run(~r/^Статья[ ]\d+/m, binary) do
      nil ->
        Regex.replace(
          ~r/^(\d+)\.[ ].*/m,
          binary,
          fn
            m, art_num ->
              "#{@components[:article]}#{art_num} #{m}"
          end
        )

      _ ->
        amended_binary = amended_article(binary)

        Regex.replace(
          ~r/^Статья[ ](\d+-?\d*)_?(\d*).*/m,
          amended_binary,
          fn
            m, art_num, "" ->
              "#{@components[:article]}#{art_num} #{m}"

            m, art_num, para_num ->
              @components[:article] <> "#{art_num}_#{para_num} " <> m
          end
        )
    end
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
      ~r/^Президент/m,
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
