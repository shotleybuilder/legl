defmodule UK.Parser do
  @moduledoc false
  alias Types.Component
  @components %Component{}

  @regex_components Component.mapped_components_for_regex()

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

  @uk_cardinals ~s(One Two Three Four Five Six Seven Eight Nine Ten)

  @regex_uk_cardinals Regex.replace(~r/\n/, @uk_cardinals, "")
                      |> (&Regex.replace(~r/[ ]/, &1, "|")).()

  @uk_cardinal_integer String.split(@uk_cardinals)
                       |> Enum.reduce({%{}, 1}, fn x, {map, inc} ->
                         {Map.put(map, x, inc), inc + 1}
                       end)
                       |> Kernel.elem(0)

  def cardinal_as_integer(cardinal) do
    case Map.get(@uk_cardinal_integer, cardinal) do
      nil -> ""
      x -> Integer.to_string(x)
    end
  end

  @doc false
  @spec clean_original(String.t()) :: String.t()
  def clean_original("CLEANED\n" <> binary) do
    binary
    |> (&IO.puts("cleaned: #{String.slice(&1, 0, 100)}...")).()

    binary
  end

  def clean_original(binary) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> collapse_amendment_text_between_quotes()
      |> separate_part_chapter_schedule()
      |> join_empty_numbered()
      # |> rm_overview()
      # |> rm_footer()
      |> Legl.Parser.rm_leading_tabs()

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    clean_original(binary)
  end

  def separate_part_chapter_schedule(binary),
    do:
      Regex.replace(
        ~r/^(PART[ ]\d+)([A-Z]+)/m,
        binary,
        "\\g{1} \\g{2}"
      )
      |> (&Regex.replace(
            ~r/^(CHAPTER[ ]\d+)([A-Z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()
      |> (&Regex.replace(
            ~r/^(SCHEDULE)([A-Z a-z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()
      |> (&Regex.replace(
            ~r/^(SCHEDULE[ ]\d+)([A-Z a-z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()

  def collapse_amendment_text_between_quotes(binary) do
    Regex.run(
      ~r/(?:\r\n|\n)^[“][\s\S]*[”]/m,
      binary
    )
    |> IO.inspect()

    Regex.replace(
      ~r/(?:\r\n|\n)^[“][\s\S]*[”]/m,
      binary,
      fn x -> "#{join(x)}" end
    )
  end

  def join(binary) do
    Regex.replace(
      ~r/(\r\n|\n)/m,
      binary,
      "#{Legl.pushpin_emoji()}"
    )
  end

  @doc false

  def parser(binary, :regulation = type) when is_atom(type) do
    # {:ok, binary} = File.read(Path.absname(Legl.original()))

    binary
    |> rm_header()
    |> rm_explanatory_note
    |> join_empty_numbered()
    |> get_title()
    |> get_article()
    |> get_para()
    |> get_part()
    |> get_chapter()
    |> get_signed_section()
    |> get_annex()
    # get_sub_section() has to come after get_article
    |> get_sub_section(:regulation)
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  def parser(:act = type) when is_atom(type) do
    {:ok, binary} = File.read(Path.absname(Legl.original()))

    binary
    |> rm_header()
    |> rm_explanatory_note
    |> join_empty_numbered()
    |> get_chapter()
    |> get_amendments(:act)
    # |> get_modifications(:act)
    |> get_sub_section(:act)
    # get_section() has to come after get_sub_section
    |> get_A_section(:act)
    |> get_section(:act)
    # get_heading() has to come after get_section
    |> get_heading(:act)
    |> get_part()
    |> get_signed_section()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
    |> rm_amendment(:act)
  end

  def get_title(binary) do
    "#{@components.title} #{binary}"
  end

  @doc """
  Separate parser for Schedules since there is no easy way to differentiate schedule articles from the main law
  """
  def parse_annex() do
    {:ok, binary} = File.read(Path.absname(Legl.original_annex()))

    binary
    |> rm_leading_tabs_spaces()
    |> rm_header_annex()
    |> Legl.Parser.rm_empty_lines()
    |> get_annex()
    |> get_annex_heading()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  def rm_leading_tabs_spaces(binary), do: Regex.replace(~r/^[\s\t]+/m, binary, "")

  @doc """
  Remove https://legislation.gov.uk header content
  """
  def rm_header(binary) do
    binary
    |> (&Regex.replace(~r/^[[:space:][:print:]]+PreviousNext\n+/, &1, "")).()
    # just the law w/o the schedules view
    |> (&Regex.replace(~r/^Previous: IntroductionNext: Schedule/m, &1, "")).()
    |> (&Regex.replace(~r/^[[:space:][:print:]]+Back to full view\n+/, &1, "")).()
  end

  def rm_header_annex(binary),
    do:
      Regex.replace(
        ~r/^[[:space:][:print:]]+Previous\: SignatureNext\: Explanatory Note\n+/,
        binary,
        ""
      )

  def rm_explanatory_note(binary),
    do:
      Regex.replace(
        ~r/^Explanatory Note[\s\S]+|EXPLANATORY NOTE[\s\S]+/m,
        binary,
        ""
      )

  def join_empty_numbered(binary),
    do:
      Regex.replace(
        ~r/^(\(([a-z]+|[ivmcldx]+)\)|\d+\.?)(?:\r\n|\n)/m,
        binary,
        "\\g{1} "
      )

  @doc """
  PART and Roman Part Number concatenate when copied e.g. PART IINFORMATION

  """
  @spec get_part(String.t()) :: String.t()
  def get_part(binary) do
    part_class_scheme =
      cond do
        Regex.match?(~r/^(PART|Part)[ ]+\d+/m, binary) -> "numeric"
        Regex.match?(~r/^PART[ ]+A/m, binary) -> "alphabetic"
        Regex.match?(~r/^PART[ ]+I/m, binary) -> "roman_numeric"
        true -> "no parts"
      end

    case part_class_scheme do
      "no parts" ->
        binary

      "numeric" ->
        Regex.replace(
          ~r/^(PART|Part)[ ](\d*)[ ]?([ A-Z]*)/m,
          binary,
          "#{@components.part}\\g{2} \\g{1} \\g{2} \\g{3}"
        )

      "alphabetic" ->
        Regex.replace(
          ~r/^PART[ ]([A-Z])[ ]?([ A-Z]+)/m,
          binary,
          fn _, value, text ->
            index = Legl.conv_alphabetic_classes(value)
            "#{@components.part}#{index} PART #{value} #{text}"
          end
        )

      "roman_numeric" ->
        Regex.replace(
          ~r/^PART[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3})([ A-Z]+)/m,
          binary,
          fn _, tens, units, text ->
            numeral = tens <> units

            {remaining_numeral, last_numeral} = String.split_at(numeral, -1)

            # last_numeral = String.last(numeral)
            # remaining_numeral = String.slice(numeral, 0..(String.length(numeral) - 2))

            case Dictionary.match?("#{last_numeral}#{text}") do
              true ->
                value = Legl.conv_roman_numeral(remaining_numeral)
                "#{@components.part}#{value} PART #{remaining_numeral} #{last_numeral}#{text}"

              false ->
                value = Legl.conv_roman_numeral(numeral)
                "##{@components.part}#{value} PART #{numeral} #{text}"
            end
          end
        )
    end
  end

  @doc """

  """
  def get_chapter(binary),
    do:
      Regex.replace(
        ~r/^(Chapter|CHAPTER)[ ](\d+)/m,
        binary,
        "#{@components.chapter}\\g{2} \\0"
      )

  @doc """
  Parse Act section headings & Regulation article headings.
  * Act
  Format
  Heading
  There is an initial captialisaiton and no ending period
  """
  def get_heading(binary, :act),
    do:
      Regex.replace(
        ~r/^[A-Z][^\d\.][^\n]+[^\.](etc\.)?\n#{article_emoji()}(\d+)/m,
        binary,
        "#{@components.heading}\\0"
      )

  @doc """
  Parse sections of Acts.  The equivalent of Regualtion articles.
  Formats:
  1Text
  """
  def get_section(binary, :act),
    do:
      Regex.replace(
        # too restrictive ~r/^(\d+)([^\n]+)([^\.])(etc\.)?(\n#{sub_article_emoji()})/m,
        ~r/^(\[?F\d\d*,?[ ])?(\d{1,3})[ ]?([A-Z|\.])([^\n]+)([^\.])(etc\.)?/m,
        binary,
        "#{article_emoji()}\\g{1}\\g{2} \\g{3}\\g{4}\\g{5}\\g{6}"
      )

  @doc """
  Parse sections of Acts.  The equivalent of Regualtion articles.
  Formats:
  1Text
  """
  def get_A_section(binary, :act),
    do:
      Regex.replace(
        # too restrictive ~r/^(\d+)([^\n]+)([^\.])(etc\.)?(\n#{sub_article_emoji()})/m,
        ~r/^(\[F\d\d?)?[ ]?(\d{1,3}A)[ ]?([A-Z\.])([^\n]+)([^\.])(etc\.)?/m,
        binary,
        "#{article_emoji()}\\g{1} \\g{2} \\g{3}\\g{4}\\g{5}\\g{6}"
      )

  @doc """
  Parse sub-sections of Acts.
  Formats:
  (1)Text
  """
  def get_sub_section(binary, :act),
    do:
      Regex.replace(
        ~r/^(\[?F?\d*\(\d+\))[ ]?([A-Z])/m,
        binary,
        "#{sub_article_emoji()}\\g{1} \\g{2}"
      )

  def get_sub_section(binary, :regulation),
    do:
      Regex.replace(
        ~r/^[^#{@regex_components.part}|#{@regex_components.chapter}|#{@regex_components.annex}]([^\n]+)[^\.](etc\.)?\n#{@regex_components.article}\d+[ ](\d+)/m,
        binary,
        "#{@components.sub_section}\\g{3} \\0"
      )

  @doc """
  Parse the articles of Regulations.
  """
  def get_article(binary),
    do:
      Regex.replace(
        ~r/^(\d+)\.[ ]+/m,
        binary,
        "#{@components.article}\\g{1} \\0"
      )
      |> (&Regex.replace(
            ~r/^((\d+)\.(#{<<226, 128, 148>>}|\-)\(\d+\))/m,
            &1,
            "#{@components.article}\\g{2} \\0"
          )).()

  def get_para(binary),
    do:
      Regex.replace(
        ~r/^\((\d+)\)[ ][A-Z]/m,
        binary,
        "#{@components.para}\\g{1} \\0"
      )

  @doc """
  Mark-up Schedules
  egs
  SCHEDULE 1.Name

  """
  def get_annex(binary),
    do:
      Regex.replace(
        ~r/^SCHEDULE[ ](\d+).*/m,
        binary,
        "#{@components.annex}\\g{1} \\0 "
      )
      |> (&Regex.replace(
            ~r/^THE SCHEDULE|^SCHEDULE/m,
            &1,
            "#{@components.annex}1 \\0"
          )).()

  def get_annex_heading(binary),
    do:
      Regex.replace(
        ~r/^([A-Z][^\n\.]+)\n(#{annex_emoji()}.*)/m,
        binary,
        "\\g{2}#{pushpin_emoji()}\\g{1}"
      )

  @doc """

  """
  def get_signed_section(binary) do
    binary
    |> (&Regex.replace(
          ~r/^Signed by/m,
          &1,
          "#{@components.signed}\\0"
        )).()
    |> (&Regex.replace(
          ~r/^Sealed with the Official Seal/m,
          &1,
          "#{signed_emoji()}\\0"
        )).()
  end

  def rm_amendment(binary, :act),
    do: Regex.replace(~r/^#{amendment_emoji()}.*(?:\r\n|\n)?/m, binary, "")

  @doc """
  Revised Acts
  """
  def get_amendments(binary, :act),
    do:
      Regex.replace(
        ~r/^Textual[ ]Amendments|Extent[ ]Information|Modifications etc\.[ ]\(not altering text\)/m,
        binary,
        "#{amendment_emoji()}\\0"
      )

  @doc """
  Revised Acts
  """
  def get_modifications(binary, :act),
    do:
      Regex.replace(
        ~r/^Modifications etc\.[ ]\(not altering text\)/m,
        binary,
        "#{amendment_emoji()}\\0"
      )
end
