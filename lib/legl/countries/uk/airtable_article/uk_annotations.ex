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

  def annotations(binary, %{type: :act} = opts) do
    binary =
      binary
      |> rm_marginal_citations()
      |> floating_efs()
      |> tag_txt_amend_efs()
      |> part_efs()
      |> chapter_efs()
      |> tag_schedule_efs()
      |> cross_heading_efs()
      |> tag_sub_section_range()
      |> tag_sub_section_efs()
      |> tag_sub_sub_section_efs()
      |> tag_section_range()
      |> tag_section_end_efs()
      |> section_efs()
      |> section_ss_efs()
      |> tag_schedule_section_efs()
      |> tag_schedule_range()
      |> tag_mods_cees()
      |> tag_commencing_ies()
      |> tag_extent_ees()
      |> tag_editorial_xes()
      |> tag_section_wash_up()
      |> tag_heading_efs()
      |> tag_txt_amend_efs_wash_up()
      |> space_efs()
      |> rm_emoji("🔸")

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
        ~s/Ss?c?h?\\.[ ][^\\.]/,
        ~s/Ss[ ]/,
        ~s/s[ ]?\\./,
        ~s/W[O|o]rds?/,
        ~s/In[ ]s.[ ]/,
        ~s/The[ ]words[ ]repealed/,
        ~s/Definition[ ]|Entry?i?e?s?/,
        ~s/By.*?S\\.I\\./,
        ~s/Para\\.?[ ]/,
        ~s/Pt.[ ]/,
        # ~s/Part[ ]/, can be confused with an actual Part clause
        ~s/Cross[ ]heading/,
        ~s/Chapter.*?\\(ss\\.[ ].*?\\)[ ]inserted/
      ]
      |> Enum.join("|")

    binary
    # See uk_annotations.exs for examples and test
    |> (&Regex.replace(
          ~r/S\.[ ]I\./,
          &1,
          "S.I."
        )).()
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
    regex =
      ~s/^(\\[?F\\d+)(\\[?F?\\d*)?[ ]?(SCHEDULE|Schedule)[ ]([A-Z]*\\d+[A-Z]*)[ ]?(#{@geo_regex})[ ]?([A-Z]?.*)/

    QA.scan_and_print(binary, regex, "SCHEDULE")

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          "#{@components.annex}\\g{4} \\g{1}\\g{2} \\g{3} \\g{4} \\g{6} [::region::]\\g{5}"
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
    regex = ~s/^🔻(F\\d+)🔻.*?(?:C|c)ross(?:-|[ ])heading.*(?:inserted|substituted)/

    count = QA.scan_and_print(binary, regex, "cross heading")

    case count do
      0 ->
        binary

      _ ->
        x_hdgs =
          Regex.scan(
            ~r/#{regex}/m,
            binary
          )

        x_hdgs
        |> Enum.map(fn [_, ef_code] -> ef_code end)
        |> Enum.reduce(binary, fn ef, acc ->
          acc
          |> (&Regex.replace(
                ~r/^(\[?)#{ef}([^0-9].*?)(#{@region_regex})/m,
                &1,
                "#{@components.heading}\\g{1}#{ef} \\g{2} [::region::]\\g{3}"
              )).()
        end)
    end
  end

  @doc """
  Function reads amendment clauses looking for S. insertions and substitutions
  When matched the assoociated Fxxx code is read and stored in a list
  concatenated with Ss. number
  These Fxxx codes are then searched for and marked up as sections
  """
  def section_efs(binary) do
    # 🔻F2🔻 S. 1A inserted -> [F21AWater Services
    # 🔻F144🔻 S. 17B title substituted -> 17B[F144Meaning of supply
    # 🔻F169🔻 S. 17DA inserted -> [F16917DAGuidance
    # 🔻F685🔻 S. 63A inserted

    # Pattern: [[line, ef, section_number], [line, ef, section_number] ...]
    regex = ~s/^🔻(F\\d+)🔻[ ]S\\.[ ](\\d+[A-Z]+)[^\\(].*/

    QA.scan_and_print(binary, regex, "S. SECTIONS I", true)

    binary =
      Regex.scan(~r/#{regex}/m, binary)
      |> Enum.reduce(binary, fn [_line, ef, x], acc ->
        acc
        |> (&Regex.replace(
              ~r/^(\[?)#{ef}[ ]?#{x}([ A-Z\[])/m,
              &1,
              "#{@components.section}#{x} \\g{1}#{ef} #{x} \\g{2}"
            )).()
        |> (&Regex.replace(
              ~r/^#{x}#{ef}/m,
              &1,
              "#{@components.section}#{x} #{ef} "
            )).()
        # X2[F43829 Consumer complaintsU.K.
        |> (&Regex.replace(
              ~r/^(X\d+)[ ]?(\[?)#{ef}#{x}/m,
              &1,
              "#{@components.section}#{x} \\g{1} \\g{2}#{ef} #{x}"
            )).()
      end)

    # 🔻F886🔻 S. 91 substituted -> [F88691 [F887 Old Welsh
    # 🔻F1205🔻 S. 145 and ... repealed -> F1205145. . . . . .
    #

    regex = ~s/^🔻(F\\d+)🔻[ ]S\\.[ ](\\d+)[ ].*?(?:repealed|substituted|omitted).*/

    QA.scan_and_print(binary, regex, "S. SECTIONS II", true)

    # Pattern: [[line, ef, section_number], [line, ef, section_number] ...]
    Regex.scan(~r/#{regex}/m, binary)
    # |> IO.inspect(label: "section_efs/1")
    |> Enum.reverse()
    |> Enum.reduce(binary, fn [_line, ef, x], acc ->
      acc
      # F1[1 General duties
      |> (&Regex.replace(
            ~r/^(\[?)#{ef}(\[?)#{x}([^0-9])/m,
            &1,
            "#{@components.section}#{x} \\g{1}#{ef} \\g{2}#{x} \\g{3}"
          )).()
      # 🔻F1542🔻 S. 221 substituted -> [221F1542Crown application.E+W
      |> (&Regex.replace(
            ~r/^(\[?)#{x}#{ef}/m,
            &1,
            "#{@components.section}#{x} \\g{1}#{ef} #{x} "
          )).()
      |> (&Regex.replace(
            ~r/^(X\d+)[ ]?(\[?)#{ef}#{x}/m,
            &1,
            "#{@components.section}#{x} \\g{1} \\g{2}#{ef} #{x} "
          )).()
      # F530[F529195 Maps of waterworks.E+W
      |> (&Regex.replace(
            ~r/^(\[?)#{ef}(\[F\d+?)#{x}([^0-9][A-Z\. ].*)(#{@region_regex})/m,
            &1,
            "#{@components.section}#{x} \\g{1}#{ef} \\g{2} #{x} \\g{3}\\g{4}"
          )).()
      # F685[224Application to the Isles of Scilly.E+W
      |> (&Regex.replace(
            ~r/^(\[?)#{ef}(\[)#{x}([^0-9].*)(#{@region_regex})/m,
            &1,
            "#{@components.section}#{x} \\g{1}#{ef} \\g{2} #{x} \\g{3}\\g{4}"
          )).()
    end)
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
    regex = ~s/^F(\\d+)(?:-|—|, )?(\\d+)?([ \\.]+)(#{@geo_regex})([\\s\\S]+?^🔻F(\\d+)🔻)/

    QA.scan_and_print(binary, regex, "SECTION RANGE", true)

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
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
    # RANGE when there are >2x insertions / substitutions
    # 🔻F494🔻 Ss. 33A-33C inserted
    # 🔻F426🔻 Ss. 27H-27K inserted
    # 🔻F143🔻 Ss. 17A, 17AA substituted
    # 🔻F490🔻 Ss. 32-35 substituted
    # 🔻F366🔻 Ss. 150-153 repealed (1.4.1996)
    # 🔻F229🔻 Chapter IIA (ss. 91A-91B)
    # 🔻F62🔻 Ss 27, 27A substituted

    # ef_codes has this shape
    # [
    # {"F1359", nil},
    # [{"F1359", ["192A, 192B", "192A", "192B"]},
    # {"F1200", nil},
    # {"F1200", ["144ZE, 144ZF", "144ZE", "144ZF"]},
    # {"F1199", ["144ZA-144ZD", "144ZA", "144ZD"]}, ...
    # ]

    # Ensure Ss is Ss.
    # 🔻F62🔻 Ss 27, 27A substituted
    binary = Regex.replace(~r/🔻[ ]Ss[ ]/, binary, "🔻 Ss. ")

    regex =
      ~s/^🔻(F\\d+)🔻(?:[ ].*?[ ]\\(ss\\.[ ].*?\\)[ ]|[ ]Ss\\.[ ].*?)(repealed|inserted|substituted|omitted)/

    QA.scan_and_print(binary, regex, "Ss. SECTIONS", true)

    ef_codes =
      Regex.scan(
        ~r/#{regex}/m,
        binary
      )
      |> Enum.reduce([], fn [line, ef_code, amd_type], acc ->
        # sometimes the en dash (codepoint 8211) \u2013 is used for ranges
        line = Regex.replace(~r/–/, line, "-")

        acc =
          case Regex.run(~r/(\d+[A-Z]*),[ ](\d+[A-Z]*)/, line) do
            nil ->
              acc

            match ->
              [{ef_code, match, amd_type} | acc]
          end

        Regex.run(~r/(\d+[A-Z]*)-(\d+[A-Z]*)/, line)
        |> (&[{ef_code, &1, amd_type} | acc]).()
      end)
      |> Enum.uniq()

    ef_tags =
      Enum.reduce(ef_codes, [], fn
        {_, nil, _}, acc ->
          acc

        {ef_code, [match, first, last], amd_type}, acc ->
          cond do
            String.contains?(match, ",") ->
              [
                {match, ef_code, last, ef_code <> last, amd_type},
                {match, ef_code, first, ef_code <> first, amd_type}
                | acc
              ]

            String.contains?(match, "-") ->
              cond do
                # RANGE with this pattern 87-87C
                Regex.match?(~r/\d+-\d+[A-Z]/, match) ->
                  # IO.puts("cond do #1 #{match}")
                  [_, a, b] = Regex.run(~r/(\d+)-\d+([A-Z])/, match)
                  acc = [{match, ef_code, a, ef_code <> a, amd_type} | acc]

                  i = Legl.Utility.alphabet_to_numeric_map()[b]

                  accum =
                    Enum.reduce(97..i, [], fn x, accum ->
                      [
                        {match, ef_code, a <> String.upcase(<<x::utf8>>),
                         ef_code <> a <> String.upcase(<<x::utf8>>), amd_type}
                        | accum
                      ]
                    end)
                    |> Enum.reverse()

                  accum ++ acc

                # RANGE with this pattern 32-35
                Regex.match?(~r/\d+-\d+/, match) ->
                  # IO.puts("cond do #2 #{match}")
                  [_, a, b] = Regex.run(~r/(\d+)-(\d+)/, match)
                  ia = String.to_integer(a)
                  ib = String.to_integer(b)

                  accum =
                    Enum.reduce(ia..ib, [], fn x, accum ->
                      [{match, ef_code, "#{x}", "#{ef_code}#{x}", amd_type} | accum]
                    end)
                    |> Enum.reverse()

                  accum ++ acc

                # RANGE with this pattern 105ZA-105ZI
                Regex.match?(~r/\d+[A-Z][A-Z]-\d+[A-Z][A-Z]/, match) ->
                  # IO.puts("cond do #3 #{match}")
                  [_, num, a, b] = Regex.run(~r/(\d+[A-Z])([A-Z])-\d+[A-Z]([A-Z])/, match)
                  ia = Legl.Utility.alphabet_to_numeric_map()[a]
                  ib = Legl.Utility.alphabet_to_numeric_map()[b]

                  accum =
                    Enum.reduce(ia..ib, [], fn x, accum ->
                      [
                        {match, ef_code, num <> String.upcase(<<x::utf8>>),
                         ef_code <> num <> String.upcase(<<x::utf8>>), amd_type}
                        | accum
                      ]
                    end)
                    |> Enum.reverse()

                  # |> IO.inspect()

                  accum ++ acc

                # RANGE with this pattern 27H-27K
                Regex.match?(~r/\d+[A-Z]-\d+[A-Z]/, match) ->
                  # IO.puts("cond do #4 #{match}")
                  [_, num, a, b] = Regex.run(~r/(\d+)([A-Z])-\d+([A-Z])/, match)
                  ia = Legl.Utility.alphabet_to_numeric_map()[a]
                  ib = Legl.Utility.alphabet_to_numeric_map()[b]

                  accum =
                    Enum.reduce(ia..ib, [], fn x, accum ->
                      [
                        {match, ef_code, num <> String.upcase(<<x::utf8>>),
                         ef_code <> num <> String.upcase(<<x::utf8>>), amd_type}
                        | accum
                      ]
                    end)
                    |> Enum.reverse()

                  # |> IO.inspect()

                  accum ++ acc

                true ->
                  acc
              end

            true ->
              [{match, nil, nil, amd_type} | acc]
          end
      end)
      |> IO.inspect(limit: :infinity)

    {acc, io} =
      Enum.reduce(ef_tags, {binary, []}, fn {_match, ef, section_number, tag, amd_type},
                                            {acc, io} ->
        regex =
          case amd_type do
            "repealed" ->
              ~s/^(\\[?)#{tag}((?:[ ]|\\.).*)(#{@geo_regex})/

            _ ->
              ~s/^(\\[?)#{tag}([^0-9].*)(#{@geo_regex})/
          end

        io =
          case Regex.run(~r/#{regex}/m, acc) do
            nil -> io
            [m, _, _, _] -> [{m, ef, section_number, amd_type} | io]
          end

        acc =
          acc
          |> (&Regex.replace(
                ~r/#{regex}/m,
                &1,
                "#{@components.section}#{section_number} \\g{1}#{ef} #{section_number} \\g{2}\\g{3}"
              )).()
          |> Legl.Utility.rm_dupe_spaces(@regex_components.section)

        {acc, io}
      end)

    QA.print_selected_sections(io)
    acc
  end

  @doc """
  #TODO
  """
  def tag_schedule_section_efs(binary) do
    # See uk_annotations.exs for examples and test
    para =
      Regex.scan(~r/^🔻(F\d+)🔻[ ]Sch\.[ ]\d+[A-Z]*[ ]para\.[ ](\d+[A-Z]*)[ ]/m, binary)
      |> Enum.reduce([], fn [match, ef_code, x], acc ->
        [{match, ef_code, x, ef_code <> x} | acc]
      end)
      |> Enum.uniq()

    paras_duo =
      Regex.scan(
        ~r/^🔻(F\d+)🔻[ ]Schs?\.[ ]\d+[A-Z]*[ ]paras\.[ ](\d+[A-Z]*),[ ](\d+[A-Z]*)[^\(]/m,
        binary
      )
      |> Enum.reduce([], fn [match, ef_code, x1, x2], acc ->
        [{match, ef_code, x2, ef_code <> x2}, {match, ef_code, x1, ef_code <> x1} | acc]
      end)
      |> Enum.uniq()

    paras_range =
      Regex.scan(
        ~r/^🔻(F\d+)🔻[ ]Sch\.[ ].*[ ]paras\.[ ](\d+[A-Z]*)-(\d+[A-Z]*)[^\(]/m,
        binary
      )
      |> Enum.reduce([], fn [match, ef_code, r1, r2], acc ->
        for n <- String.to_integer(r1)..String.to_integer(r2) do
          {match, ef_code, ~s/#{n}/, ef_code <> ~s/#{n}/}
        end
        |> (&(&1 ++ acc)).()
      end)
      |> Enum.uniq()

    # |> IO.inspect()

    ef_tags = para ++ paras_duo ++ paras_range

    Enum.reduce(ef_tags, binary, fn {_match, ef, section_number, tag}, acc ->
      acc
      # [F16068(1)A care home or independent hospital.E+W
      |> (&Regex.replace(
            ~r/^(\[?)#{tag}(\((\d+)\))/m,
            &1,
            "#{@components.section}#{section_number}-\\g{3} \\g{1}#{ef} #{section_number}\\g{2}"
          )).()
      |> (&Regex.replace(
            ~r/^(\[?)#{tag}([^0-9])/m,
            &1,
            "#{@components.section}#{section_number} \\g{1}#{ef} #{section_number} \\g{2}"
          )).()
      # F129F1303E+W+S. .
      |> (&Regex.replace(
            ~r/^(\[?F\d+)#{tag}([^0-9])/m,
            &1,
            "#{@components.section}#{section_number} \\g{1}#{ef} #{section_number} \\g{2}"
          )).()
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

  def rm_marginal_citations(binary) do
    binary
    |> (&Regex.replace(
          ~r/^Marginal[ ]Citations\n/m,
          &1,
          ""
        )).()
    |> (&Regex.replace(
          ~r/^M\d+([ ]|\.).*\n/m,
          &1,
          ""
        )).()
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
  Finds sections conforming to this pattern:
    [F43172 Indemnities in respect of fluoridation.E+W+S
    foobar
    foobar
    Textual Amendments
    🔻F43🔻Ss. 13, 23, 141(1)-(4)(7), 172 repealed
  """
  def tag_section_wash_up(binary) do
    regex = ~s/(^\\[F|^F)(\\d+)([ ]?[A-Z].*?)(#{@geo_regex})$([\\s\\S]+?^🔻F(\\d+)🔻)/

    QA.scan_and_print(binary, regex, "SECTION WASH UP", true)

    binary
    |> (&Regex.replace(
          ~r/#{regex}/m,
          &1,
          fn _, prefix, n, txt, region, amd, ef ->
            # take the F9 number from the 'from' number 914 becomes 14
            # F2 and 22 becomes 2
            n = String.replace_prefix(n, ef, "")

            case n do
              "" ->
                ~s/[::heading::]#{prefix}#{n} #{txt} [::region::]#{region}/
                |> Kernel.<>(amd)

              _ ->
                ~s/[::section::]#{n} #{prefix} #{n} #{txt} [::region::]#{region}/
                |> Kernel.<>(amd)
            end
          end
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
