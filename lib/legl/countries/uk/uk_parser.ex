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

  def parser(binary, %{type: :act} = opts) do
    binary
    |> get_title()
    |> get_part_chapter(:part)
    |> get_part_chapter(:chapter)
    # |> get_modifications(:act)
    |> get_annex()
    |> provision_before_schedule()
    |> get_table()
    |> get_A_section(:act)
    |> get_section(:act)
    |> get_sub_section(:act)
    |> get_amendments(:act)
    |> get_modifications(:act)
    |> get_commencements(:act)
    |> get_extents(:act)
    |> get_editorial(:act)
    |> get_signed_section()
    # |> revise_section_number(:act)
    |> get_A_heading(:act)
    |> get_heading(:act)
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
    |> move_region_to_end(:act)
    |> add_missing_region()
    |> rm_emoji(["🇨", "🇪", "🇲", "🇽", "🔺", "🔻", "❌"])
    # |> rm_amendment(:act)
    |> Legl.Countries.Uk.AirtableArticle.UkArticleQa.qa_sections(opts)
  end

  def parser(binary, %{type: :regulation} = _opts) do
    binary
    |> rm_header()
    |> rm_explanatory_note
    # |> join_empty_numbered()
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
    # Has to come before table
    |> get_sub_table()
    |> get_table()
    |> rm_table_ref()
    |> get_A_heading(:regulation)
    |> get_heading(:regulation)
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
    |> move_region_to_end(:regulation)
    |> add_missing_region()
    |> rm_emoji(["🇨", "🇪", "🇲", "🇽", "🔺", "🔻"])
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
      opts =
      case type do
        :part ->
          ["PART|Part", "#{@components.part}"]

        :chapter ->
          ["CHAPTER|Chapter", "#{@components.chapter}"]
      end

    scheme =
      cond do
        Regex.match?(~r/^\[?🔺F?\d*🔺?[ ]?(#{type_regex})[ ]+\d+/m, binary) &&
            Regex.match?(~r/^(#{type_regex})[ ]+I/m, binary) ->
          :roman_numeric

        Regex.match?(~r/^\[?🔺F?\d*🔺?[ ]?(#{type_regex})[ ]+\d+/m, binary) ->
          :numeric

        Regex.match?(~r/^(#{type_regex})[ ]+A/m, binary) ->
          :alphabetic

        Regex.match?(~r/^(#{type_regex})[ ]+I/m, binary) ->
          :roman

        true ->
          false
      end

    case scheme do
      false ->
        binary

      :roman_numeric ->
        binary |> part_chapter_numeric(opts) |> part_chapter_roman(opts)

      :numeric ->
        part_chapter_numeric(binary, opts)

      :roman ->
        part_chapter_roman(binary, opts)

      :alphabetic ->
        Regex.replace(
          ~r/^(#{type_regex})[ ]([A-Z])[ ]?([ A-Z]+)/m,
          binary,
          fn _, part_chapter, value, text ->
            index = Legl.conv_alphabetic_classes(value)
            "#{component}#{index} #{part_chapter} #{value} #{text}"
          end
        )
    end
  end

  def part_chapter_numeric(binary, [type_regex, component]) do
    Regex.replace(
      ~r/^(#{type_regex})[ ](\d+)[ ]?(#{@region_regex})(.*)/m,
      binary,
      "#{component}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}"
    )
    # 🔺F226🔺PART 7U.K.Transitional provisions
    # [🔺F141🔺 CHAPTER 1A E+W [F142 Water supply licences and sewerage licences]
    |> (&Regex.replace(
          ~r/^(\[?🔺F\d+🔺)[ ]?(#{type_regex})[ ](\d+[A-Z]?)[ ]?(#{@region_regex})(.*)/m,
          &1,
          "#{component}\\g{3} \\g{1} \\g{2} \\g{3} \\g{5} [::region::]\\g{4}"
        )).()
  end

  def part_chapter_roman(binary, [type_regex, component]) do
    # 🔺F1🔺Part IE+W The National Parks Commission
    # 🔺F902🔺 [PART IIIAE+W Promotion of the Efficient Use of Water
    # Part IU.K. Wildlife
    Regex.replace(
      ~r/^(\[?🔺?F?\d*🔺?)[ ]?(\[?#{type_regex})[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3})([A-Z]?)[ ]?(#{@region_regex})(.+)/m,
      binary,
      fn _, amd_code, part_chapter, tens, units, alpha, region, text ->
        numeral = tens <> units

        {remaining_numeral, last_numeral} = String.split_at(numeral, -1)

        # IO.inspect("#{part}, #{tens}, #{units}, #{text}, #{numeral}, #{remaining_numeral}, #{last_numeral}")

        # last_numeral = String.last(numeral)
        # remaining_numeral = String.slice(numeral, 0..(String.length(numeral) - 2))

        case Dictionary.match?("#{last_numeral}#{text}") do
          true ->
            value = Legl.conv_roman_numeral(remaining_numeral)

            "#{component}#{value}#{alpha} #{part_chapter} #{remaining_numeral} #{last_numeral}#{alpha} #{amd_code}#{text} [::region::]#{region}"

          false ->
            value = Legl.conv_roman_numeral(numeral)

            "#{component}#{value}#{alpha} #{part_chapter} #{numeral}#{alpha} #{amd_code}#{text} [::region::]#{region}"
        end
      end
    )
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
      # Revised cross-heading
      # [❌F87❌ Modification of appointment conditions: EnglandE+W
      |> (&Regex.replace(
            ~r/^(\[❌F\d+❌[ ].*?)(#{@region_regex})$([\s\S]+?#{@regex_components.section})(\d+[A-Z]?)(-?\d*[ ])/m,
            &1,
            "#{@components.heading}\\g{4} \\g{1} [::region::]\\g{2}\\g{3}\\g{4}\\g{5}"
          )).()
      # U.K. REPTILES
      # Small number of headings have the Region first
      |> (&Regex.replace(
            ~r/^(#{@region_regex})[ ]([A-Z].*?)(etc\.)?$([\s\S]+#{@regex_components.section})(\d+[A-Z]?)(-?\d*[ ])/m,
            &1,
            "#{@components.heading}\\g{5} \\g{2}\\g{3} [::region::]\\g{1}\\g{4}\\g{5}\\g{6}"
          )).()
      |> (&Regex.replace(
            ~r/^([A-Z].*?)(etc\.)?(#{@region_regex})$([\s\S]+?#{@regex_components.section})(\d+[A-Z]?)(-?\d*[ ])/m,
            &1,
            "#{@components.heading}\\g{5} \\g{1}\\g{2} [::region::]\\g{3}\\g{4}\\g{5}\\g{6}"
          )).()
      |> (&Regex.replace(
            ~r/^([A-Z].*?)(etc\.)?(#{@country_regex})$([\s\S]+?#{@regex_components.section})(\d+[A-Z]?)(-?\d*[ ])/m,
            &1,
            "#{@components.heading}\\g{5} \\g{1}\\g{2} [::region::]\\g{3}\\g{4}\\g{5}\\g{6}"
          )).()

  def get_heading(binary, :regulation),
    do:
      binary
      |> (&Regex.replace(
            ~r/^([A-Z].*?)(#{@region_regex})(\n#{@regex_components.article})(\d+[A-Z]?)/m,
            &1,
            "#{@components.heading}\\g{4} \\g{1} [::region::]\\g{2}\\g{3}\\g{4}"
          )).()
      # Not every heading in Regulations has a Region
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
      # 🔺F2🔺...S  Desc: a revoked heading
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
      binary
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z]?)\((\d{1,3})\)[ ]?(.*)(#{@region_regex})/m,
            &1,
            "#{@components.section}\\g{1}-\\g{2} \\g{1}(\\g{2}) \\g{3} [::region::]\\g{4}"
          )).()
      # 6B.(1)Section 2(1) does not entitle
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z]?)\.\((\d{1,3})\)[ ]?(.*)(#{@region_regex})$/m,
            &1,
            "#{@components.section}\\g{1}-\\g{2} \\g{1}.(\\g{2}) \\g{3} [::region::]\\g{4}"
          )).()
      # A1The net-zero emissions targetS
      |> (&Regex.replace(
            ~r/^([A-Z]\d{1,3})([A-Z].*)(#{@region_regex})$/m,
            &1,
            "#{@components.section}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      # 8ANitrogen balance sheetS
      # 18D Group 2 offences and licences etc. : power to enter premises E+W
      # 19XBOffences in connection with enforcement powersE+W
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z][A-Z]?)[ ]?([A-Z].*)(#{@region_regex})$/m,
            &1,
            "#{@components.section}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      # 14NSpecies control orders: entry by warrant etc.S
      # 19ZD Power to take samples: ScotlandS
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z][A-Z]?)[ ]?([A-Z].*)(#{@country_regex})$/m,
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
      # 1 Protection of wild birds, their nests and eggs.S
      |> (&Regex.replace(
            ~r/^(\d{1,3})[ ]?(.*?)(#{@country_regex})$/m,
            &1,
            "#{@components.section}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      #
      |> (&Regex.replace(
            ~r/^(\d{1,3})\((\d{1,3})\)[ ]?(.*)/m,
            &1,
            "#{@components.section}\\g{1}-\\g{2} \\g{1}(\\g{2}) \\g{3}"
          )).()
      |> Legl.Utility.rm_dupe_spaces("\\[::section::\\]")

  @doc """
  Parse amended sections of Acts.
  Formats:

  """
  def get_A_section(binary, :act),
    do:
      binary
      |> (&Regex.replace(
            ~r/^#{@regex_components.section}(\[?F\d+)[ ](.*)[ ](.*?)(#{@region_regex})$/,
            &1,
            "#{@components.section}\\g{2} \\g{1} \\g{2} \\g{3} [::region::]\\g{4}"
          )).()

  @doc """
  Parse sub-sections of Acts.
  Formats:
  (1)Text
  """
  def get_sub_section(binary, :act),
    # (1)[F60 [F61 The [F62 Natural Resources Body
    do:
      Regex.replace(
        ~r/^(\[?F?\d*[A-Z]?\((\d+[A-Z]?)\))[ ]?([,\[“A-Z])/m,
        binary,
        "#{@components.sub_section}\\g{2} \\g{1} \\g{3}"
      )
      # [🔺F5🔺(1)The provisions
      # [🔺F50🔺(1)] In this Part of this Act
      # [🔺F250🔺 (1) ]In relation to land in Wales
      # [🔺F252🔺 (2) Subsection (3) applies where—
      # [🔺F416🔺 (1) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
      # [🔺F34🔺 ( 2 ) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
      # 🔺X9🔺 (1)The enactments mentioned
      |> (&Regex.replace(
            ~r/^(\[?🔺[FX]\d+[A-Z]?🔺)[ ]?\([ ]?(\d+[A-Z]?)[ ]?\)([\] ]*)(.*)/m,
            &1,
            "#{@components.sub_section}\\g{2} \\g{1} (\\g{2}) \\g{3} \\g{4}"
          )).()
      # 🔺F28🔺 [ (4A) In any proceedings
      |> (&Regex.replace(
            ~r/^(🔺F\d+🔺[ ]\[[ ]?\((\d+[A-Z]?)\))(.*)/m,
            &1,
            "#{@components.sub_section}\\g{2} \\g{1} \\g{3}"
          )).()
      # 🔺F383🔺 [🔺F384🔺 (1) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
      |> (&Regex.replace(
            ~r/^(🔺F\d+🔺[ ]\[🔺F\d+[A-Z]?🔺[ ]?\((\d+[A-Z]?)\))(.*)/m,
            &1,
            "#{@components.sub_section}\\g{2} \\g{1} \\g{3}"
          )).()

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
      # 3.  A declaration of conformity must include—S
      |> (&Regex.replace(
            ~r/^(\d+)(\.[ ]+.*)(#{@country_regex})$/m,
            &1,
            "#{@components.article}\\g{1} \\g{1}\\g{2} [::region::]\\g{3}"
          )).()
      # 3.—[🔺F4🔺(1) These Regulations apply to energy-related products.]
      |> (&Regex.replace(
            ~r/^(\d+[A-Z]?)\.(?:#{<<226, 128, 148>>}|\-)(\[?🔺F\d+🔺)\((\d+)\)/m,
            &1,
            "#{@components.article}\\g{1}-\\g{3} \\0"
          )).()
      #
      |> (&Regex.replace(
            ~r/^(\d+)\.[ ]+/m,
            &1,
            "#{@components.article}\\g{1} \\0"
          )).()
      # [🔺F21🔺8E.—(1) The Scottish
      |> (&Regex.replace(
            ~r/^(\[?🔺F\d+🔺)(\d+[A-Z])\.(?:#{<<226, 128, 148>>}|\-)\((\d+)\)/m,
            &1,
            "#{@components.article}\\g{2}-\\g{3} \\0"
          )).()
      # 12A.—(1) This regulation
      |> (&Regex.replace(
            ~r/^(\d+[A-Z])\.(?:#{<<226, 128, 148>>}|\-)\((\d+)\)/m,
            &1,
            "#{@components.article}\\g{1}-\\g{2} \\0"
          )).()
      # 21A.  The maximum amount
      |> (&Regex.replace(
            ~r/^(\d+[A-Z])(\.[ ]+)/m,
            &1,
            "#{@components.article}\\g{1} \\0"
          )).()
      # [🔺F21🔺8.—(1) The Scottish
      |> (&Regex.replace(
            ~r/^(\[?🔺F\d+🔺)(\d+)\.(?:#{<<226, 128, 148>>}|\-)\((\d+)\)/m,
            &1,
            "#{@components.article}\\g{2}-\\g{3} \\0"
          )).()
      # 🔺F226🔺25.  . . .
      # 🔺F80🔺4A.  . .
      |> (&Regex.replace(
            ~r/^(\[?🔺F\d+🔺)(\d+[A-Z]?)(\.[ ]+[\. ]*)/m,
            &1,
            "#{@components.article}\\g{2} \\g{1} \\g{2}\\g{3}"
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
      # 🔺F187🔺(10) . .   Desc: a revoked sub_article
      |> (&Regex.replace(
            ~r/^(\[?🔺F\d+🔺)(\((\d+)\)[\. ]*)/m,
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
      # [🔺F535🔺 SCHEDULE ZA1 E+WBirds which re-use their nests
      |> (&Regex.replace(
            ~r/^(\[?🔺F?\d*🔺)[ ]?(SCHEDULES?|Schedules?)[ ]?([A-Z]*\d*[A-Z]?)[ ]?(#{@region_regex})([^.]*?)(?:\n)/m,
            &1,
            "#{@components.annex}\\g{3} \\g{1} \\g{2} \\g{3} \\g{5} [::region::]\\g{4}\n"
          )).()
      # [🔺F227🔺SCHEDULE [🔺F228🔺1] U.K.SUSTAINABILITY CRITERIA
      |> (&Regex.replace(
            ~r/^(\[?🔺?F?\d*🔺?)(SCHEDULES?|Schedules?)[ ]?(\[?🔺F?\d*🔺)(\d*[A-Z]?)(\]?)[ ]?(#{@region_regex})([^.]*?)(?:\n)/m,
            &1,
            "#{@components.annex}\\g{4} \\g{1} \\g{2} \\g{3} \\g{4}\\g{5} \\g{7} [::region::]\\g{6}\n"
          )).()
      # SCHEDULE E+W+S . . . 🔺F14🔺
      |> (&Regex.replace(
            ~r/^(SCHEDULE|Schedule)[ ]?(#{@region_regex})(.*?🔺F\d+🔺)(?:\n)/m,
            &1,
            "#{@components.annex}1 \\g{1} \\g{3} [::region::]\\g{2}\n"
          )).()
      # [🔺F661🔺 SCHEDULE 9B SInvasive alien species: defences and licences
      |> (&Regex.replace(
            ~r/^(\[?🔺?F?\d*🔺?)[ ](SCHEDULES?|Schedules?)[ ]?(\d*[A-Z]?)[ ]?(#{@country_regex})([^.]*?)(?:\n)/m,
            &1,
            "#{@components.annex}\\g{3} \\g{1} \\g{2} \\g{3} \\g{5} [::region::]\\g{4}\n"
          )).()
      # SCHEDULE 4 U.K. Animals the Sale etc. of Which is Restricted
      |> (&Regex.replace(
            ~r/^(SCHEDULE|Schedule)[ ]?(\d+)[ ]*(#{@region_regex})[ ]?(.*[^.])(?:\n)/m,
            &1,
            "#{@components.annex}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}\n"
          )).()
      # SCHEDULE 5 S Animals which are Protected [F931 under Section 9]
      |> (&Regex.replace(
            ~r/^(SCHEDULE|Schedule)[ ]?(\d+)[ ]*(#{@country_regex})[ ]?(.*[^.])(?:\n)/m,
            &1,
            "#{@components.annex}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}\n"
          )).()
      # SCHEDULE 1 Application to the Crown etc.
      # Schedule 1A contains—
      # A reference to a schedule that has to be filtered out with capitalisation
      |> (&Regex.replace(
            ~r/^(SCHEDULE|Schedule)[ ]?(\d+[A-Z]?)[ ]([A-Z][^.]*?|[A-Z].*etc\.)(?:\n)/m,
            &1,
            "#{@components.annex}\\g{2} \\g{1} \\g{2} \\g{3}\n"
          )).()
      # SCHEDULE U.K.List of the elements referred to in regulation 18(5)
      |> (&Regex.replace(
            ~r/^(SCHEDULES?|Schedules?)[ ]?(#{@region_regex})([A-Z][^.]*?)(?:\n)/m,
            &1,
            "#{@components.annex}1 \\g{1} \\g{3} [::region::]\\g{2}\n"
          )).()
      # SCHEDULE Identified Improvement Measures
      |> (&Regex.replace(
            ~r/^(?:SCHEDULE|Schedule)[^S|^s][ ]?[A-Z][^.]*?(?:\n)/m,
            &1,
            "#{@components.annex}1 \\0"
          )).()
      |> (&Regex.replace(
            ~r/^(?:THE SCHEDULE|The Schedule)[ ]?[^.]*?(?:\n)/m,
            &1,
            "#{@components.annex}1 \\0"
          )).()
      |> (&Regex.replace(
            ~r/^(SCHEDULES|Schedules)/m,
            &1,
            "#{@components.annex} \\0"
          )).()
      # remove double, triple and quadruple spaces
      |> (&Regex.replace(
            ~r/^(\[::annex::\].*)/m,
            &1,
            fn _, x -> String.replace(x, ~r/[ ]{2,4}/, " ") end
          )).()

  def provision_before_schedule(binary),
    do:
      binary
      |> (&Regex.replace(
            ~r/^(Regulation.*|Article.*|Section.*)\n(\[::annex::].*)/m,
            &1,
            "\\g{2} 📌\\g{1}"
          )).()

  def get_table(binary),
    do:
      binary
      |> (&Regex.replace(
            ~r/^Table[ ](\d+)/m,
            &1,
            "#{@components.table}\\g{1} \\0"
          )).()
      |> (&Regex.replace(
            ~r/.+?\t.*/m,
            &1,
            "#{@components.table_row}\\0"
          )).()
      |> (&Regex.replace(
            ~r/^(?:[\dA-Z\(]).+?\t.+?\t.*/m,
            &1,
            "#{@components.table_row}\\0"
          )).()

  def rm_table_ref(binary),
    do:
      binary
      |> (&Regex.replace(
            ~r/^(#{@regex_components.table}|#{@regex_components.sub_table}[\S\s]*?)(#{@regex_components.sub_article})/m,
            &1,
            "\\g{1}"
          )).()

  def get_sub_table(binary),
    do:
      binary
      |> (&Regex.replace(
            ~r/^Table[ ]\d+\.(\d+)/m,
            &1,
            "#{@components.sub_table}\\g{1} \\0"
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
  def get_amendments(binary, _type),
    do:
      binary
      |> (&Regex.replace(
            ~r/^(Textual[ ]Amendments)/m,
            &1,
            "#{@components.amendment_heading}\\g{1}"
          )).()
      |> (&Regex.replace(
            ~r/^🔻F\d+🔻.*/m,
            &1,
            "#{@components.amendment}\\0"
          )).()

  def get_modifications(binary, _type),
    do:
      binary
      |> (&Regex.replace(
            ~r/^(Modifications etc\.[ ]\(not altering text\))/m,
            &1,
            "#{@components.modification_heading}\\g{1}"
          )).()
      |> (&Regex.replace(
            ~r/^(🇲C\d+🇲)([^\.\(].*)/m,
            &1,
            "#{@components.modification}\\g{1}\\g{2}"
          )).()

  def get_commencements(binary, _type),
    do:
      Regex.replace(
        ~r/^(Commencement[ ]Information)/m,
        binary,
        "#{@components.commencement_heading}\\g{1}"
      )
      |> (&Regex.replace(
            ~r/^(🇨I\d+🇨)([^\.\(].*)/m,
            &1,
            "#{@components.commencement}\\g{1}\\g{2}"
          )).()

  def get_extents(binary, _type),
    do:
      Regex.replace(
        ~r/^(Extent[ ]Information)/m,
        binary,
        "#{@components.extent_heading}\\g{1}"
      )
      |> (&Regex.replace(
            ~r/^(🇪E\d+🇪)([^\.\(].*)/m,
            &1,
            "#{@components.extent}\\g{1}\\g{2}"
          )).()

  def get_editorial(binary, _type),
    do:
      Regex.replace(
        ~r/^(Editorial[ ]Information)/m,
        binary,
        "#{@components.editorial_heading}\\g{1}"
      )
      |> (&Regex.replace(
            ~r/^(🇽X\d+🇽)([^\.\(].*)/m,
            &1,
            "#{@components.editorial}\\g{1}\\g{2}"
          )).()

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
              # [::section::][F39 5-1 5[F39(1)]Para
              Regex.match?(~r/\d+[ ]\d+-\d+[ ]/, x) -> :section_and_sub_section
              # [::section::][F384A-1 [F384A(1)
              Regex.match?(~r/\d+[A-Z]-\d+/, x) -> :amended_section_and_sub_section
              # [::section::][F332A [F332A
              Regex.match?(~r/\d+[A-Z]/, x) -> :amended_section_A
              # [::section::][F332A [F332A
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
              # [::sub_section::][F48 2A [F48(2A) Para
              Regex.match?(~r/\d+[ ]\d+[A-Z][ ]/, x) -> :amended_sub_section
              # [::sub_section::][F42 2 [F42(2) Para
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

      "[::part::]" <> x, acc ->
        case String.match?(x, ~r/\[::region::\]/) do
          true -> ["[::part::]#{x}" | acc]
          _ -> [~s/[::part::]#{x} [::region::]/ | acc]
        end

      x, acc ->
        [x | acc]
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @components_dedupe "\\[::editorial_heading::\\]|\\[::editorial::\\]|\\[::amendment::\\]|\\[::commencement::\\]"
  def rm_emoji(binary, emojii) when is_list(emojii) do
    Enum.reduce(emojii, binary, fn emoji, acc ->
      Regex.replace(~r/#{emoji}([A-Z]\d+)#{emoji}/m, acc, "\\g{1} ")
    end)
    |> Legl.Utility.rm_dupe_spaces(@components_dedupe)
  end
end
