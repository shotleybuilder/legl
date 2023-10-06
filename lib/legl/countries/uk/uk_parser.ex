defmodule UK.Parser do
  @moduledoc false

  alias Legl.Countries.Uk.AirtableArticle.UkArticleQa, as: QA
  alias Types.Component
  @components %Component{}

  @regex_components Component.mapped_components_for_regex()

  @region_regex UK.region()
  @country_regex UK.country()
  @geo_regex UK.geo()

  import Legl,
    only: [
      amendment_emoji: 0
    ]

  @uk_cardinals ~s(One Two Three Four Five Six Seven Eight Nine Ten)

  # @regex_uk_cardinals Regex.replace(~r/\n/, @uk_cardinals, "")
  #                    |> (&Regex.replace(~r/[ ]/, &1, "|")).()

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

  @cols Legl.Utility.cols()

  def parser(binary, %{type: :act, html?: true} = opts) do
    binary
    |> get_title()
    |> provision_before_schedule(opts)
    # |> get_dbl_A_heading(:act)
    |> get_A_heading(:act)
    |> Legl.Parser.join("UK")
    |> move_region_to_end()
    |> add_missing_region()
    |> rm_emoji(["⭕", "❌"])
    |> clean_pins()
    |> rm_pins()
  end

  def parser(binary, %{type: :act} = opts) do
    binary =
      binary
      |> get_title()
      |> get_A_part(:act)
      |> get_A_chapter(:act)
      |> get_part_chapter(:part)
      |> get_part_chapter(:chapter)
      |> get_modifications(:act)
      |> get_amendments(:act)
      |> get_commencements(:act)
      |> get_extents(:act)
      |> get_editorial(:act)

    {main, schedules} = separate_main_and_schedules(binary)

    IO.puts("\nLENGTH OF MAIN and ANNEXES")
    IO.puts("main length: #{String.length(main)}")
    IO.puts("schedules length: #{String.length(schedules)}")

    main =
      main
      |> get_A_section(:act, :section)
      |> get_section_with_period(@components.section, opts)
      |> get_section(:act, @components.section)
      |> get_sub_section(:act, @components.sub_section)

    schedules =
      case schedules do
        "" ->
          ""

        _ ->
          schedules
          |> get_annex()
          |> provision_before_schedule(opts)
          |> get_A_section(:act, :paragraph)
          |> get_section_with_period(@components.paragraph, opts)
          |> get_section(:act, @components.paragraph)
          |> get_sub_section(:act, @components.sub_paragraph)
      end

    binary = ~s/#{main}\n#{schedules}/

    binary =
      binary
      |> get_table()
      |> rm_floating_regions()
      |> get_numbered_headings(opts)
      |> get_signed_section()
      # |> revise_section_number(:act)
      |> get_A_heading(:act)
      |> get_heading(opts)
      |> Legl.Parser.join()
      # |> Legl.Parser.rm_tabs()
      |> move_region_to_end()
      |> add_missing_region()
      |> rm_emoji(["🇨", "🇪", "🇲", "🇽", "🔺", "🔻", "⭕", "❌"])
      |> QA.qa(opts)

    binary
  end

  def parser(binary, %{type: :regulation} = opts) do
    binary
    |> get_title()
    |> provision_before_schedule(opts)
    # |> get_dbl_A_heading(:regulation)
    |> get_A_heading(:regulation)
    # for double headng
    |> get_A_heading(:regulation)
    |> Legl.Parser.join("UK")
    |> move_region_to_end()
    |> add_missing_region()
    |> rm_emoji(["⭕", "❌"])
    |> clean_pins()
    |> rm_pins()
  end

  def separate_main_and_schedules(binary) do
    with true <- String.contains?(binary, "[::annex::]") do
      [main, schedules] = String.split(binary, "[::annex::]", parts: 2)
      {main, ~s/[::annex::]#{schedules}/}
    else
      false -> {binary, ""}
    end
  end

  def get_title(binary) do
    IO.puts("GET_TITLE/1")
    "#{@components.title} #{binary}"
  end

  @doc """
  Function returns the numeric value of Roman Part and Chapter numbers if used
  """
  def get_A_part(binary, :act) do
    # [::part::][F508 Part 2A Regulation of provision of infrastructure [::region::]U.K.
    # [::part::]F902 [PART IIIA Promotion of the Efficient Use of Water [::region::]E+W
    # [::part::][F1472 Part 7A Further provision about regulation [::region::]U.K.
    regex =
      ~r/^#{@regex_components.part}(.*?)[ ](?:\[?PART|\[?Part)[ ](.*?)(\]?)[ ](.*?)\[::region::\](.*)$/m

    binary
    |> (&Regex.replace(
          regex,
          &1,
          fn _, ef, num, bkt, txt, region ->
            [_, t, u, p] = Regex.run(~r/(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})(.*)/, num)
            conv_num = ~s/#{Legl.conv_roman_numeral(t <> u)}/ <> p

            "#{@components.part}#{conv_num} #{ef} PART #{num}#{bkt} #{txt} [::region::]#{region}"
          end
        )).()
  end

  def get_A_chapter(binary, :act) do
    # [::chapter::][F141 CHAPTER 1A [F142 Water supply licences and sewerage licences] [::region::]E+W
    # [::chapter::][F690 CHAPTER 2A [F691 Supply duties etc: water supply licensees] [::region::]E+W
    # [::chapter::][F1126 Chapter 2A Duties relating to sewerage services: sewerage licensees [::region::]E+W
    # [::chapter::][F1188 CHAPTER 4 Storm overflows [::region::]E+W
    regex =
      ~s/^#{@regex_components.chapter}(.*?)[ ](?:\\[?CHAPTER|\\[?Chapter)[ ](.*?)[ ](.*?)\\[::region::\\](.*)$/

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          fn _, ef, num, txt, region ->
            conv_num = conv_roman(num)

            "#{@components.chapter}#{conv_num} #{ef} CHAPTER #{num} #{txt} [::region::]#{region}"
          end
        )).()
  end

  @doc """
  PART and Roman Part Number concatenate when copied e.g. PART IINFORMATION

  Amended Part and Chapter are parsed in Annotation Module and are fully formed
  in the binary and do not need parsing here
  """
  def get_part_chapter(binary, type) do
    [type_regex, component] =
      opts =
      case type do
        :part ->
          ["PART|Part", "#{@components.part}"]

        :chapter ->
          ["CHAPTER|Chapter|chapter", "#{@components.chapter}"]
      end

    scheme =
      cond do
        Regex.match?(
          ~r/^(#{type_regex})[ ]+\d+/m,
          binary
        ) and
            Regex.match?(
              ~r/^(#{type_regex})[ ]+I/m,
              binary
            ) ->
          :roman_numeric

        Regex.match?(
          ~r/^(#{type_regex})[ ]+\d+/m,
          binary
        ) ->
          :numeric

        Regex.match?(~r/^(#{type_regex})[ ]+A/m, binary) ->
          :alphabetic

        Regex.match?(~r/^(#{type_regex})[ ]+I/m, binary) ->
          :roman

        true ->
          false
      end

    IO.puts("SCHEME #{type_regex} #{scheme}")

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
      ~r/^(#{type_regex})[ ](\d+)[ ]?(#{@geo_regex})(.*)/m,
      binary,
      "#{component}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}"
    )
  end

  def part_chapter_roman(binary, [type_regex, component]) do
    # Part IU.K. Wildlife

    Regex.replace(
      ~r/^(#{type_regex})[ ](XC|XL|L?X{0,3})(IX|IV|V?I{0,3})([A-D]?)[ ]?(#{@geo_regex})(.*)/m,
      binary,
      fn match, part_chapter, tens, units, alpha, region, text ->
        IO.inspect(match, label: "part_chapter_roman/2")
        # Initial or full caps for part / chapter
        part_chapter =
          cond do
            # text is captialised
            Regex.match?(~r/[A-Z]{2,}/, text) ->
              Regex.replace(~r/chapter/, part_chapter, "CHAPTER")
              |> (&Regex.replace(~r/part/, &1, "PART")).()

            # text is snake case
            Regex.match?(~r/[A-Z][a-z]+/, text) ->
              Regex.replace(~r/chapter/, part_chapter, "Chapter")
              |> (&Regex.replace(~r/part/, &1, "Part")).()

            true ->
              part_chapter
          end

        numeral = tens <> units

        {remaining_numeral, last_numeral} = String.split_at(numeral, -1)

        # IO.inspect("#{part}, #{tens}, #{units}, #{text}, #{numeral}, #{remaining_numeral}, #{last_numeral}")

        # last_numeral = String.last(numeral)
        # remaining_numeral = String.slice(numeral, 0..(String.length(numeral) - 2))

        case Dictionary.match?("#{last_numeral}#{text}") do
          true ->
            value = Legl.conv_roman_numeral(remaining_numeral)

            "#{component}#{value}#{alpha} #{part_chapter} #{remaining_numeral} #{last_numeral}#{alpha} #{text} [::region::]#{region}"

          false ->
            value = Legl.conv_roman_numeral(numeral)

            "#{component}#{value}#{alpha} #{part_chapter} #{numeral}#{alpha} #{text} [::region::]#{region}"
        end
      end
    )
  end

  @doc """
    The Flood and Water Mgt Act 2010 has numbered headings
    1. Key concepts and definitionsE+W
  """
  def get_numbered_headings(binary, %{numbered_headings: false}), do: binary

  def get_numbered_headings(binary, %{type: :act}) do
    regex = ~s/^(\\d+)(\\.[ ].*)(#{@region_regex})$/

    Regex.scan(~r/#{regex}/m, binary)
    |> IO.inspect(label: "Numbered Headings", width: @cols)

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          "#{@components.heading}\\g{1} \\g{1}\\g{2} [::region::]\\3"
        )).()
  end

  @doc """
  Parse Act section headings
  Format
  Heading
  There is an initial captialisation and no ending period
  """
  def get_heading(binary, %{type: :act}) do
    tag = ~s/(?:#{@regex_components.section}|#{@regex_components.paragraph})/

    binary
    # U.K. REPTILES Small number of headings have the Region first
    |> (&Regex.replace(
          ~r/^(#{@region_regex})[ ]([A-Z].*?)(etc\.)?$([\s\S]+#{tag})(\d+[A-Z]?)(-\d*[ ])?/m,
          &1,
          "#{@components.heading}\\g{5} \\g{2}\\g{3} [::region::]\\g{1}\\g{4}\\g{5}\\g{6}"
        )).()
    |> (&Regex.replace(
          ~r/^([A-Z].*?)(etc\.)?(#{@region_regex})$(\n#{tag})(\d+[A-Z]?)(-\d*[ ])?/m,
          &1,
          "#{@components.heading}\\g{5} \\g{1}\\g{2} [::region::]\\g{3}\\g{4}\\g{5}\\g{6}"
        )).()
    |> (&Regex.replace(
          ~r/^([A-Z].*?)(etc\.)?(#{@region_regex})$([\s\S]+?#{tag})(\d+[A-Z]?)(-\d*[ ])?/m,
          &1,
          "#{@components.heading}\\g{5} \\g{1}\\g{2} [::region::]\\g{3}\\g{4}\\g{5}\\g{6}"
        )).()
    |> (&Regex.replace(
          ~r/^([A-Z].*?)(etc\.)?(#{@country_regex})$([\s\S]+?#{tag})(\d+[A-Z]?)(-\d*[ ])?/m,
          &1,
          "#{@components.heading}\\g{5} \\g{1}\\g{2} [::region::]\\g{3}\\g{4}\\g{5}\\g{6}"
        )).()
  end

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

  def get_A_heading(binary, :act) do
    tag = ~s/(?:#{@regex_components.section}|#{@regex_components.paragraph})/

    regex =
      ~r/^#{@regex_components.heading}([^\d].*?)[ ](.*?)\[::region::\](.*)$([\s\S]+?#{tag})(\d+[A-Z]*)(-?\d*[ ])/m

    binary
    |> (&Regex.replace(
          regex,
          &1,
          "#{@components.heading}\\g{5} \\g{1} \\g{2}[::region::]\\g{3}\\g{4}\\g{5}\\g{6}"
        )).()
  end

  def get_A_heading(binary, :regulation) do
    IO.write("GET_A_HEADING/2")
    tag = ~s/(?:#{@regex_components.article}|#{@regex_components.paragraph})/

    regex = ~r/^#{@regex_components.heading}([^\d].*)$([\s\S]+?#{tag})(\d+[A-Z]*\.?\d?)/m

    binary =
      Regex.replace(
        regex,
        binary,
        "#{@components.heading}\\g{3} \\g{1} \\g{2}\\g{3}\\g{4}"
      )

    IO.puts("...complete")

    binary
  end

  def get_dbl_A_heading(binary, :regulation) do
    IO.write("GET_DBL_A_HEADING/2")
    tag = ~s/(?:#{@regex_components.paragraph})/

    regex =
      ~r/^#{@regex_components.heading}(.*)\n^#{@regex_components.heading}(.*)$([\s\S]+?#{tag})(.+?)[ ]/m

    binary =
      Regex.replace(
        regex,
        binary,
        fn _, hdg1, hdg2, para_txt, hdg_id ->
          {hdg2_id, hdg1_id} =
            case hdg_id |> String.graphemes() |> Enum.frequencies() do
              %{"." => 2} -> {Regex.run(~r/^\d+\.\d+/, hdg_id), Regex.run(~r/^\d+/, hdg_id)}
              %{"." => 1} -> {Regex.run(~r/^\d+\.\d+/, hdg_id), Regex.run(~r/^\d+/, hdg_id)}
              _ -> {hdg_id, hdg_id}
            end

          "#{@components.heading}#{hdg1_id} #{hdg1}\n#{@components.heading}#{hdg2_id} #{hdg2} #{para_txt}#{hdg_id} "
        end
      )

    IO.puts("...complete")

    binary
  end

  @doc """
  Parse sections of Acts.  The equivalent of Regulation articles.
  Formats:
  1Text - targetted by the 2nd regex
  1(1)Text - targetted by the 1st regex
  """
  def get_section(binary, :act, component),
    do:
      binary
      # 32Z1Certificate purchase orders: procedureE+W+S
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z]\d)[ ]?(.*)(#{@region_regex})/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      # 1(1) Foobar U.K.
      # 3[F873(1)FoobarE+W+S
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z]?)(\[?F?\d*)\((\d{1,3})\)[ ]?(.*?)(#{@region_regex})$/m,
            &1,
            "#{component}\\g{1}-\\g{3} \\g{1}\\g{2}(\\g{3}) \\g{4} [::region::]\\g{5}"
          )).()
      # 1(1) Foobar S
      # 1(1) Foobar
      # 3[F873(1)FoobarS
      # regex - the end of line marker pulls the non-greedy to the end when region not present
      # cannot use for region because it would match every clause
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z]?)(\[?F?\d*)\((\d{1,3})\)[ ]?(.*?)(#{@country_regex})?$/m,
            &1,
            "#{component}\\g{1}-\\g{3} \\g{1}\\g{2}(\\g{3}) \\g{4} [::region::]\\g{5}"
          )).()
      # A1The net-zero emissions targetS
      |> (&Regex.replace(
            ~r/^([A-Z]\d{1,3})([A-Z].*)(#{@region_regex})$/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      # A1E+WThe mineral planning authority for an area in England may,
      |> (&Regex.replace(
            ~r/^([A-Z]\d{1,3})(#{@region_regex})([A-Z].*)/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{3} [::region::]\\g{2}"
          )).()
      # 8ANitrogen balance sheetS
      # 18D Group 2 offences and licences etc. : power to enter premises E+W
      # 19XBOffences in connection with enforcement powersE+W
      # 16B [F129 CMA's] power of veto following report: supplementaryE+W
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z][A-Z]?)[ ]?([A-Z\[].*)(#{@region_regex})$/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      # 14NSpecies control orders: entry by warrant etc.S
      # 19ZD Power to take samples: ScotlandS
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z][A-Z]?)[ ]?([A-Z].*)(#{@country_regex})$/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      # 53ExtentU.K.
      # Has to come before the next to avoid 'E' of Extent a proxy for England
      |> (&Regex.replace(
            ~r/^(\[?)(\d{1,3})[ ]?(.*?)(#{@geo_regex})$/m,
            &1,
            "#{component}\\g{2} \\g{1}\\g{2} \\g{3} [::region::]\\g{4}"
          )).()
      # 19AE+WThe adoption duty does not apply to a drainage system
      # 1SBefore making an order the Minister shall prepare
      |> (&Regex.replace(
            ~r/^(\d{1,3}[A-Z]*?)(#{@geo_regex})([A-Z].*)/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{3} [::region::]\\g{2}"
          )).()

      # 1 Protection of wild birds, their nests and eggs.S
      |> (&Regex.replace(
            ~r/^(\d{1,3})[ ]?(.*?)(#{@country_regex})$/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
          )).()
      # 144. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
      # Excludes
      # 6.  To scuttle any vessel or floating container anywhere at sea
      |> (&Regex.replace(
            ~r/^(\d{1,3})(( \. \.|\. \. )[\. ]+)/m,
            &1,
            "#{component}\\g{1} \\g{1}\\g{3}\\g{2}"
          )).()

      # 🔺X1🔺 28 Customer service committees.U.K.
      # 🔺X4🔺 7E+W+SSections 79 and 80 of that Act
      |> (&Regex.replace(
            ~r/^🔺(X\d+)🔺[ ]?(\d{1,3})[ ]?(.+?)(#{@region_regex})$/m,
            &1,
            "#{component}\\g{2} \\g{1} \\g{2} \\g{3} [::region::]\\g{4}"
          )).()
      |> (&Regex.replace(
            ~r/^🔺(X\d+)🔺[ ]?(\d{1,3})[ ]?(#{@region_regex})(.*)/m,
            &1,
            "#{component}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}"
          )).()
      # 5The Authority may, with the approval of the ... staff as it may determine.
      |> (&Regex.replace(
            ~r/^(\d{1,3})[ ]?([A-Z].*)/m,
            &1,
            "#{component}\\g{1} \\g{1} \\g{2}"
          )).()
      |> Legl.Utility.rm_dupe_spaces("\\[::section::\\]")

  def get_section_with_period(binary, _component, %{"s_.": false} = _opts), do: binary

  def get_section_with_period(binary, component, %{"s_.": true} = _opts) do
    binary
    # Exclude U.K.
    |> (&Regex.replace(
          ~r/^(\d{1,3}[A-Z]*?)(#{@geo_regex})[ ]?(.*)/m,
          &1,
          "#{component}\\g{1} \\g{1} \\g{3} [::region::] \\g{2}"
        )).()
    # 6B.(1)Section 2(1) does not entitle
    |> (&Regex.replace(
          ~r/^(\d{1,3}[A-Z]*)\.\((\d{1,3})\)[ ]?(.*)(#{@region_regex})$/m,
          &1,
          "#{component}\\g{1}-\\g{2} \\g{1}.(\\g{2}) \\g{3} [::region::]\\g{4}"
        )).()
    # 109B.Cancellation or variation of restriction noticesE+W
    |> (&Regex.replace(
          ~r/^(\d{1,3}[A-Z]*)\.[ ]?(.*)(#{@region_regex})$/m,
          &1,
          "#{component}\\g{1} \\g{1} \\g{2} [::region::]\\g{3}"
        )).()
    # 161A.Notices requiring persons to carry out works and operationsE+W
    # 33A.U.K.Bartley Water, above the toll bridge at Eling.
    |> (&Regex.replace(
          ~r/^(\d{1,3}[A-Z]*)\.[ ]?(.*?)(#{@region_regex})(.*)/m,
          &1,
          "#{component}\\g{1} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}"
        )).()
    # 2.The following are relevant provisions in relation to all holders of a licence under section 7—
    |> (&Regex.replace(
          ~r/^(\d{1,3}[A-Z]*)\.[ ]?(.*)/m,
          &1,
          "#{component}\\g{1} \\g{1} \\g{2} [::region::]"
        )).()
  end

  @doc """
  Parse amended sections of Acts.
  Formats:
  [::section::]X2 [F438 29 Consumer complaintsU.K.
  [::section::]41E [F739 41E References to [F740 CMA] .E+W+S
  """
  def get_A_section(binary, :act, component) do
    r_component = Map.get(@regex_components, component)
    component = Map.get(@components, component)

    binary
    |> String.split("\n")
    |> Enum.reduce([], fn line, acc ->
      case String.starts_with?(line, "[::section::]") or
             String.starts_with?(line, "[::paragraph::]") do
        true ->
          case Regex.match?(~r/\[::region::\]/, line) do
            # region can be set by uk_annotation.ex
            true ->
              [line | acc]

            false ->
              regex = ~s/^#{r_component}(.*?)(#{@geo_regex})$/
              # QA.scan_and_print(line, regex, "A-Section-1")

              case Regex.run(~r/#{regex}/, line) do
                [_, txt, region] ->
                  "#{component}#{txt} [::region::]#{region}"
                  |> (&[&1 | acc]).()

                nil ->
                  regex = ~s/^#{r_component}(\\d+[A-Z]*.*?)(#{@geo_regex})(.*)/
                  # QA.scan_and_print(line, regex, "A-Section-2")

                  case Regex.run(~r/#{regex}/, line) do
                    [_, n, region, txt] ->
                      "#{component}#{n} #{txt} [::region::]#{region}"
                      |> (&[&1 | acc]).()

                    nil ->
                      [line | acc]
                  end
              end
          end

        false ->
          [line | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @doc """
  Parse sub-sections of Acts.
  Formats:
  (1)Text
  [(1)]Text
  """
  def get_sub_section(binary, :act, component),
    do:
      Regex.replace(
        ~r/^(\[?\((\d+[A-Z]?[A-Z]?)\)\]?)[ ]?([,\[“A-Z]\.?)/m,
        binary,
        "#{component}\\g{2} \\g{1} \\g{3}"
      )

  def get_sub_section(binary, :regulation, component),
    do:
      Regex.replace(
        ~r/^[^#{@regex_components.part}|#{@regex_components.chapter}|#{@regex_components.annex}]([^\n]+)[^\.](etc\.)?\n#{@regex_components.article}\d+[ ](\d+)/m,
        binary,
        "#{component}\\g{3} \\0"
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
      #
      |> (&Regex.replace(
            ~r/^(\d+)\.[ ]+/m,
            &1,
            "#{@components.article}\\g{1} \\0"
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

  @doc """
  Mark-up Schedules
  egs
  SCHEDULE 1.Name

  """
  def get_annex(binary),
    do:
      binary
      # SCHEDULE 4 U.K. Animals the Sale etc. of Which is Restricted
      # SCHEDULE 10E+W PROCEDURE RELATING TO BYELAWS UNDER SECTION 157
      # SCHEDULE 2ABU.K.Duties of supply exemption holders
      |> (&Regex.replace(
            ~r/^(SCHEDULE|Schedule)[ ]?(\d+[A-Z]*?)[ ]*(#{@region_regex})[ ]?(.*([etc\.]|[^\.]))(?:\n)/m,
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
      # SCHEDULEU.K. Enactments Repealed
      |> (&Regex.replace(
            ~r/^(SCHEDULES?|Schedules?)[ ]?(#{@region_regex})[ ]?([A-Z][^.]*?)(?:\n)/m,
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

  def provision_before_schedule(binary, %{pbs?: false} = _opts), do: binary

  def provision_before_schedule(binary, %{pbs?: true} = _opts) do
    IO.puts("PROVISION BEFORE SCHEDULE/1")

    regex =
      ~r/^(Regulation.*|Article.*|Section.*)\n(\[::annex::\].*)|^(\[?F\d+ )?(Regulation.*|Article.*|Section.*)\n(\[::annex::\].*)/m

    binary
    |> (&Regex.replace(
          regex,
          &1,
          "\\g{3}📌\\g{1}\\g{2}"
        )).()
  end

  def get_table(binary),
    do:
      binary
      |> (&Regex.replace(
            ~r/^Table[ ](\d+)/m,
            &1,
            "#{@components.table}\\g{1} \\0"
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

  def move_region_to_end(binary) do
    Regex.replace(~r/(.*)([ ]\[::region::\].*?)([ 📌].*)/m, binary, "\\g{1}\\g{3}\\g{2}")
    |> (&Regex.replace(~r/[ ]{2, }\[::region::\]/m, &1, " [::region::]")).()
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

      "[::chapter::]" <> x, acc ->
        case String.match?(x, ~r/\[::region::\]/) do
          true -> ["[::chapter::]#{x}" | acc]
          _ -> [~s/[::chapter::]#{x} [::region::]/ | acc]
        end

      "[::paragraph::]" <> x, acc ->
        case String.contains?(x, "[::region::]") do
          true -> ["[::paragraph::]#{x}" | acc]
          _ -> [~s/[::paragraph::]#{x} [::region::]/ | acc]
        end

      "[::sub_paragraph::]" <> x, acc ->
        case String.contains?(x, "[::region::]") do
          true -> ["[::sub_paragraph::]#{x}" | acc]
          _ -> [~s/[::sub_paragraph::]#{x} [::region::]/ | acc]
        end

      x, acc ->
        [x | acc]
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @components_dedupe "\\[::editorial_heading::\\]|\\[::editorial::\\]|\\[::amendment::\\]|\\[::commencement::\\]"
  def rm_emoji(binary, emojii) when is_list(emojii) do
    IO.write("RM_EMOJI/2")

    binary =
      Enum.reduce(emojii, binary, fn emoji, acc ->
        Regex.replace(~r/#{emoji}/m, acc, "")
      end)
      |> Legl.Utility.rm_dupe_spaces(@components_dedupe)

    IO.puts("...complete")
    binary
  end

  def conv_roman(term) do
    cond do
      # numeric with opt postfix 1A
      Regex.match?(~r/\d+[A-Z]*/, term) ->
        term

      # roman with postfix eg 1A
      Regex.match?(~r/([IVX]+)([A-Z]+)/, term) ->
        # Split terms like IIIA
        [_, roman, amend] = Regex.run(~r/(.*)([A-Z]+)/, term)
        # Legl.conv_roman_numeral/1 returns Integer value
        "#{Legl.conv_roman_numeral(roman)}#{amend}"

      # roman
      Regex.match?(~r/([IVX]+)/, term) ->
        Legl.conv_roman_numeral(term)

      true ->
        IO.puts("ERROR: conv_roman/2 #{term}")
    end
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

  def rm_floating_regions(binary) do
    Regex.replace(~r/^(#{@region_regex})$/m, binary, "")
  end

  def rm_explanatory_note(binary),
    do:
      Regex.replace(
        ~r/^Explanatory Note[\s\S]+|EXPLANATORY NOTE[\s\S]+/m,
        binary,
        ""
      )

  def clean_pins(binary) do
    IO.write("CLEAN_PINS/1")

    binary =
      binary
      |> (&Regex.replace(~r/📌[ ]/, &1, "📌")).()
      |> (&Regex.replace(~r/📌”/, &1, "”")).()
      |> (&Regex.replace(~r/📌;/, &1, "”")).()
      |> (&Regex.replace(~r/“[ ]+📌/, &1, "“")).()

    IO.puts("...complete")
    binary
  end

  defp rm_pins(binary) do
    IO.write("UK.Parser.rm_pin_at_end_of_line/1")

    binary =
      binary
      # at the end of a line
      |> (&Regex.replace(
            ~r/📌$/m,
            &1,
            ""
          )).()
      # before region tag
      |> (&Regex.replace(
            ~r/📌\[::region::\]/,
            &1,
            " [::region::]"
          )).()

    IO.puts("...complete")
    binary
  end
end
