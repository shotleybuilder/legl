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
      |> cross_heading_efs()
      |> tag_table_efs()
      |> tag_schedule_efs()
      |> tag_sub_section_efs()
      |> tag_schedule_section_efs()
      |> tag_sub_section_range()
      |> tag_sub_sub_section_efs()
      |> tag_section_range()
      |> tag_section_end_efs()
      |> tag_section_efs_i()
      |> tag_section_efs_ii()
      |> section_ss_efs()
      |> tag_schedule_range()
      |> tag_mods_cees()
      |> tag_commencing_ies()
      |> tag_extent_ees()
      |> tag_editorial_xes()
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
        ~s/Act repealed/
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
    regex = ~s/^(\\[?F\\d+)(\\[?F\\d+)?[ ]?(\\[?(?:PART|Part))(.*?)(#{@geo_regex})(.*)/

    QA.scan_and_print(binary, regex, "PART")

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
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

  def tag_schedule_efs(binary) do
    # See uk_annotations.exs for examples and test
    # [F37SCHEDULE 2S Election -> picks-up the 'E' as the region if [A-Z] is used
    # X18 SCHEDULE 4E+W+S Repeals
    regex =
      ~s/^(\\[?[XF]\\d+)?(\\[?F?\\d*)[ ]?(SCHEDULE|Schedule)[ ]([A-Z]*\\d+[A-Z]*)[\\] ]?(#{@geo_regex})[ ]?([A-Z]?.*)/

    QA.scan_and_print(binary, regex, "SCHEDULE")

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
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
    regex = ~s/^🔻(F\\d+)🔻.*?[Cc]ross[ -]?heading.*(?:inserted|substituted)/

    count = QA.scan_and_print(binary, regex, "cross heading", true)

    case count do
      0 ->
        binary

      _ ->
        Regex.scan(~r/#{regex}/m, binary)
        |> Enum.map(fn [_, ef_code] -> ef_code end)
        |> Enum.reduce(binary, fn ef, acc ->
          regex = ~s/^(\\[?)#{ef}[ ]?([^0-9].*?)(#{@geo_regex})$/
          QA.scan_and_print(acc, regex, "cross headings found", true)

          acc
          |> (&Regex.replace(
                ~r/#{regex}/m,
                &1,
                "#{@components.heading}\\g{1}#{ef} \\g{2} [::region::]\\g{3}"
              )).()
        end)
    end
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
  def tag_section_efs_i(binary) do
    regex = ~r/^🔻(F\d+)🔻[ ]S\.[ ](\d+[A-Z]+)[^\(].*/m

    tag_sections(binary, regex, "S. SECTIONS I", true)
  end

  @doc """
  PATTERN.  NORMAL SECTIONS 1, 6, 10 etc.
  """
  def tag_section_efs_ii(binary) do
    # 🔻F1205🔻 S. 145 and ... repealed -> F1205145. . . . . .
    #

    regex = ~r/^🔻(F\d+)🔻[ ]S\.[ ](\d+).*?(?:repealed|substituted|omitted).*/m

    tag_sections(binary, regex, "S. SECTIONS II", true)
  end

  def tag_sections(binary, regex, label, opt \\ false) do
    QA.scan_and_print(binary, regex, label, opt)

    Regex.scan(regex, binary)
    |> Enum.reduce(binary, fn [_line, ef, sn], acc ->
      tag_sections_replace(acc, ef, sn)
    end)
  end

  def tag_sections_replace(binary, ef, sn) do
    binary
    # EF before SN
    |> (&Regex.replace(
          ~r/^((?:\[?F\d+)*?)(\[?)#{ef}(\[?)#{sn}[ \.]?([A-Z\[ ].*)/m,
          &1,
          "#{@components.section}#{sn} \\g{1}\\g{2}#{ef} \\g{3}#{sn} \\g{4}"
        )).()
    # SN before EF
    |> (&Regex.replace(
          ~r/^(\[?)[ ]?#{sn}[ ]?(\[?)#{ef}[ ]?([A-Z].*)/m,
          &1,
          "#{@components.section}#{sn} \\g{1}#{sn} \\g{2}#{ef} \\g{3}"
        )).()
    # EF before efs before SN
    |> (&Regex.replace(
          ~r/^(\[?)#{ef}((?:\[?F\d+)*?)#{sn}[ \.]?([A-Z].*)/m,
          &1,
          "#{@components.section}#{sn} \\g{1}#{ef}\\g{2} #{sn} \\g{3}"
        )).()
    # X
    |> (&Regex.replace(
          ~r/^(X\d+)[ ]?(\[?)#{ef}#{sn}/m,
          &1,
          "#{@components.section}#{sn} \\g{1} \\g{2}#{ef} #{sn}"
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
    regex1 = ~s/^F(\\d+)(?:-|—|, )(\\d+)?([ \\.]+)(#{@geo_regex})([\\s\\S]+?^🔻F(\\d+)🔻)/
    # 37—40.. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . F147 U.K.
    regex2 =
      ~s/^(\\d+)(?:-|—|, )(\\d+)?([ \\.]+)F(\\d+)[ ]?(#{@geo_regex})([\\s\\S]+?^🔻?F(\\d+)🔻?)/

    QA.scan_and_print(binary, regex1, "SECTION RANGE", true)
    QA.scan_and_print(binary, regex2, "SECTION RANGE", true)

    binary
    |> (&Regex.replace(
          ~r/#{regex1}/m,
          &1,
          fn _, from, to, txt, region, amd, ef ->
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
              ~s/[::section::]#{n} F#{ef} #{n} #{txt} [::region::]#{region}/
            end
            |> Enum.join("\n")
            |> Kernel.<>(amd)
          end
        )).()
    # |> QA.qa_print_line("37—40")
    |> (&Regex.replace(
          ~r/#{regex2}/m,
          &1,
          fn _match, from, to, txt, ef, region, amd, _ef_qa ->
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
              ~s/[::section::]#{n} F#{ef} #{n} #{txt} [::region::]#{region}/
            end
            |> Enum.join("\n")
            |> Kernel.<>(amd)
          end
        )).()
  end

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
            |> (&Regex.replace(~r/[ ]ss\./m, &1, " Ss.")).()
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
      ~s/^🔻(F\\d+)🔻(?:.*?[ ]Ss?\\.[ ])(#{patterns}).*?(repealed|inserted|substituted|omitted)/

    ef_codes = EfCodes.ef_codes(binary, regex, "SS.")

    ef_codes = Optimiser.optimise_ef_codes(ef_codes, "SECTIONS")

    ef_tags = EfCodes.ef_tags(ef_codes)

    {acc, io} =
      Enum.reduce(ef_tags, {binary, []}, fn {ef, sn, amd_type, _tag}, {acc, io} ->
        regex = ~r/^(\[?F?\d*)?(\[?)?#{ef}((?:\[?F?\d*)*)[ ]?#{sn}[ ]?([A-Z \.][a-z \.].*)/m

        io =
          case Regex.run(regex, acc) do
            nil -> io
            [m, _, _, _, _] -> [{m, ef, sn, amd_type} | io]
          end

        acc =
          acc
          |> (&Regex.replace(
                regex,
                &1,
                "#{@components.section}#{sn} \\g{1}\\g{2}#{ef}\\g{3} #{sn} \\g{4}"
              )).()
          |> Legl.Utility.rm_dupe_spaces(@regex_components.section)

        {acc, io}
      end)

    QA.print_selected_sections(io)
    acc
  end

  def build_schedule_regex() do
    # 2, 5-9, 11
    sn = ~s/\\d+[A-Z]{0,3}/
    snp = ~s/(?:#{sn}-#{sn}|#{sn})/

    patterns =
      [
        # ranges such as 🔻F227🔻 Sch. 4 paras. 33-33C
        # 33-33C -> 33, 33A, 33B, 33C
        # ~s/#{snp}-#{snp}/,
        ~s/(?:#{snp},[ ])+#{snp}[ ]and[ ]#{snp}-#{snp}/,
        # 🔻F79🔻 Sch. 4 Pt. I paras. 7, 8 repealed
        ~s/(?:#{snp},[ ])+#{snp}/,
        # 🔻F80🔻 Sch. 4 Pt. I para. 9 repealed
        # 🔻F958🔻 Sch. 4 para. 5(1) repealed (1.1.1993) by New Roads
        snp
      ]
      |> Enum.join("|")

    ~r/^🔻(F\d+)🔻.*Schs?\.[ ]\d*[A-Z]*[ ]?paras?\.[ ]?(#{patterns}).*?by/m
  end

  @doc """

  """
  def tag_schedule_section_efs(binary) do
    # See uk_annotations.exs for examples and test
    # section_number_pattern

    regex = build_schedule_regex()

    ef_codes = EfCodes.ef_codes(binary, regex, "SCHEDULE SS.")

    ef_codes = Optimiser.optimise_ef_codes(ef_codes, "SCHEDULES")

    ef_tags = EfCodes.ef_tags(ef_codes)

    # sn - section number
    Enum.reduce(ef_tags, binary, fn {ef, sn, _, _tag}, acc ->
      tag_sections_replace(acc, ef, sn)
    end)
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
          ~r/^(F\d+)SCHEDULES[ ](\d+)(?:-|—)(\d+)(#{@geo_regex})(.*)/m,
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
  end

  def tag_sub_section_efs(binary) do
    # See uk_annotations.exs for examples and test
    regex = "^(\\[?F\\d+)[ ]?(\\[?F?\\d*)?[ ]*(\\[)?\\([ ]*([A-Z]*\\d+[A-Z]*)[ ]?\\)[ ]?(.*)"

    QA.scan_and_print(binary, regex, "sub-section")

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          "#{@components.sub_section}\\g{4} \\g{1}\\g{2} \\g{3}(\\g{4}) \\g{5}"
        )).()
  end

  @doc """
  takes F1(1)—(5). . . . .
  and makes
  [::annex::]9 F125 SCHEDULE 9 . .  [::region::]E+W
  [::annex::]10 F125 SCHEDULE 10 .  [::region::]E+W
  [::annex::]11 F125 SCHEDULE 11 .  [::region::]E+W
  [::annex::]12 F125 SCHEDULE 12 .  [::region::]E+W
  [::annex::]13 F125 SCHEDULE 13 .  [::region::]E+W
  [::annex::]14 F125 SCHEDULE 14 .  [::region::]E+W
  """
  def tag_sub_section_range(binary) do
    binary
    |> (&Regex.replace(
          ~r/^(F\d+)\((\d+)\)(?:-|—)\((\d+)\)([ \.]*)/m,
          &1,
          fn _, ef, from, to, txt ->
            f = String.to_integer(from)
            t = String.to_integer(to)

            for n <- f..t do
              ~s/[::sub_section::]#{n} #{ef} (#{n}) #{txt}/
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
    regex = ~r/^(F\d+)[ ](\d+[A-Z]*)[ ](#{@geo_regex})(.*)/m

    QA.scan_and_print(binary, regex, "SECTION WASH UP", true)

    binary
    |> (&Regex.replace(
          regex,
          &1,
          "#{@components.section}\\g{2} \\g{1} \\g{2} \\g{4} [::region::]\\g{3}"
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
