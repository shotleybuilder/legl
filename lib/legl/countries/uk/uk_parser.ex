defmodule UK.Parser do
  @moduledoc false
  alias Types.Component
  @components %Component{}

  @regex_components Component.mapped_components_for_regex()

  @region_regex "U\\.K\\.|E\\+W\\+N\\.I\\.|E\\+W\\+S|E\\+W"
  @country_regex "N\\.I\\.|S|W|E"

  import Legl,
    only: [
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

  @spec cardinal_as_integer(any) :: binary
  def cardinal_as_integer(cardinal) do
    case Map.get(@uk_cardinal_integer, cardinal) do
      nil -> ""
      x -> Integer.to_string(x)
    end
  end

  def parser(binary, :act = type) when is_atom(type) do

    binary
    |> get_title()
    |> get_part_chapter(:part)
    |> get_part_chapter(:chapter)
    #|> get_modifications(:act)
    |> get_annex()
    |> get_A_section(:act)
    |> get_section(:act)
    |> get_sub_section(:act)
    |> get_amendments(:act)
    |> get_commencements(:act)
    |> get_signed_section()
    #|> revise_section_number(:act)
    |> get_A_heading(:act)
    |> get_heading(:act)
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
    |> move_region_to_end(:act)
    |> add_missing_region()
    |> rm_triangles()
    #|> rm_amendment(:act)
  end

  def parser(binary, :regulation = type) when is_atom(type) do
    binary
    |> rm_header()
    |> rm_explanatory_note
    #|> join_empty_numbered()
    |> get_title()
    |> get_part_chapter(:part)
    |> get_part_chapter(:chapter)
    |> get_article()
    |> get_sub_article()
    |> get_amendments(:regulation)
    |> get_commencements(:regulation)
    |> get_signed_section()
    |> get_annex()
    |> provision_before_schedule()
    |> get_table()
    |> get_A_heading(:regulation)
    |> get_heading(:regulation)
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
    |> move_region_to_end(:regulation)
    |> add_missing_region()
    |> rm_triangles()
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

  @doc """
  PART and Roman Part Number concatenate when copied e.g. PART IINFORMATION

  """
  def get_part_chapter(binary, type) do

    [type_regex, component] =
      case type do
        :part ->
          ["PART|Part", "#{@components.part}"]
        :chapter ->
          ["CHAPTER|Chapter", "#{@components.chapter}"]
      end

    part_class_scheme =
      cond do
        Regex.match?(~r/^(#{type_regex})[ ]+\d+/m, binary) -> "numeric"
        Regex.match?(~r/^(#{type_regex})[ ]+A/m, binary) -> "alphabetic"
        Regex.match?(~r/^(#{type_regex})[ ]+I/m, binary) -> "roman_numeric"
        true -> :false
      end

    case part_class_scheme do
      :false ->
        binary

      "numeric" ->
        Regex.replace(
          ~r/^(#{type_regex})[ ](\d+)[ ]?(#{@region_regex})(.*)/m,
          binary,
          "#{component}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}"
        )

      "alphabetic" ->
        Regex.replace(
          ~r/^(#{type_regex})[ ]([A-Z])[ ]?([ A-Z]+)/m,
          binary,
          fn _, part_chapter, value, text ->
            index = Legl.conv_alphabetic_classes(value)
            "#{component}#{index} #{part_chapter} #{value} #{text}"
          end
        )

      "roman_numeric" ->
        Regex.replace(
          ~r/^(#{type_regex})[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3})([ A-Za-z]+)/m,
          binary,
          fn _, part_chapter, tens, units, text ->

            numeral = tens <> units

            {remaining_numeral, last_numeral} = String.split_at(numeral, -1)

            #IO.inspect("#{part}, #{tens}, #{units}, #{text}, #{numeral}, #{remaining_numeral}, #{last_numeral}")

            # last_numeral = String.last(numeral)
            # remaining_numeral = String.slice(numeral, 0..(String.length(numeral) - 2))

            case Dictionary.match?("#{last_numeral}#{text}") do
              true ->
                value = Legl.conv_roman_numeral(remaining_numeral)
                "#{component}#{value} #{part_chapter} #{remaining_numeral} #{last_numeral}#{text}"

              false ->
                value = Legl.conv_roman_numeral(numeral)
                "#{component}#{value} #{part_chapter} #{numeral} #{text}"
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


  @heading_children ~s/[#{@regex_components.section}|#{@regex_components.amendment}]/
  @doc """
  Parse Act section headings
  Format
  Heading
  There is an initial captialisation and no ending period
  """
  def get_heading(binary, :act),
    do:
      binary
      |> (&Regex.replace(
        ~r/^([A-Z].*?)(etc\.)?(#{@region_regex})$([\s\S]+#{@regex_components.section})(.*?[ ])/m,
        &1,
        "#{@components.heading}\\g{5}\\g{1}\\g{2} [::region::]\\g{3}\\g{4}\\g{5}"
      )).()

  def get_heading(binary, :regulation),
  do:
    binary
    |> (&Regex.replace(
      ~r/^([A-Z].*?)(#{@region_regex})(\n#{@regex_components.article})(\d+)/m,
      &1,
      "#{@components.heading}\\g{4} \\g{1} [::region::]\\g{2}\\g{3}\\g{4}"
    )).()
    |> (&Regex.replace(
      ~r/^([A-Z].*?)(#{@country_regex})(\n#{@regex_components.article})(\d+)/m,
      &1,
      "#{@components.heading}\\g{4} \\g{1} [::region::]\\g{2}\\g{3}\\g{4}"
    )).()
    #Not every heading in Regulations has a Region
    |> (&Regex.replace(
      ~r/^([A-Z].*?)(\n#{@regex_components.article})(\d+)/m,
      &1,
      "#{@components.heading}\\g{3} \\g{1} \\g{2}\\g{3}"
    )).()

  def get_A_heading(binary, :act),
    do:
      Regex.replace(
        ~r/^(\[?🔺F\d+🔺)([A-Z].*?)(etc\.)?(#{@region_regex})$([\s\S]+?#{@regex_components.section})(.*?[ ])/m,
        binary,
        "#{@components.heading}\\g{6}\\g{1} \\g{2}\\g{3} [::region::]\\g{4}\\g{5}\\g{6}"
      )
      #🔺F2🔺...S  Desc: a revoked heading
      |> (&Regex.replace(
        ~r/^(\[?🔺F\d+🔺)(\.*?)(#{@region_regex})$([\s\S]+?#{@regex_components.section})(.*?[ ])/m,
        &1,
        "#{@components.heading}\\g{5}\\g{1} \\g{2} [::region::]\\g{3}\\g{4}\\g{5}"
      )).()

  def get_A_heading(binary, :regulation),
    do:
      Regex.replace(
        ~r/^(\[F\d+[A-Z].*?)(#{@region_regex})(\n#{@regex_components.article}|\n#{@regex_components.amendment})(\d+[A-Z]?)/m,
        binary,
        "#{@components.heading}\\g{4} \\g{1} [::region::]\\g{2}\\g{3}\\g{4}"
      )
  @doc """
  Parse sections of Acts.  The equivalent of Regulation articles.
  Formats:
  1Text - targetted by the 2nd regex
  1(1)Text - targetted by the 1st regex
  """
  def get_section(binary, :act),
    do:
      Regex.replace(
        ~r/^(\d{1,3}[A-Z]?)\((\d{1,3})\)[ ]?(.*)(#{@region_regex})/m,
        binary,
        "#{@components.section}\\g{1}-\\g{2} \\g{1}(\\g{2}) \\g{3} [::region::]\\g{4}"
      )
      #A1The net-zero emissions targetS
      |> (&Regex.replace(
        ~r/^([A-Z]\d{1,3})([A-Z].*)(#{@region_regex})$/m,
        &1,
        "#{@components.section}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
      )).()
      # 8ANitrogen balance sheetS
      |> (&Regex.replace(
        ~r/^(\d{1,3}[A-Z])([A-Z].*)(#{@region_regex})$/m,
        &1,
        "#{@components.section}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
      )).()
      |> (&Regex.replace(
        ~r/^(\d{1,3})(#{@region_regex})(.*)/m,
        &1,
        "#{@components.section}\\g{1} \\g{1} \\g{3} [::region::]\\g{2}"
      )).()
      |> (&Regex.replace(
        ~r/^(\d{1,3})[ ]?(.*?)(#{@region_regex})$/m,
        &1,
        "#{@components.section}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
      )).()
      |> (&Regex.replace(
        ~r/^(\d{1,3})\((\d{1,3})\)[ ]?(.*)/m,
        &1,
        "#{@components.section}\\g{1}-\\g{2} \\g{1}(\\g{2}) \\g{3}"
      )).()

  @doc """
  Parse amended sections of Acts.
  Formats:

  """
  def get_A_section(binary, :act),
    do:
      binary
      #[🔺F4🔺2AModification of the interim targetsS
      |> (&Regex.replace(
        ~r/^(\[?🔺F\d+🔺)(\d+[A-Z])[ ]?([A-Z].*)(#{@region_regex})$/m,
        &1,
        "#{@components.section}\\g{2} \\g{1} \\g{2} \\g{3} [::region::]\\g{4}"
      )).()
      #🔺F2🔺1The 2050 targetS
      |> (&Regex.replace(
        ~r/^(\[?🔺F\d+🔺)(\d+)(.*)(#{@region_regex})$/m,
        &1,
        "#{@components.section}\\g{2} \\g{1} \\g{2} \\g{3} [::region::]\\g{4}"
      )).()
      #5[F39(1)]Text...
      |> (&Regex.replace(
        ~r/^(\d+[A-Z]?)(\[F\d{1,4})\((\d+)\)(.*)(#{@region_regex})$/m,
        &1,
        "#{@components.section}\\g{2} \\g{1}-\\g{3} \\g{1}\\g{2}(\\g{3})\\g{4} [::region::]\\g{5}"
      )).()
      #F21The 2050 targetS
      |> (&Regex.replace(
        ~r/^(F\d{1,4})([A-Z].*)(#{@region_regex})$/m,
        &1,
        "#{@components.section}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
      )).()
      #[F364A(1)The paragraph text...
      |> (&Regex.replace(
        ~r/^(\[F\d{1,4}[A-Z])\((\d{1,3})\)(.*)/m,
        &1,
        "#{@components.section}\\g{1}-\\g{2} \\g{1}(\\g{2}) \\g{3}"
      )).()
      #[F332AE+W+N.I.The regulations ...
      |> (&Regex.replace(
        ~r/^(\[F\d{1,4}[A-Z]?)(#{@region_regex})(.*)/m,
        &1,
        "#{@components.section}\\g{1} \\g{1}(\\g{3}) [::region::]\\g{2}"
      )).()
      #F68Text    Missing the opening square bracket
      |> (&Regex.replace(
        ~r/^(F\d{1,4})[ ]?(.*)(#{@region_regex})$/m,
        &1,
        "#{@components.section}[\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
      )).()
      #[F35(5)For the purposes...
      #[F48(2A)Regulations
      #[F42(2) In this
      |> (&Regex.replace(
        ~r/^(\[F\d{1,4})\((\d{1,3}[A-Z]?)\)[ ]?(.*)/m,
        &1,
        "#{@components.sub_section}\\g{1} \\g{2} \\g{1}(\\g{2}) \\g{3}"
      )).()
      #F5(1). . . . . . Missing the opening square bracket
      |> (&Regex.replace(
        ~r/^(\F\d{1,4})\((\d{1,3}[A-Z]?)\)[ ]?(.*)/m,
        &1,
        "#{@components.sub_section}[\\g{1} \\g{2} \\g{1}(\\g{2}) \\g{3}"
      )).()

  @doc """
  Parse sub-sections of Acts.
  Formats:
  (1)Text
  """
  def get_sub_section(binary, :act),
    do:
      Regex.replace(
        ~r/^(\[?F?\d*[A-Z]?\((\d+[A-Z]?)\))[ ]?([“A-Z])/m,
        binary,
        "#{@components.sub_section}\\g{2} \\g{1} \\g{3}"
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
    binary
      |> (&Regex.replace(
        ~r/^(\d+)(\.[ ]+.*)(#{@region_regex})$/m,
        &1,
        "#{@components.article}\\g{1} \\g{1}\\g{2} [::region::]\\g{3}"
      )).()
      #3.  A declaration of conformity must include—S
      |> (&Regex.replace(
        ~r/^(\d+)(\.[ ]+.*)(#{@country_regex})$/m,
        &1,
        "#{@components.article}\\g{1} \\g{1}\\g{2} [::region::]\\g{3}"
      )).()
      #
      |> (&Regex.replace(
        ~r/^(\d+)\.[ ]+/m,
        &1,
        "#{@components.article}\\g{1} \\0"
      )).()
      #[🔺F21🔺8E.—(1) The Scottish
      |> (&Regex.replace(
        ~r/^(\[?🔺F\d+🔺)(\d+[A-Z])\.(?:#{<<226, 128, 148>>}|\-)\((\d+)\)/m,
        &1,
        "#{@components.article}\\g{2}-\\g{3} \\0"
      )).()
      #12A.—(1) This regulation
      |> (&Regex.replace(
        ~r/^(\d+[A-Z])\.(?:#{<<226, 128, 148>>}|\-)\((\d+)\)/m,
        &1,
        "#{@components.article}\\g{1}-\\g{2} \\0"
      )).()
      #[🔺F21🔺8.—(1) The Scottish
      |> (&Regex.replace(
        ~r/^(\[?🔺F\d+🔺)(\d+)\.(?:#{<<226, 128, 148>>}|\-)\((\d+)\)/m,
        &1,
        "#{@components.article}\\g{2}-\\g{3} \\0"
      )).()
      |> (&Regex.replace(
        ~r/^(\d+)\.(?:#{<<226, 128, 148>>}|\-)\((\d+)\)/m,
        &1,
        "#{@components.article}\\g{1}-\\g{2} \\0"
      )).()
      |> (&Legl.Utility.rm_dupe_spaces(&1, "\\[::article::\\]")).()

  def get_sub_article(binary),
    do:
      Regex.replace(
        ~r/^\((\d+)\)[ ][A-Z]/m,
        binary,
        "#{@components.sub_article}\\g{1} \\0"
      )
      |> (&Regex.replace(
        ~r/^(\[?🔺F\d+🔺)(\((\d+)\)[ ][A-Z])/m,
        &1,
        "#{@components.sub_article}\\g{3} \\g{1} \\g{2}"
      )).()

  @doc """
  Mark-up Schedules
  egs
  SCHEDULE 1.Name

  """
  def get_annex(binary),
    do:
      binary
      |> (&Regex.replace(
        ~r/^(\[?🔺?F?\d*🔺?)(SCHEDULES?|Schedules?)[ ]?(\d*[A-Z]?[ ]?)(#{@region_regex})([^.]*?)(?:\n)/m,
        &1,
        "#{@components.annex}\\g{3} \\g{1} \\g{2} \\g{3} \\g{5} [::region::]\\g{4}\n"
        )).()
      |> (&Regex.replace(
        ~r/^(SCHEDULE|Schedule)[ ]?(\d+)[ ]?(#{@region_regex})([^.]*?)(?:\n)/m,
        &1,
        "#{@components.annex}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}\n"
        )).()
      |> (&Regex.replace(
        ~r/^(SCHEDULE|Schedule)[ ]?(\d+)[ ]?([^.]*?)(?:\n)/m,
        &1,
        "#{@components.annex}\\g{2} \\g{1} \\g{2} \\g{3}\n"
        )).()
      # SCHEDULE Identified Improvement Measures
      |> (&Regex.replace(
        ~r/^(?:SCHEDULE|Schedule)[^S|^s][ ]?[^.]*?(?:\n)/m,
        &1,
        "#{@components.annex}1 \\0"
        )).()
      |> (&Regex.replace(
        ~r/^(?:THE SCHEDULE|The Schedule)[ ]?[^.]*?(?:\n)/m,
        &1,
        "#{@components.annex}1 \\0"
      )).()
      |> (&Regex.replace(
        ~r/^(SCHEDULES|Schedules)(?:\n)/m,
        &1,
        "#{@components.annex} \\0"
      )).()
      # remove double, triple and quadruple spaces
      |> (&Regex.replace(
        ~r/^(\[::annex::\].*)/m,
        &1,
        fn _, x -> String.replace(x, ~r/[ ]{2,4}/, " ") end
      )).()

  def provision_before_schedule(binary), do:
    binary
    |> (&Regex.replace(
      ~r/^(Regulation.*|Article.*)\n(\[::annex::].*)/m,
      &1,
      "\\g{2} 📌\\g{1}"
    )).()

  def get_table(binary), do:
    binary
    |> (&Regex.replace(
      ~r/^Table[ ](\d+)/m,
      &1,
      "#{@components.table}\\g{1} \\0"
    )).()
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
          "#{@components.signed}\\0"
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
        ~r/^(Textual[ ]Amendments|Extent[ ]Information|Modifications etc\.[ ]\(not altering text\))/m,
        binary,
        "#{@components.amendment}\\g{1}"
      )
      |> (&Regex.replace(
        ~r/^(F\d+)(S\.)[ ](\d+\(?\d*\)?)(.*)/m,
        &1,
        "\\g{1} \\g{2}\\g{3}\\g{4}"
      )).()

  def get_amendments(binary, :regulation),
    do:
      binary
      |> (&Regex.replace(
        ~r/^(Textual[ ]Amendments|Extent[ ]Information|Modifications etc\.[ ]\(not altering text\))/m,
        &1,
        "#{@components.amendment}\\g{1}"
      )).()
      |> (&Regex.replace(
        ~r/^(🔺F\d+🔺)([^\.].*)/m,
        &1,
        "#{@components.amendment}\\g{1} \\g{2}"
      )).()

  def get_commencements(binary, _type),
    do:
      Regex.replace(
        ~r/^(Commencement[ ]Information)/m,
        binary,
        "#{@components.commencement}\\g{1}"
      )
      |> (&Regex.replace(
        ~r/^(I\d+)(S\.)[ ](\d+\(?\d*\)?)(.*)/m,
        &1,
        "\\g{1} \\g{2}\\g{3}\\g{4}"
      )).()
      |> (&Regex.replace(
        ~r/^(I\d+)(Art\.)[ ](\d+\(?\d*\)?)(.*)/m,
        &1,
        "\\g{1} \\g{2}\\g{3}\\g{4}"
      )).()
      |> (&Regex.replace(
        ~r/^(I\d+)(Sch\.)[ ](\d+\(?\d*\)?)(.*)/m,
        &1,
        "\\g{1} \\g{2}\\g{3}\\g{4}"
      )).()

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

  @doc """
    An amended section has the following pattern
      [::section::]F1234 F1234 Section title
    This function converts to
      [::section::]34 F1234 Section title
    By keeping a track of the last section number and incrementing by 1.

    Also, adds the section number to the amendment
      From
        [::amendment::]Textual Amendment ...
      To
        [::amendment::]10 Textual Amendment ...
  """

  def revise_section_number(binary, :act) do
    acc =
      String.split(binary, "\n")
      |> Enum.reduce([], fn

        "[::section::][F" <> x, acc ->
          amd_type =
            cond do
              #[::section::][F39 5-1 5[F39(1)]Para
              Regex.match?(~r/\d+[ ]\d+-\d+[ ]/, x) -> :section_and_sub_section
              #[::section::][F384A-1 [F384A(1)
              Regex.match?(~r/\d+[A-Z]-\d+/, x) -> :amended_section_and_sub_section
              #[::section::][F332A [F332A
              Regex.match?(~r/\d+[A-Z]/, x) -> :amended_section_A
              #[::section::][F332A [F332A
              Regex.match?(~r/\d+/, x) -> :amended_section
              true -> IO.inspect("ERROR #{x}")
            end
          [_, num, str] =
            case amd_type do
              :section_and_sub_section ->
                Regex.run(~r/(\d+-\d+)[ ](.*)/, x)
              :amended_section_and_sub_section ->
                Regex.run(~r/\d{2}(\d[A-Z]-\d+)[ ](.*)/, x)
              :amended_section_A ->
                Regex.run(~r/\d{2}(\d[A-Z])[ ](.*)/, x)
              :amended_section ->
                [n] = Regex.run(~r/^\d+/, x)
                case String.length(n) do
                  2 -> Regex.run(~r/\d{1}(\d+)[ ](.*)/, x)
                  3 -> Regex.run(~r/\d{1}(\d+)[ ](.*)/, x)
                  4 -> Regex.run(~r/\d{2}(\d+)[ ](.*)/, x)
                end
            end

            ["[::section::]#{num} #{str}" | acc]

        "[::sub_section::][F" <> x, acc ->

          amd_type =
            cond do
              #[::sub_section::][F48 2A [F48(2A) Para
              Regex.match?(~r/\d+[ ]\d+[A-Z][ ]/, x) -> :amended_sub_section
              #[::sub_section::][F42 2 [F42(2) Para
              Regex.match?(~r/\d+[ ]\d+[ ]/, x) -> :sub_section
            end

          [_, num, str] =
            case amd_type do
              :amended_sub_section ->
                Regex.run(~r/(\d[A-Z])[ ](.*)/, x)
              :sub_section ->
                Regex.run(~r/^\d+[ ](\d+)[ ](.*)/, x)
            end

            ["[::sub_section::]#{num} #{str}" | acc]

        x, acc ->
          [x | acc]

      end)
    acc
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def move_region_to_end(binary, _) do
    Regex.replace(~r/(.*)([ ]\[::region::\].*?)([ ].*)/m, binary, "\\g{1}\\g{3}\\g{2}")
  end

  def add_missing_region(binary) do
    String.split(binary, "\n")
    |> Enum.reduce([], fn
      "[::section::]" <> x, acc ->
        case String.match?(x, ~r/\[::region::\]/) do
          true -> ["[::section::]#{x}" | acc]
          _ -> [~s/[::section::]#{x} [::region::]/ | acc]
        end
      "[::annex::]" <> x, acc ->
        case String.match?(x, ~r/\[::region::\]/) do
          true -> ["[::annex::]#{x}" | acc]
          _ -> [~s/[::annex::]#{x} [::region::]/ | acc]
        end
      "[::heading::]" <> x, acc ->
        case String.match?(x, ~r/\[::region::\]/) do
          true -> ["[::heading::]#{x}" | acc]
          _ -> [~s/[::heading::]#{x} [::region::]/ | acc]
        end
      "[::article::]" <> x, acc ->
        case String.match?(x, ~r/\[::region::\]/) do
          true -> ["[::article::]#{x}" | acc]
          _ -> [~s/[::article::]#{x} [::region::]/ | acc]
        end
      x, acc -> [x | acc]
    end)
    |> Enum.reverse
    |> Enum.join("\n")
  end

  def rm_triangles(binary) do
    Regex.replace(~r/🔺/m, binary, "")
  end

end
