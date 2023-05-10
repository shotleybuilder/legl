defmodule Legl.Countries.Uk.UkClean do
  @region_regex "U\\.K\\.|E\\+W\\+N\\.I\\.|E\\+W\\+S|E\\+W"
  @country_regex "N\\.I\\.|S|W|E"

  alias Legl.Countries.Uk.AirtableArticle.UkArticleQa, as: QA

  def clean_original("CLEANED\n" <> binary, _opts) do
    binary |> (&IO.puts("cleaned: #{String.slice(&1, 0, 100)}...")).()
    binary
  end

  def clean_original(binary, %{type: :act} = opts) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> collapse_amendment_text_between_quotes()
      |> separate_part()
      # |> separate_chapter()
      |> separate_schedule()
      |> Legl.Parser.rm_leading_tabs()
      |> join_empty_numbered()
      |> tag_txt_amend_efs()
      |> part_efs()
      |> chapter_efs()
      |> cross_heading_efs()
      |> section_efs()
      |> section_subs_efs()
      |> schedule_efs()
      |> tag_sub_efs()
      |> tag_schedule_efs()
      # ***** |> tag_efs()
      |> tag_mods_cees()
      |> tag_commencing_ies()
      |> tag_extent_ees()
      |> tag_editorial_xes()
      |> rm_marginal_citations()
      |> opening_quotes()
      |> closing_quotes()
      # |> tag_section_efs(opts)
      |> space_efs()
      |> QA.qa_list_spare_efs(opts)
      |> list_headings(opts)

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    clean_original(binary, opts)
  end

  def clean_original(binary, opts) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> collapse_amendment_text_between_quotes()
      # |> separate_part_chapter_schedule()
      |> separate_part()
      |> separate_chapter()
      |> separate_schedule()
      |> join_empty_numbered()
      # |> rm_overview()
      # |> rm_footer()
      |> Legl.Parser.rm_leading_tabs()
      |> tag_efs()
      |> tag_txt_amend_efs()
      |> tag_extent_ees()
      |> closing_quotes()

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    clean_original(binary, opts)
  end

  @spec separate_part(binary) :: binary
  def separate_part(binary),
    do:
      Regex.replace(
        ~r/^((?:PART|Part)[ ]\d+)([A-Za-z]+)/m,
        binary,
        "\\g{1} \\g{2}"
      )

  @spec separate_chapter(binary) :: binary
  def separate_chapter(binary),
    do:
      Regex.replace(
        ~r/^((?:CHAPTER|Chapter)[ ]?\d*[A-Z]?)([A-Z].*)/m,
        binary,
        "\\g{1} \\g{2}"
      )
      |> (&Regex.replace(
            ~r/^\[(F\d+)((?:CHAPTER|Chapter)[ ]?\d*[A-Z]?)([A-Z].*)/m,
            &1,
            "[🔺\\g{1}🔺 \\g{2} \\g{3}"
          )).()

  @spec separate_schedule(binary) :: binary
  def separate_schedule(binary),
    do:
      Regex.replace(
        ~r/^((?:SCHEDULES?|Schedules?)[ ]?\d*[A-Z])([A-Z].*)/m,
        binary,
        "\\g{1} \\g{2}"
      )

  @spec separate_part_chapter_schedule(binary) :: binary
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
            ~r/^(SCHEDULE)(S?)([A-Z a-z]*)/m,
            &1,
            "\\g{1}\\g{2}\\g{3}"
          )).()
      |> (&Regex.replace(
            ~r/^(SCHEDULE[ ]\d+)([A-Z a-z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()

  @spec collapse_amendment_text_between_quotes(binary) :: binary
  def collapse_amendment_text_between_quotes(binary) do
    Regex.replace(
      ~r/(?:inserte?d?—|substituted?—|adde?d?—|inserted the following Schedule—)(?:\r\n|\n)^[“][\s\S]*?(?:\.”\.|\.”|”\.|”;)/m,
      binary,
      fn x -> "#{join(x)}" end
    )

    # |> (&Regex.replace(
    #  ~r/(?:inserte?d?—|substituted?—|adde?d?—|inserted the following Schedule—)📌[“][\s\S]*?(?:\.”\.)/m,
    #  &1,
    #  fn x -> "#{join(x)}" end
    # )).()
  end

  def join(binary) do
    Regex.replace(
      ~r/(\r\n|\n)/m,
      binary,
      "#{Legl.pushpin_emoji()}"
    )
  end

  def join_empty_numbered(binary),
    do:
      Regex.replace(
        ~r/^(\(([a-z]+|[ivmcldx]+)\)|\d+\.?)(?:\r\n|\n)/m,
        binary,
        "\\g{1} "
      )

  @doc """
  A function to process tag_efs in 'original.txt' outside of running the parse process.
  Result is saved to 'a_original.txt'.

  iex> Legl.Countries.Uk.UkClean.tag_efs()
  """
  def tag_efs() do
    txt =
      Legl.txt("original")
      |> Path.absname()
      |> File.read!()
      |> tag_efs()
      |> tag_txt_amend_efs()

    Legl.txt("a_original")
    |> Path.absname()
    |> File.write!(txt)
  end

  def tag_efs(binary) when is_binary(binary) do
    lines = String.split(binary, "\n")

    {_, acc} =
      Enum.reduce(lines, {"F1", []}, fn x, {ef, acc} ->
        case Regex.run(~r/#{ef}/, x) do
          nil ->
            "F" <> index = ef
            next_ef = ~s/F#{String.to_integer(index) + 1}/
            {ef, binary} = tag_efs({ef, next_ef, x})
            {ef, [binary | acc]}

          _ ->
            {ef, binary} = tag_efs({nil, ef, x})
            {ef, [binary | acc]}
        end
      end)

    Enum.reverse(acc)
    |> Enum.join("\n")
  end

  def tag_efs({last_ef, ef, binary}) do
    binary = tag_previous_encountered_efs(binary, ef)

    case Regex.run(~r/#{ef}/, binary) do
      nil ->
        {last_ef, binary}

      _ ->
        binary =
          Regex.replace(~r/#{ef}/m, binary, "🔺\\g{0}🔺")
          |> (&Regex.replace(~r/🔺🔺/, &1, "🔺")).()

        "F" <> index = ef
        next_ef = ~s/F#{String.to_integer(index) + 1}/
        tag_efs({ef, next_ef, binary})
    end
  end

  @doc """
  Tag previously encountered efs that appear at the start of a line
  """
  def tag_previous_encountered_efs(line, "F" <> index = _ef) do
    efs = Enum.map(String.to_integer(index)..1, fn x -> ~s/F#{x}/ end)

    Enum.reduce(efs, line, fn x, acc ->
      Regex.replace(~r/^#{x}/, acc, "🔺\\g{0}🔺")
      |> (&Regex.replace(~r/^\[(#{x})/, &1, "[🔺\\g{1}🔺")).()
    end)
  end

  @doc """
  🔻 is used to tag Textual Amendments separately to other amendment tags
  """
  def tag_txt_amend_efs(binary) do
    binary
    # F578 By S. I.
    |> (&Regex.replace(
          ~r/S\.[ ]I\./,
          &1,
          "S.I."
        )).()
    # F438Definition substituted by Agriculture Act 1986
    # F535 Sch. ZA1 inserted
    # F537Entry in Sch
    # F903Para reference (a)
    # F54In s. 1(7) the definition of "local authority"
    |> (&Regex.replace(
          ~r/^(F\d+)[ ]?(Ss?c?h?\.[ ]|s[ ]?\.|W[O|o]rds?|In[ ]s.[ ]|The[ ]words[ ]repealed|Definition[ ]|Entry?i?e?s?|By.*?S\.I\.|Para\.?[ ]|Pt.[ ]|Part[ ]|Cross[ ]heading)/m,
          &1,
          "🔻\\g{1}🔻 \\g{2}"
        )).()
    # F121964 c. 29.
    |> (&Regex.replace(
          ~r/^(F\d+?)(\d{4} c\. \d+)/m,
          &1,
          "🔻\\g{1}🔻 \\g{2}"
        )).()
  end

  def part_efs(binary) do
    binary
    # F902[PART IIIAE+W Promotion of the Efficient Use of Water
    |> (&Regex.replace(
          ~r/^(\[?)(F\d+)(\[(?:PART|Part))/m,
          &1,
          "\\g{1}🔺\\g{2}🔺 \\g{3}"
        )).()
  end

  def chapter_efs(binary) do
    binary
    |> (&Regex.replace(
          ~r/^\[(F\d+)((?:CHAPTER|Chapter)[ ]?\d*[A-Z]?)([A-Z].*)/m,
          &1,
          "[🔺\\g{1}🔺 \\g{2} \\g{3}"
        )).()
  end

  @doc """
  Function reads amendment clauses looking for "cross-heading inserted"
  When found the associated Fxxx code is read and stored in a list
  These Fxxx codes are then searched for and marked up as headings
  """
  def cross_heading_efs(binary) do
    Regex.scan(~r/^🔻(F\d+)🔻.*?C?c?ross-?[ ]?heading.*(?:inserted|substituted)/m, binary)
    |> Enum.map(fn [_, ef_code] -> ef_code end)
    |> Enum.reduce(binary, fn ef, acc ->
      acc
      |> (&Regex.replace(
            ~r/^(\[?)#{ef}([^0-9])/m,
            &1,
            "\\g{1}❌#{ef}❌ \\g{2}"
          )).()
    end)
  end

  @doc """
  Function reads amendment clauses looking for S. insertions and substitutions
  When matched the assoociated Fxxx code is read and stored in a list
  concatenated with Ss. number
  These Fxxx codes are then searched ofr and marked up as sections
  """
  def section_efs(binary) do
    # 🔻F2🔻 S. 1A inserted -> [F21AWater Services
    # 🔻F144🔻 S. 17B title substituted -> 17B[F144Meaning of supply
    # 🔻F169🔻 S. 17DA inserted -> [F16917DAGuidance
    # 🔻F685🔻 S. 63A inserted

    # Pattern: [[line, ef, section_number], [line, ef, section_number] ...]
    binary =
      Regex.scan(~r/^🔻(F\d+)🔻[ ]S\.[ ](\d+[A-Z]+)[^\()].*/m, binary)
      |> Enum.reduce(binary, fn [_line, ef, x], acc ->
        acc
        |> (&Regex.replace(
              ~r/^(\[?)#{ef}#{x}/m,
              &1,
              "\\g{1}🔺#{ef}🔺 #{x} "
            )).()
        |> (&Regex.replace(
              ~r/^#{x}#{ef}/m,
              &1,
              "#{x} 🔺#{ef}🔺 "
            )).()
      end)

    # 🔻F886🔻 S. 91 substituted -> [F88691 [F887 Old Welsh
    # 🔻F1205🔻 S. 145 and ... repealed -> F1205145. . . . . .
    #

    # Pattern: [[line, ef, section_number], [line, ef, section_number] ...]
    Regex.scan(~r/^🔻(F\d+)🔻[ ]S\.[ ](\d+)[ ](?:.*?repealed|substituted).*/m, binary)
    # |> IO.inspect(label: "section_efs/1")
    |> Enum.reverse()
    |> Enum.reduce(binary, fn [_line, ef, x], acc ->
      acc
      |> (&Regex.replace(
            ~r/^(\[?)#{ef}#{x}([^0-9])/m,
            &1,
            "\\g{1}🔺#{ef}🔺 #{x} \\g{2}"
          )).()
      # 🔻F1542🔻 S. 221 substituted -> [221F1542Crown application.E+W
      |> (&Regex.replace(
            ~r/^(\[?)#{x}#{ef}/m,
            &1,
            "\\g{1}🔺#{ef}🔺 #{x}  "
          )).()
      |> (&Regex.replace(
            ~r/^(X\d+)\[#{ef}#{x}/m,
            &1,
            "\\g{1} [🔺#{ef}🔺 #{x} "
          )).()
    end)
  end

  @doc """
  Function reads amendment clauses looking for Ss. insertions and substitutions
  When matched the assoociated Fxxx code is read and stored in a list
  concatenated with Ss. number
  These Fxxx codes are then searched ofr and marked up as sections
  """
  def section_subs_efs(binary) do
    # CSV when there are 2x insertions / substitutions
    # 🔻F124🔻 Ss. 16A, 16B inserted
    # 🔻F188🔻 Ss. 17FA, 17FB inserted
    # RANGE when there are >2x insertions / substitutions
    # 🔻F494🔻 Ss. 33A-33C inserted
    # 🔻F426🔻 Ss. 27H-27K inserted
    # 🔻F143🔻 Ss. 17A, 17AA substituted
    # 🔻F490🔻 Ss. 32-35 substituted

    # ef_codes has this shape
    # [
    # {"F1359", nil},
    # [{"F1359", ["192A, 192B", "192A", "192B"]},
    # {"F1200", nil},
    # {"F1200", ["144ZE, 144ZF", "144ZE", "144ZF"]},
    # {"F1199", ["144ZA-144ZD", "144ZA", "144ZD"]}, ...
    # ]
    ef_codes =
      Regex.scan(~r/^🔻(F\d+)🔻[ ]Ss\.[ ].*/m, binary)
      |> Enum.reduce([], fn [line, ef_code], acc ->
        acc =
          case Regex.run(~r/Ss\.[ ](\d+[A-Z]*),[ ](\d+[A-Z]*)/m, line) do
            nil ->
              acc

            match ->
              [{ef_code, match} | acc]
          end

        Regex.run(~r/(\d+[A-Z]*)-(\d+[A-Z]*)/, line)
        |> (&[{ef_code, &1} | acc]).()
      end)
      |> Enum.uniq()

    # |> IO.inspect(limit: :infinity)

    ef_tags =
      Enum.reduce(ef_codes, [], fn
        {_, nil}, acc ->
          acc

        {ef_code, [match, first, last]}, acc ->
          cond do
            String.contains?(match, ",") ->
              [
                {match, ef_code, last, ef_code <> last},
                {match, ef_code, first, ef_code <> first}
                | acc
              ]

            String.contains?(match, "-") ->
              cond do
                # RANGE with this pattern 87-87C
                Regex.match?(~r/\d+-\d+[A-Z]/, match) ->
                  # IO.puts("cond do #1 #{match}")
                  [_, a, b] = Regex.run(~r/(\d+)-\d+([A-Z])/, match)
                  acc = [{match, ef_code, a, ef_code <> a} | acc]

                  i = Legl.Utility.alphabet_to_numeric_map()[b]

                  accum =
                    Enum.reduce(97..i, [], fn x, accum ->
                      [
                        {match, ef_code, a <> String.upcase(<<x::utf8>>),
                         ef_code <> a <> String.upcase(<<x::utf8>>)}
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
                      [{match, ef_code, "#{x}", "#{ef_code}#{x}"} | accum]
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
                         ef_code <> num <> String.upcase(<<x::utf8>>)}
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
                        {match, ef_code, String.upcase(<<x::utf8>>),
                         ef_code <> num <> String.upcase(<<x::utf8>>)}
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
              [{match, nil, nil} | acc]
          end
      end)

    # |> IO.inspect(limit: :infinity)

    Enum.reduce(ef_tags, binary, fn {_match, ef, section_number, tag}, acc ->
      acc
      |> (&Regex.replace(
            ~r/^(\[?)#{tag}([^0-9])/m,
            &1,
            "\\g{1}🔺#{ef}🔺 #{section_number} \\g{2}"
          )).()
    end)
  end

  @doc """
  #TODO
  """
  def schedule_efs(binary) do
    Regex.scan(~r/^🔻(F\d+)🔻[ ]Sch\.[ ]\d+[A-Z]*[ ]para\.[ ]\d+[A-Z]*[^\(]/m, binary)
    |> IO.inspect()

    Regex.scan(~r/^🔻(F\d+)🔻[ ]Sch\.[ ]\d+[A-Z]*[ ]paras\.[ ]\d+[A-Z]*,[ ]\d+[A-Z]*[^\(]/m, binary)
    |> IO.inspect()

    binary
  end

  def tag_mods_cees(binary) do
    Regex.replace(
      ~r/^(C\d+)(.*)/m,
      binary,
      "🇲\\g{1}🇲\\g{2}"
    )
  end

  def tag_commencing_ies(binary) do
    Regex.replace(
      ~r/^(Commencement Information)\n(I\d+)(.*)/m,
      binary,
      "\\g{1}\n🇨\\g{2}🇨 \\g{3}"
    )
  end

  def tag_extent_ees(binary) do
    Regex.replace(
      ~r/^(Extent Information)\n^(E\d+)(.*)/m,
      binary,
      "\\g{1}\n🇪\\g{2}🇪 \\g{3}"
    )
  end

  def tag_editorial_xes(binary) do
    binary =
      Regex.replace(
        ~r/^(Editorial[ ]Information)\n^(X\d+)(.*)/m,
        binary,
        "\\g{1}\n🇽\\g{2}🇽 \\g{3}"
      )

    xes = collect_tags("🇽X(\\d+)🇽", binary)

    IO.puts("xes: #{List.first(xes)}")

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

  def opening_quotes(binary) do
    Regex.replace(~r/[ ]\"(.)/m, binary, " “\\g{1}")
  end

  def closing_quotes(binary) do
    Regex.replace(~r/(.)\"(\.| |\))/m, binary, "\\g{1}”\\g{2}")
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

  def tag_section_efs(binary, opts) when is_map(opts) do
    efs = collect_tags("🔻F(\\d+)🔻", binary)

    case opts.list_section_efs do
      true ->
        IO.write("Efs: ")
        Enum.reverse(efs) |> Enum.each(&IO.write("#{&1}, "))
        IO.puts("\nEfs_count: #{List.first(efs)}")

      false ->
        nil
    end

    lines = String.split(binary, "\n")

    Enum.reduce(lines, [], fn line, acc -> [tag_section_efs(line, efs) | acc] end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def tag_section_efs("[F" <> line, efs) when is_binary(line) do
    line = ~s/[F#{line}/

    # sections carry a region tag at the end, so we use this to reduce the number of lines processed
    case Regex.match?(~r/(#{@region_regex}|#{@country_regex})$/, line) do
      true ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          # [F505X561 Ploughing.E+W
          # [F51166BApplication
          # [F51970A Service
          # [F52470BEffect
          # [F165 19ZC Wildlife inspectors: ScotlandS
          case Regex.run(~r/^\[F#{ef}[ ]?(\d+[A-Z]*)[ ]?([A-Z].*)/, line) do
            nil -> {:cont, acc}
            [_, id, text] -> {:halt, ~s/[🔺F#{ef}🔺 #{id} #{text}/}
          end
        end)

      _ ->
        case Regex.match?(~r/^[F\d+[A-Z]*\.?(#{@region_regex}|#{@country_regex})/, line) do
          true ->
            Enum.reduce_while(efs, line, fn ef, acc ->
              # [F9514AB.SContravention of emergency measures
              # [F2983AE+WAn order of the confirmation of that order.]
              case Regex.run(
                     ~r/^\[F#{ef}[ ]?(\d+[A-Z]*)\.?(#{@region_regex}|#{@country_regex})([A-Z].*)/,
                     line
                   ) do
                nil -> {:cont, acc}
                [_, id, region, text] -> {:halt, ~s/[🔺F#{ef}🔺 #{id} #{text} #{region}/}
              end
            end)

          _ ->
            line
        end
    end
  end

  def tag_section_efs("F" <> line, efs) when is_binary(line) do
    line = ~s/F#{line}/

    cond do
      # sections carry a region tag at the end, so we use this to reduce the
      # number of lines processed
      Regex.match?(~r/(#{@region_regex}|#{@country_regex})$/, line) ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          # F246[F245 27ZAApplication of Part 1 to England and WalesE+W
          # F42847[F427Grants to the Countryside Council for Wales]E+W
          # F786[F787(3). . . . . . . (SUB-SECTION)
          case Regex.run(~r/^F#{ef}(\[F\d*)[ ](\d+[A-Z]?[A-Z]?)[ ]?([A-Z].*)/, line) do
            [_, ef2, id, text] ->
              {:halt, ~s/🔺F#{ef}🔺 #{ef2} #{id} #{text}/}

            nil ->
              # F11F1 The Countryside Council for Wales.E+W
              # F12F1. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . E+W
              case Regex.run(~r/^F#{ef}[ ]?(\d+[A-Z]?[A-Z]?)(F\d+)[ ]?(.*)/, line) do
                [_, id, ef2, text] ->
                  {:halt, ~s/🔺F#{ef}🔺 #{ef2} #{id} #{text}/}

                nil ->
                  # F356[F357Nature reserves, ... and Ramsar sitesE+W+S (A HEADING!)
                  # F34633 Ministerial guidance as respects.E+W+S
                  # F11 Provision by local authorities for disposal of refuse.E+W
                  # F37438. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .E+W+S
                  case Regex.run(~r/^F#{ef}[ ]?(\d+[A-Z]?[A-Z]?)[ ]?([^\[].*)/, line) do
                    [_, id, text] -> {:halt, ~s/🔺F#{ef}🔺 #{id} #{text}/}
                    nil -> {:cont, acc}
                  end
              end
          end
        end)

      Regex.match?(~r/F\d+[ ]?F?\d+[ ].*?(#{@region_regex}|#{@country_regex})/, line) ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          # F674 1 E+W+S. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
          # F705 1 —4.E+W+S. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
          case Regex.run(~r/^F#{ef}[ ]?(\[?F?\d*)[ ](\d+[A-Z]?[A-Z]?)[ ]?(.*)/, line) do
            [_, ef2, id, text] ->
              {:halt, ~s/🔺F#{ef}🔺 #{ef2} #{id} #{text}/}

            nil ->
              {:cont, acc}
          end
        end)

      # F3611
      # But NOT to capture F269...
      Regex.match?(~r/F\d+.*/, line) ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          case Regex.run(~r/^F#{ef}(\d+[A-Z]?[A-Z]?)(?:[^\.0-9])(.*)/, line) do
            [_, id, text] ->
              {:halt, ~s/🔺F#{ef}🔺 #{id} #{text}/}

            nil ->
              {:cont, acc}
          end
        end)

      true ->
        line
    end
  end

  def tag_section_efs("🔺X" <> line, efs) when is_binary(line) do
    line = ~s/🔺X#{line}/

    # sections carry a region tag at the end, so we use this to reduce the number of lines processed
    case Regex.match?(~r/(#{@region_regex}|#{@country_regex})$/, line) do
      true ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          # 🔺X2🔺 [F247 Sites of special scientific interest and limestone pavements ] E+W+S (A HEADING!)
          # Presume any section with an [F carries an post alphabetic code
          # 🔺X4🔺 [F36437A Ramsar sites.E+W
          case Regex.run(~r/^(🔺X\d+🔺)[ ]\[F#{ef}[ ]?(\d+[A-Z]+)[ ]?([A-Z].*)/, line) do
            nil -> {:cont, acc}
            [_, x_tag, id, text] -> {:halt, ~s/#{x_tag} [🔺F#{ef}🔺 #{id} #{text}/}
          end
        end)

      _ ->
        line
    end
  end

  def tag_section_efs(line, _), do: line

  def tag_sub_efs(binary) do
    binary
    # [F18(6)For
    # [F9(3A) In
    # [F8(3ZA)A
    # [F2(aa)takes
    # F416(1). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
    # F34( 2 ). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
    |> (&Regex.replace(
          ~r/^\[?(F\d+)(\([ ]?\d+[A-Z]*[ ]?\)|\([a-z]+\))[ ]?(.*)/m,
          &1,
          "\[🔺\\g{1}🔺 \\g{2} \\g{3}"
        )).()
    # F28 [(4A)In any proceedings under subsection
    # F60[(7)In any proceedings
    |> (&Regex.replace(
          ~r/^(F\d+)[ ]?\[(\(\d+[A-Z]*\)|\([a-z]+\))[ ]?(.*)/m,
          &1,
          "🔺\\g{1}🔺 \[ \\g{2} \\g{3}"
        )).()
    # F383[F384(1). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
    # [F659[F660(6)The “list of species of special concern” means
    |> (&Regex.replace(
          ~r/^(\[?)(F\d+)\[(F\d+)(\(\d+[A-Z]*\)|\([a-z]+\))[ ]?(.*)/m,
          &1,
          "\\g{1}🔺\\g{2}🔺 \[🔺\\g{3}🔺 \\g{4} \\g{5}"
        )).()
  end

  def tag_schedule_efs(binary) do
    binary
    # F560SCHEDULE 5E+W Animals which are Protected
    # F682 SCHEDULE 12E+W+S Procedure in Connection With Orders Under Section 36
    # [F535SCHEDULE ZA1E+WBirds which re-use their nests
    # [F656SCHEDULE 9AE+WSpecies control agreements
    # F683 SCHEDULE 13 E+W
    |> (&Regex.replace(
          ~r/^(\[?)(F\d+)[ ]?(SCHEDULE)[ ]([A-Z]*\d+[A-Z]?)[ ]?([A-Z].*)/m,
          &1,
          "\\g{1}🔺\\g{2}🔺 \\g{3} \\g{4} \\g{5}"
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

  def space_efs(binary) do
    Regex.replace(
      ~r/(\[?F\d{1,3})([A-Za-z])/m,
      binary,
      "\\g{1} \\g{2}"
    )
  end

  def list_headings(binary, opts) do
    case opts.list_headings do
      true ->
        lines = String.split(binary, "\n")

        Enum.reduce(lines, [], fn line, acc ->
          cond do
            Regex.match?(~r/^[A-Z].*(#{@region_regex}|#{@country_regex})$/, line) -> [line | acc]
            true -> acc
          end
        end)
        |> Enum.reverse()
        |> Enum.join("\n")
        |> IO.puts()

        binary

      _ ->
        binary
    end
  end
end
