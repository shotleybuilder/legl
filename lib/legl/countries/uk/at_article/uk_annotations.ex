defmodule Legl.Countries.Uk.AirtableArticle.UkAnnotations do
  @moduledoc """
  Functions to find and tag annotations such as amendments, modifications etc.
  """

  # UK.region()
  @region_regex UK.region()
  @country_regex UK.country()
  @geo_regex @region_regex <> "|" <> @country_regex

  @components %Types.Component{}
  @regex_components Types.Component.mapped_components_for_regex()

  alias Legl.Countries.Uk.AirtableArticle.UkArticleQa, as: QA
  alias Legl.Countries.Uk.AirtableArticle.UkEfCodes, as: EfCodes
  alias Legl.Countries.Uk.AirtableArticle.UkArticleSectionsOptimisation, as: Optimiser

  def annotations(binary, %{type: :act} = opts) do
    binary =
      binary
      |> floating_efs()
      |> tag_txt_amend_efs()
      |> part_efs()
      |> chapter_efs()
      # x heading was here
      |> tag_table_efs()
      |> tag_mods_cees()
      |> tag_commencing_ies()
      |> tag_extent_ees()
      |> tag_editorial_xes()
      |> cross_heading_efs()

    {main, schedules} = separate_main_and_schedules(binary)

    main =
      main
      |> tag_section_range()
      |> tag_section_end_efs()
      |> tag_section_efs_i(opts)
      |> tag_section_efs_ii(opts)
      |> section_ss_efs()
      |> tag_sub_section_range(@components.sub_section)
      |> tag_sub_section_efs(@components.sub_section)

    schedules =
      case schedules do
        # there are no schedules to process
        "" ->
          ""

        _ ->
          schedules
          |> tag_schedule_range()
          |> tag_schedule_efs(opts)
          |> tag_schedule_section_efs()
          |> tag_sub_section_range(@components.sub_paragraph)
          |> tag_sub_section_efs(@components.sub_paragraph)
      end

    binary = ~s/#{main}\n#{schedules}/

    binary =
      binary
      |> tag_sub_sub_section_efs()
      |> tag_section_wash_up()
      |> tag_heading_efs()
      |> tag_txt_amend_efs_wash_up()
      |> space_efs()

    # |> rm_emoji("🔸")

    if opts.qa == true, do: binary |> QA.qa_list_spare_efs(opts) |> QA.list_headings(opts)

    # Confirmation msg to console
    binary |> (&IO.puts("\n\nannotated: #{String.slice(&1, 0, 100)}...")).()

    binary
  end

  def separate_main_and_schedules(binary) do
    patterns = %{
      # multiple schedules and region
      xs_region: ~r/^(SCHEDULES|Schedules)[ ]?(#{@region_regex})/m,
      # multiple schedules and no region
      xs: ~r/^(SCHEDULES|Schedules)/m,
      # one schedule and region
      "1s_region": ~r/^((?:THE )?SCHEDULE|(?:The)?Schedule)[ ]?(#{@region_regex})/m,
      # one schedule
      "1s": ~r/^(?:(?:THE )?SCHEDULE|(?:The)?Schedule)/m
    }

    s_pattern =
      cond do
        Regex.match?(patterns.xs_region, binary) -> :xs_region
        Regex.match?(patterns.xs, binary) -> :xs
        Regex.match?(patterns[:"1s_region"], binary) -> :"1s_region"
        Regex.match?(patterns[:"1s"], binary) -> :"1s"
        true -> :no_schedules
      end

    case s_pattern do
      :no_schedules ->
        {binary, ""}

      _ ->
        [_, main, schedules] =
          binary
          |> (&Regex.replace(
                Map.get(patterns, s_pattern),
                &1,
                fn regex_result ->
                  separate_main_and_schedules_result(regex_result)
                end
              )).()
          |> (&Regex.run(~r/^([\s\S]+)(\[::annex::\][\s\S]+)$/, &1)).()

        {main, schedules}
    end
  end

  defp separate_main_and_schedules_result([_, title, region]) do
    "#{@components.annex}#{title} [::region::]#{region}"
  end

  defp separate_main_and_schedules_result(match) do
    "#{@components.annex}#{match} [::region::]"
  end

  @doc """
  Function to remove floating efs
  Fxxx\nfoobar becomes Fxxx foobar
  """
  def floating_efs(binary) do
    regex = ~s/^(\\[?F\\d+)(?:\\r\\n|\\n)/
    QA.scan_and_print(binary, regex, "float")

    Regex.replace(
      ~r/#{regex}/m,
      binary,
      "\\g{1}"
    )
  end

  @doc """
  A function to process tag_efs in 'original.txt' outside of running the parse process.
  Result is saved to 'a_original.txt'.

  iex> Legl.Countries.Uk.UkClean.tag_efs()
  """
  def tag_efs(opts) do
    txt =
      Legl.txt("original")
      |> Path.absname()
      |> File.read!()
      |> annotations(opts)

    Legl.txt("a_original")
    |> Path.absname()
    |> File.write!(txt)
  end

  @doc """
  🔻 is used to tag Textual Amendments separately to other amendment tags
  """
  def tag_txt_amend_efs(binary) do
    regex =
      [
        ~s/Ss?c?h?s?\\.[ ][^\\.]/,
        ~s/S[Ss][\\. ]/,
        ~s/s[ ]?\\./,
        ~s/W[O|o]rds?/,
        ~s/In[ ]s.[ ]/,
        ~s/The[ ]words[ ]repealed/,
        ~s/Definition[ ]|Entry?i?e?s?/,
        ~s/By.*?S\\.I\\./,
        ~s/Para\\.?[ ]/,
        ~s/Pt.[ ]/,
        # ~s/Part[ ]/, can be confused with an actual Part clause
        ~s/[Cc]ross[- ]?heading/,
        ~s/Chapter.*?\\(ss\\.[ ].*?\\)[ ]inserted/,
        ~s/Act repealed/,
        ~s/Sum[ ]in[ ][Ss]\\./
      ]
      |> Enum.join("|")

    binary
    # See uk_annotations.exs for examples and test

    # Missing period on Sch
    # 🔻F296🔻 Sch 2 para. 6 repealed (E.W.) (1.12.1991) by Water
    # Regex uses the + lookahead which doesn't capture
    |> (&Regex.replace(~r/Sch(?=[ ])/m, &1, "Sch.")).()
    |> (&Regex.replace(~r/S\.[ ]I\./, &1, "S.I.")).()
    |> (&Regex.replace(
          ~r/^(F\d+)[ ]?(#{regex})/m,
          &1,
          "🔻\\g{1}🔻 \\g{2}"
        )).()
    |> (&Regex.replace(
          ~r/^(F\d+?)(\d{4} c\. \d+)/m,
          &1,
          "🔻\\g{1}🔻 \\g{2}"
        )).()
  end

  def part_efs(binary) do
    # See uk_annotations.exs for examples and test
    regex = ~r/^(\[?F\d+)(\[?F\d+)?[ ]?(\[?(?:PART|Part))[ ]?([IVX\d].*?)(#{@geo_regex})(.*)/m

    QA.scan_and_print(binary, regex, "PART")

    binary
    |> (&Regex.replace(
          regex,
          &1,
          "#{@components.part}\\g{1}\\g{2} \\g{3} \\g{4} [::region::]\\g{5}"
        )).()
    |> Legl.Utility.rm_dupe_spaces(@regex_components.part)
  end

  def chapter_efs(binary) do
    # See uk_annotations.exs for examples and test
    regex = ~s/^(\\[?F\\d+)(CHAPTER|Chapter)(.*)(#{@region_regex})(.*)/

    QA.scan_and_print(binary, regex, "CHAPTER")

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          "#{@components.chapter}\\g{1} \\g{2} \\g{3} \\g{5} [::region::]\\g{4}"
        )).()
    |> Legl.Utility.rm_dupe_spaces(@regex_components.chapter)
  end

  def tag_schedule_efs(binary, opts \\ %{qa_sched_s?: false, qa_sched_s_limit?: false}) do
    # See uk_annotations.exs for examples and test
    # [F37SCHEDULE 2S Election -> picks-up the 'E' as the region if [A-Z] is used
    # X18 SCHEDULE 4E+W+S Repeals
    regex =
      ~r/^(\[?[XF]\d+)?(\[?F?\d*)[ ]?(SCHEDULE|Schedule)[ ]([A-Z]*\d+[A-Z]*)[\] \.]?(#{@geo_regex})[ ]?([A-Z]?.*)/m

    if opts.qa_sched_s? == true do
      QA.scan_and_print(binary, regex, "SCHEDULE", opts.qa_sched_s_limit?)
    end

    binary
    |> (&Regex.replace(
          regex,
          &1,
          "#{@components.annex}\\g{4} \\g{1}\\g{2} \\g{3} \\g{4} \\g{6} [::region::]\\g{5}"
        )).()
    |> (&Regex.replace(
          ~r/^(\[?)(F\d{1,3})[ ]?SCHEDULES/m,
          &1,
          "#{@components.annex} \\0"
        )).()
    |> Legl.Utility.rm_dupe_spaces(@regex_components.annex)
  end

  @doc """
  Function reads amendment clauses looking for "cross-heading inserted"
  When found the associated Fxxx code is read and stored in a list
  These Fxxx codes are then searched for and marked up as headings
  """
  def cross_heading_efs(binary) do
    # See uk_annotations.exs for examples and test
    regex = ~r/^🔻(F\d+)🔻.*?[Cc]ross[ -]?heading.*(?:inserted|substituted)/m

    count = QA.scan_and_print(binary, regex, "cross heading", true)

    {acc, io} =
      case count do
        0 ->
          {binary, nil}

        _ ->
          Regex.scan(regex, binary)
          |> Enum.map(fn [_, ef_code] -> ef_code end)
          |> Enum.reduce({binary, []}, fn ef, {acc, io} ->
            regex_ = ~r/^(\[?)#{ef}[ ]?([^0-9].*?)(#{@geo_regex})$/m
            result = Regex.run(regex_, acc)
            io = [result | io]

            acc =
              acc
              |> (&Regex.replace(
                    regex_,
                    &1,
                    "#{@components.heading}\\g{1}#{ef} \\g{2} [::region::]\\g{3}"
                  )).()

            {acc, io}
          end)
      end

    IO.inspect(io, label: "CROSS HEADINGS PROCESSED")
    acc
  end

  def tag_table_efs(binary) do
    # 🔻F162🔻 Sch. 1A Table 2 substituted (N.I.) (1.6.2018) by
    regex = ~r/🔻(F\d+)🔻[ ]Sch.[ ]\d+[A-Z]{0,2}[ ](Table[ ]\d+).*/m
    QA.scan_and_print(binary, regex, "TABLES", true)

    Regex.scan(regex, binary)
    |> Enum.reduce(binary, fn [_, ef, txt], acc ->
      acc
      |> (&Regex.replace(
            ~r/^((?:\[?F\d+)*?)(\[?)#{ef}[ ]?(\[?)[ ]?#{txt}(.*)/m,
            &1,
            "#{@components.table}\\g{1}\\g{2}#{ef} \\g{3}#{txt}\\g{4}"
          )).()
    end)
  end

  @doc """
  Function reads amendment clauses looking for S. insertions and substitutions
  When matched the assoociated Fxxx code is read and stored in a list
  concatenated with Ss. number
  These Fxxx codes are then searched for and marked up as sections
  PATTERN.  AMENDED SECTIONS 1A, 6B, 10ZA etc.
  """
  def tag_section_efs_i(binary, opts \\ %{qa_si?: false, qa_si_limit?: false}) do
    regex = ~r/^🔻(F\d+)🔻[ ]S\.[ ](\d+[A-Z]+)[^\(].*/m

    if opts.qa_si? == true do
      QA.scan_and_print(binary, regex, "S. SECTIONS I", opts.qa_si_limit?)
    end

    tag_sections(binary, regex)
  end

  @doc """
  PATTERN.  NORMAL SECTIONS 1, 6, 10 etc.
  """
  def tag_section_efs_ii(binary, opts \\ %{qa_sii?: false, qa_sii_limit?: false}) do
    regex = ~r/^🔻(F\d+)🔻[ ]S\.[ ](\d+).*?(?:repealed|substituted|omitted|ceased|shall cease).*/m

    if opts.qa_sii? == true do
      QA.scan_and_print(binary, regex, "S. SECTIONS II", opts.qa_sii_limit?)
    end

    tag_sections(binary, regex)
  end

  def tag_sections(binary, regex) do
    Regex.scan(regex, binary)
    |> Enum.reduce(binary, fn [_line, ef, sn], acc ->
      tag_sections_replace(acc, ef, sn, @components.section)
    end)
  end

  def tag_sections_replace(binary, ef, sn, component) do
    # {b}
    b = _bracket = ~s/(\\[?)/

    regex = %{
      ef_b4_sn:
        ~r/^((?:\[?F\d+)*?)#{b}#{ef}[ ]?#{b}[ ]?#{sn}[ \.]?([A-Z\[\] ][^\()].*|\((1)\).*)/m,
      sn_b4_ef: ~r/^#{b}[ ]?#{sn}[ ]?#{b}#{ef}[ ]?#{b}([A-Z].*|\((\d+)\).*)/m,
      ef_b4_efs_b4_sn: ~r/^(\[?)#{ef}((?:\[?F\d+)*?)#{sn}[ \.]?(\]?[A-Z].*)/m,
      x: ~r/^(X\d+)[ ]?(\[?)#{ef}#{sn}/m
    }

    if ef == "F128" do
      Regex.run(regex.ef_b4_sn, binary)
      |> IO.inspect(label: "DEBUG tag_sections_replace/3")
    end

    binary
    # EF before SN
    |> (&Regex.replace(
          regex.ef_b4_sn,
          &1,
          fn
            _m, pre_efs, bkt1, bkt2, txt, "" ->
              "#{component}#{sn} #{pre_efs}#{bkt1}#{ef} #{bkt2}#{sn} #{txt}"

            _m, pre_efs, bkt1, bkt2, txt, "1" ->
              "#{component}#{sn}-1 #{pre_efs}#{bkt1}#{ef} #{bkt2}#{sn} #{txt}"

            # a sub-section! Let's leave alone
            m, _pre_efs, _bkt1, _bkt2, _txt, _ ->
              "#{m}"
          end
        )).()
    # SN before EF
    |> (&Regex.replace(
          regex.sn_b4_ef,
          &1,
          fn
            _m, bkt1, bkt2, bkt3, txt, "" ->
              "#{component}#{sn} #{bkt1}#{sn} #{bkt2}#{ef} #{bkt3}#{txt}"

            _m, bkt1, bkt2, bkt3, txt, "1" ->
              "#{component}#{sn}-1 #{bkt1}#{sn} #{bkt2}#{ef} #{bkt3}#{txt}"

            # a sub-section! Let's leave alone
            m, _pre_efs, _bkt1, _bkt2, _txt, _ ->
              "#{m}"
          end
        )).()
    # EF before efs before SN
    |> (&Regex.replace(
          regex.ef_b4_efs_b4_sn,
          &1,
          "#{component}#{sn} \\g{1}#{ef}\\g{2} #{sn} \\g{3}"
        )).()
    # X
    |> (&Regex.replace(
          regex.x,
          &1,
          "#{component}#{sn} \\g{1} \\g{2}#{ef} #{sn}"
        )).()
  end

  @doc """
  Function for sections when the amendment number is at the end
  e.g. 1—10.E+W. . . . .. . . . . . . . . . . . . . . F110
  """
  def tag_section_end_efs(binary) do
    regex = ~s/^(\\d+)(?:-|—|,[ ]?)?(\\d+)?\\.?(#{@geo_regex})(.*?)(F(\\d+))$/

    QA.scan_and_print(binary, regex, "SECTION END EFS", true)

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          fn _, from, to, region, txt, prefix, ef ->
            # take the F9 number from the 'from' number 914 becomes 14
            # F2 and 22 becomes 2
            from = String.replace_prefix(from, ef, "")

            # account for a range of 1 (to being "")
            to =
              if to == "" do
                from
              else
                to
              end

            f = String.to_integer(from)
            t = String.to_integer(to)

            for n <- f..t do
              ~s/[::section::]#{n} #{prefix} #{n} #{txt} [::region::]#{region}/
            end
            |> Enum.join("\n")
          end
        )).()
  end

  @doc """
  Repealed ranges
    F914—22.. . . . . . . .
    Textual Amendments
    F9S. 5(1)–(4)
  Become

  """
  def tag_section_range(binary) do
    regex1 = ~r/^F(\d+)(?:-|—|, )(\d+)?([ \.]+)(#{@geo_regex})([\s\S]+?^🔻F(\d+)🔻)/m
    # 37—40.. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . F147 U.K.
    # 45,46. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .F16 U.K.
    regex2 = ~r/^(\d+)(?:-|—|,[ ]?)(\d+)?([ \.]+)F(\d+)[ ]?(#{@geo_regex})([\s\S]+?^🔻?F(\d+)🔻?)/m

    QA.scan_and_print(binary, regex1, "Leading Ef SECTION RANGE", true)
    QA.scan_and_print(binary, regex2, "Trailing Ef SECTION RANGE", true)

    binary
    |> (&Regex.replace(
          regex1,
          &1,
          fn _, from, to, txt, region, amd, ef ->
            replacement_range_string(ef, amd, from, to, txt, region)
          end
        )).()
    # |> QA.qa_print_line("37—40")
    |> (&Regex.replace(
          regex2,
          &1,
          fn _match, from, to, txt, ef, region, amd, _ef_qa ->
            # account for a range of 1 (to being "")
            replacement_range_string(ef, amd, from, to, txt, region)
          end
        )).()
  end

  def replacement_range_string(ef, amd, from, to, txt, region) do
    {from, to} = from_to(String.to_integer(from), String.to_integer(to))

    txt = String.slice(txt, 0..10)

    for n <- from..to do
      ~s/[::section::]#{n} F#{ef} #{n} #{txt} [::region::]#{region}/
    end
    |> Enum.join("\n")
    |> Kernel.<>(amd)
  end

  @doc """
  takes F125SCHEDULES 9—14E+W. .
  and makes
  [::annex::]9 F125 SCHEDULE 9 . .  [::region::]E+W
  [::annex::]10 F125 SCHEDULE 10 .  [::region::]E+W
  [::annex::]11 F125 SCHEDULE 11 .  [::region::]E+W
  [::annex::]12 F125 SCHEDULE 12 .  [::region::]E+W
  [::annex::]13 F125 SCHEDULE 13 .  [::region::]E+W
  [::annex::]14 F125 SCHEDULE 14 .  [::region::]E+W
  """
  def tag_schedule_range(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(F\d+)SCHEDULES[ ](\d+)(?:-|—|,[ ]?)(\d+)[\.]?(#{@geo_regex})(.*)/m,
          &1,
          fn _, ef, from, to, region, txt ->
            f = String.to_integer(from)
            t = String.to_integer(to)

            for n <- f..t do
              ~s/[::annex::]#{n} #{ef} SCHEDULE #{n} #{txt} [::region::]#{region}/
            end
            |> Enum.join("\n")
          end
        )).()
    # Trailing Ef with region before the text
    |> (&Regex.replace(
          ~r/^SCHEDULES[ ](\d+)(?:-|—|,[ ]?|[ ]AND[ ])(\d+)[\.]?(#{@geo_regex})(.*?)(F\d+)([\s\S]+?^🔻?(F\d+)🔻?)/m,
          &1,
          fn m, from, to, region, txt, ef, amd, ef_qa ->
            schedule_replacement_range_string(m, from, to, region, txt, ef, amd, ef_qa)
          end
        )).()
  end

  def schedule_replacement_range_string(_, from, to, region, _txt, ef, amd, ef) do
    # Only if ef == ef_qa
    {from, to} = from_to(String.to_integer(from), String.to_integer(to))

    txt = ". . . . ."

    for n <- from..to do
      ~s/[::annex::]#{n} #{ef} SCHEDULE #{n} #{txt} [::region::]#{region}/
    end
    |> Enum.join("\n")
    |> Kernel.<>(amd)
  end

  def schedule_replacement_range_string(m, _from, _to, _region, _txt, _ef, _amd, _ef_qa), do: m

  defp from_to(from, from), do: {from, from}
  defp from_to(from, to), do: {from, to}

  @doc """
  Function reads amendment clauses looking for Ss. insertions and substitutions
  When matched the assoociated Fxxx code is read and stored in a list
  concatenated with Ss. number
  These Fxxx codes are then searched ofr and marked up as sections
  """
  def section_ss_efs(binary) do
    # CSV when there are 2x insertions / substitutions
    # 🔻F124🔻 Ss. 16A, 16B inserted
    # 🔻F188🔻 Ss. 17FA, 17FB inserted
    # CSV for 3!
    # 🔻F112🔻 Ss. 6, 6A, 6B substituted (16.5.2001
    # RANGE when there are >2x insertions / substitutions

    # 🔻F366🔻 Ss. 150-153 repealed (1.4.1996)
    # 🔻F62🔻 Ss 27, 27A substituted

    binary =
      String.split(binary, "\n")
      |> Enum.reduce([], fn line, acc ->
        case String.starts_with?(line, "🔻") do
          false ->
            [line | acc]

          true ->
            # Ensure Ss is Ss.
            # 🔻F62🔻 Ss 27, 27A substituted
            line
            |> (&Regex.replace(~r/[ ]Ss[ ]/m, &1, " Ss. ")).()
            # Ensure SS is Ss.
            # 🔻F520🔻 SS. 30A-30F inserted
            |> (&Regex.replace(~r/[ ]SS\./m, &1, " Ss.")).()
            # Ensure ss is Ss.
            # 🔻F229🔻 Chapter IIA (ss. 91A-91B)
            # 🔻F561🔻 Cross heading, ss. 33A and 33B inserted
            |> (&Regex.replace(~r/([ \(])ss\./m, &1, "\\g{1}Ss.")).()
            # 🔻F561🔻 Cross heading, ss. 33A and 33B inserted
            # Make 'and' a ','
            |> (&Regex.replace(~r/([ ]Ss\.[ ]\d+[A-Z]*)[ ]and/m, &1, "\\g{1},")).()
            # sometimes the en dash (codepoint 8211) \u2013 is used for ranges
            |> (&Regex.replace(~r/–/m, &1, "-")).()
            |> (&[&1 | acc]).()
        end
      end)
      |> Enum.reverse()
      |> Enum.join("\n")

    ef_codes = section_ss_ef_codes(binary)

    ef_codes = Optimiser.optimise_ef_codes(ef_codes, "SS.")

    ef_tags = EfCodes.ef_tags(ef_codes)

    {acc, io} =
      Enum.reduce(ef_tags, {binary, []}, fn {ef, sn, amd_type, _tag}, {acc, io} ->
        regex =
          ~r/^(\[?F?\d*)?(\[?)?#{ef}((?:\[?F?\d*)*)[ ]?(#{sn}[A-Z]{0,2})[ ]?([A-Z \.][A-Za-z \.].*)/m

        io =
          case Regex.run(regex, acc) do
            nil -> io
            [m, _, _, _, _, _] -> [{m, ef, sn, amd_type} | io]
          end

        acc =
          acc
          |> (&Regex.replace(
                regex,
                &1,
                "#{@components.section}\\g{4} \\g{1}\\g{2}#{ef}\\g{3} \\g{4} \\g{5}"
              )).()
          |> Legl.Utility.rm_dupe_spaces(@regex_components.section)

        {acc, io}
      end)

    QA.print_selected_sections(io)
    acc
  end

  def section_ss_ef_codes(binary) do
    # section_number_pattern
    snp = ~s/\\d+[A-Z]{0,2}/

    patterns =
      [
        # 🔻F494🔻 Ss. 33A-33C inserted
        # 🔻F426🔻 Ss. 27H-27K inserted
        # 🔻F490🔻 Ss. 32-35 substituted
        ~s/#{snp}-#{snp}/,
        # 🔻F126🔻 Ss. 31, 32 and 34-42 repealed (E.W.)
        ~s/(?:#{snp},[ ])+#{snp}[ ]and[ ]#{snp}-#{snp}/,
        # 🔻F749🔻 S. 41EA, 41EB inserted
        # 🔻F143🔻 Ss. 17A, 17AA substituted
        # 🔻F276🔻 Ss. 16, 16A, 17 and cross-heading substituted
        ~s/(?:#{snp},[ ])+#{snp}/
      ]
      |> Enum.join("|")

    regex =
      ~r/^🔻(F\d+)🔻(?:.*?[ \()]Ss?\.[ ])(#{patterns}).*?(repealed|inserted|substituted|omitted)/m

    EfCodes.ef_codes(binary, regex, "SS.")
  end

  def build_schedule_regex() do
    # To call in .iex
    # Legl.Countries.Uk.AirtableArticle.UkAnnotations.build_schedule_regex()

    # 🔻F80🔻 Sch. 4 Pt. I para. 9 repealed
    # 🔻F958🔻 Sch. 4 para. 5(1) repealed (1.1.1993) by New Roads
    sn = ~s/\\d+[A-Z]{0,3}/
    # ranges such as 🔻F227🔻 Sch. 4 paras. 33-33C
    # 33-33C -> 33, 33A, 33B, 33C

    snp = ~s/(?:#{sn}-#{sn}|#{sn})/

    and_ = ~s/(?:#{snp},[ ])+#{snp}[ ]and[ ]#{snp}-#{snp}/
    # 🔻F79🔻 Sch. 4 Pt. I paras. 7, 8 repealed
    csv_ = ~s/(?:#{snp},[ ])+#{snp}/

    full =
      [
        ~s/(?:#{snp},[ ])+#{snp}[ ]and[ ]#{snp}-#{snp}/,
        ~s/(?:#{snp},[ ])+#{snp}/,
        snp
      ]
      |> Enum.join("|")

    # The regex in this map are not used in prod.  Helpful for debugging a complex regex
    %{
      and_: ~r/^🔻(F\d+)🔻.*?Schs?\.[ ]\d*[A-Z]*.*?paras?\.[ ]?(#{and_}).*?by/m,
      csv_: ~r/^🔻(F\d+)🔻.*?Schs?\.[ ]\d*[A-Z]*.*?paras?\.[ ]?(#{csv_}).*?by/m,
      snp: ~r/^🔻(F\d+)🔻.*?Schs?\.[ ]\d*[A-Z]*.*?paras?\.[ ]?(#{snp}).*?by/m,
      full: ~r/^🔻(F\d+)🔻.*?Schs?\.[ ]\d*[A-Z]*.*?paras?\.[ ]?(#{full}).*?by/m
    }
  end

  @doc """

  """
  def tag_schedule_section_efs(binary) do
    # See uk_annotations.exs for examples and test
    # section_number_pattern

    regex = build_schedule_regex().full

    ef_codes = EfCodes.ef_codes(binary, regex, "SCHEDULE SS.")

    ef_codes = Optimiser.optimise_ef_codes(ef_codes, "SCHEDULES")

    ef_tags = EfCodes.ef_tags(ef_codes)

    # sn - section number
    Enum.reduce(ef_tags, binary, fn {ef, sn, _amd_type, _tag}, acc ->
      tag_sections_replace(acc, ef, sn, @components.paragraph)
    end)
  end

  def tag_sub_section_efs(binary, component) do
    # See uk_annotations.exs for examples and test
    regex = ~r/^(\[?F\d+)[ ]?(\[?F?\d*)?[ ]*(\[)?\([ ]*([A-Z]*\d+[A-Z]*)[ ]?\)[ ]?(.*)/m

    QA.scan_and_print(binary, regex, "sub-section")

    binary
    |> (&Regex.replace(
          regex,
          &1,
          "#{component}\\g{4} \\g{1}\\g{2} \\g{3}(\\g{4}) \\g{5}"
        )).()
  end

  @doc """
  """
  def tag_sub_section_range(binary, component) do
    binary
    |> (&Regex.replace(
          ~r/^(F\d+)\((\d+)\)(?:-|—)\((\d+)\)([ \.]*)/m,
          &1,
          fn _, ef, from, to, txt ->
            f = String.to_integer(from)
            t = String.to_integer(to)

            for n <- f..t do
              ~s/#{component}#{n} #{ef} (#{n}) #{txt}/
            end
            |> Enum.join("\n")
          end
        )).()
  end

  def tag_sub_sub_section_efs(binary) do
    # See uk_annotations.exs for examples and test
    regex = "^(\\[?F\\d+)(\\[?F?\\d*)?[ ]*(\\[)?\\([ ]*([a-z]*)[ ]?\\)[ ]?(.*)"

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          "🔸\\g{1}\\g{2} \\g{3}(\\g{4}) \\g{5}"
        )).()
  end

  def tag_mods_cees(binary) do
    # See uk_annotations.exs for examples and test
    regex = ~s/^(C\\d+)(.*)/

    QA.scan_and_print(binary, regex, "MODIFICATIONS")

    Regex.replace(
      ~r/#{regex}/m,
      binary,
      "#{@components.modification}\\g{1} \\g{2}"
    )
  end

  def tag_commencing_ies(binary) do
    # See uk_annotations.exs for examples and test
    regex = ~s/^(Commencement Information)\\n(I\\d+)(.*)/

    QA.scan_and_print(binary, regex, "COMMENCEMENTS")

    Regex.replace(
      ~r/#{regex}/m,
      binary,
      "#{@components.commencement_heading}\\g{1}\n#{@components.commencement}\\g{2} \\g{3}"
    )
  end

  def tag_extent_ees(binary) do
    # See uk_annotations.exs for examples and test
    regex = ~s/^(Extent Information)\\n^(E\\d+)(.*)/

    QA.scan_and_print(binary, regex, "EXTENTS")

    Regex.replace(
      ~r/#{regex}/m,
      binary,
      "#{@components.extent_heading}\\g{1}\n#{@components.extent}\\g{2} \\g{3}"
    )
  end

  def tag_editorial_xes(binary) do
    regex = ~s/^(Editorial[ ]Information)\\n^(X\\d+)(.*)/

    # QA.scan_and_print(binary, regex, "EDITORIAL INFORMATION")

    binary =
      Regex.replace(
        ~r/#{regex}/m,
        binary,
        "#{@components.editorial_heading}\\g{1}\n#{@components.editorial}\\g{2} \\g{3}"
      )

    xes = collect_tags("#{Regex.escape(@components.editorial)}X(\\d+)", binary)
    IO.puts("EDITORIAL INFORMATION")
    Enum.reverse(xes) |> Enum.each(fn x -> IO.write("X#{x}, ") end)
    IO.puts("\nCount of Editorial Information xes: #{Enum.count(xes)}\n")

    Enum.reduce(xes, binary, fn x, acc ->
      acc
      |> (&Regex.replace(
            ~r/^(X#{x})([^ ])/m,
            &1,
            "🔺\\g{1}🔺 \\g{2}"
          )).()
      |> (&Regex.replace(
            ~r/^(X#{x})([ ])/m,
            &1,
            "🔺\\g{1}🔺\\g{2}"
          )).()
      # [F505X561 Ploughing of public rights of way.E+W
      |> (&Regex.replace(
            ~r/^\[(F\d+)(X#{x})([^ ])/m,
            &1,
            "\[🔺\\g{1}🔺 🔺\\g{2}🔺 \\g{3}"
          )).()
    end)

    # |> IO.inspect(limit: :infinity)
  end

  @doc """
  Function to tag Fxxx ef_codes preceeding heading clauses
  The function assumes that section clauses have ALL been ID'd and tagged
  Examine the list of spare_efs in the console to ensure the sense of this
  """
  def tag_heading_efs(binary) do
    # F1122[ComplaintsE+W
    # F1631 Operation of pre-1985 schemesE+W
    regex = ~s/^(\\[?F\\d+)[ ]?(.*?)(#{@region_regex})/

    QA.scan_and_print(binary, regex, "heading")

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          "#{@components.heading}\\g{1} \\g{2} [::region::]\\g{3}"
        )).()
  end

  @doc """
  Manually adjusted in original.txt to EF-sp-SN-sp-Region
  """
  def tag_section_wash_up(binary) do
    regex = ~r/^(\[?F\d+)[ ](\d+[A-Z]*)[ \.](?:(#{@geo_regex})(.*)|(.*))/m

    QA.scan_and_print(binary, regex, "SECTION WASH UP", true)

    binary
    |> (&Regex.replace(
          regex,
          &1,
          "#{@components.section}\\g{2} \\g{1} \\g{2} \\g{4}\\g{5} [::region::]\\g{3}"
        )).()
  end

  @doc """
  Function to tag any remaining Textual Amendment clauses
  """
  def tag_txt_amend_efs_wash_up(binary) do
    regex = ~s/^(F\\d+)([^\\.\\[0-9].*)$/

    QA.scan_and_print(binary, regex, "amendment")

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          "🔻\\g{1}🔻 \\g{2}"
        )).()
  end

  @doc """
  Function to put a space between the ef_code and the proceeding text
  """
  def space_efs(binary) do
    binary
    |> (&Regex.scan(
          ~r/(\[?F\d{1,4})([A-Za-z])/,
          &1
        )).()
    |> Enum.count()
    |> (&IO.puts("Count of spacing efs: #{&1}\n")).()

    binary
    |> (&Regex.replace(
          ~r/(\[?F\d{1,4})([A-Za-z])/m,
          &1,
          "\\g{1} \\g{2}"
        )).()
  end

  @doc """
  Works with a single capture e.g. 🔻F(\d+)🔻
  """
  def collect_tags(regex, binary) do
    Regex.scan(~r/#{regex}/, binary)
    |> Enum.map(fn [_match, capture] -> String.to_integer(capture) end)
    |> Enum.sort()
    |> Enum.map(&Integer.to_string(&1))
    |> Enum.reverse()

    # |> IO.inspect(label: "collect_tags")
  end

  def rm_emoji(binary, emoji) do
    Regex.replace(~r/#{emoji}/, binary, "")
  end
end
