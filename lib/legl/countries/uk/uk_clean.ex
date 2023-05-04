defmodule Legl.Countries.Uk.UkClean do

  @region_regex "U\\.K\\.|E\\+W\\+N\\.I\\.|E\\+W\\+S|E\\+W"
  @country_regex "N\\.I\\.|S|W|E"

  def clean_original("CLEANED\n" <> binary, _type) do
    binary |> (&IO.puts("cleaned: #{String.slice(&1, 0, 100)}...")).()
    binary
  end

  def clean_original(binary, :act) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> collapse_amendment_text_between_quotes()
      |> separate_part()
      |> separate_chapter()
      |> separate_schedule()
      |> Legl.Parser.rm_leading_tabs()
      |> join_empty_numbered()
      |> tag_txt_amend_efs()
      |> tag_sub_efs
      |> tag_schedule_efs()
      #|> tag_efs()
      |> tag_mods_cees()
      |> tag_commencing_ies()
      |> tag_extent_ees()
      |> tag_editorial_xes()
      |> rm_marginal_citations()
      |> opening_quotes()
      |> closing_quotes()
      |> tag_section_efs()
      |> space_efs()
      |> list_spare_efs()

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    clean_original(binary, :act)
  end

  def clean_original(binary, type) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> collapse_amendment_text_between_quotes()
      #|> separate_part_chapter_schedule()
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

    clean_original(binary, type)
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
      ~r/^((?:CHAPTER|Chapter)[ ]\d+)([A-Z a-z]+)/m,
      binary,
      "\\g{1} \\g{2}"
    )

  @spec separate_schedule(binary) :: binary
  def separate_schedule(binary),
    do:
      Regex.replace(
        ~r/^((?:SCHEDULES?|Schedules?)[ ]?\d*)([A-Z a-z]*)/m,
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
    #|> (&Regex.replace(
    #  ~r/(?:inserte?d?—|substituted?—|adde?d?—|inserted the following Schedule—)📌[“][\s\S]*?(?:\.”\.)/m,
    #  &1,
    #  fn x -> "#{join(x)}" end
    #)).()
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
      |> (&Regex.replace(~r/^\[(#{x})/,&1,"[🔺\\g{1}🔺")).()
    end)
  end
  @doc """
  🔻 is used to tag Textual Amendments separately to other amendment tags
  """
  def tag_txt_amend_efs(binary) do
    binary
    #F578 By S. I.
    |> (&Regex.replace(
      ~r/S\.[ ]I\./,
      &1,
      "S.I."
    )).()
    #F438Definition substituted by Agriculture Act 1986
    #F535 Sch. ZA1 inserted
    #F537Entry in Sch
    #F903Para reference (a)
    |> (&Regex.replace(
      ~r/^(F\d+)[ ]?(Ss?c?h?\.[ ]|Words?|Definition[ ]|Entry?i?e?s?|By.*?S\.I\.|Para\.?[ ])/m,
      &1,
      "🔻\\g{1}🔻 \\g{2}"
    )).()
    #F121964 c. 29.
    |> (&Regex.replace(
      ~r/^(F\d+?)(\d{4} c\. \d+)/m,
      &1,
      "🔻\\g{1}🔻 \\g{2}"
    )).()
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
      "\\g{1}\n🇨\\g{2}🇨 \\g{3}")
  end

  def tag_extent_ees(binary) do
    Regex.replace(~r/^(Extent Information)\n^(E\d+)(.*)/m,
    binary,
    "\\g{1}\n🇪\\g{2}🇪 \\g{3}")
  end

  def tag_editorial_xes(binary) do

    binary =
      Regex.replace(~r/^(Editorial[ ]Information)\n^(X\d+)(.*)/m,
      binary,
      "\\g{1}\n🇽\\g{2}🇽 \\g{3}")

    xes =
      collect_tags("🇽X(\\d+)🇽", binary)

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
      #[F505X561 Ploughing of public rights of way.E+W
      |> (&Regex.replace(
        ~r/^\[(F\d+)(X#{x})([^ ])/m,
        &1,
        "\[🔺\\g{1}🔺 🔺\\g{2}🔺 \\g{3}"
      )).()
    end)
    #|> IO.inspect(limit: :infinity)
  end

  def opening_quotes(binary) do
    Regex.replace(~r/[ ]\"(.)/m, binary, " “\\g{1}")
  end

  def closing_quotes(binary) do
    Regex.replace(~r/(.)\"(\.| )/m, binary, "\\g{1}”\\g{2}")
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

  def tag_section_efs(binary) do
    efs = collect_tags("🔻F(\\d+)🔻", binary)
    IO.puts("efs: #{List.first(efs)}")
    lines = String.split(binary, "\n")
    Enum.reduce(lines, [], fn line, acc -> [tag_section_efs(line, efs) | acc] end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def tag_section_efs("[F" <> line, efs) when is_binary(line) do
    line = ~s/[F#{line}/
    # sections carry a region tag at the end, so we use this to reduce the number of lines processed
    case Regex.match?(~r/(#{@region_regex}|#{@country_regex})$/, line) do
      :true ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          #[F505X561 Ploughing.E+W
          #[F51166BApplication
          #[F51970A Service
          #[F52470BEffect
          #[F165 19ZC Wildlife inspectors: ScotlandS
          case Regex.run(~r/^\[F#{ef}[ ]?(\d+[A-Z]*)[ ]?([A-Z].*)/, line) do
            nil -> {:cont, acc}
            [_, id, text] -> {:halt, ~s/[🔺F#{ef}🔺 #{id} #{text}/}
          end
        end)
      _ ->
        case Regex.match?(~r/^[F\d+[A-Z]*\.(#{@region_regex}|#{@country_regex})/, line) do
          :true ->
            Enum.reduce_while(efs, line, fn ef, acc ->
              #[F9514AB.SContravention of emergency measures
              case Regex.run(~r/^\[F#{ef}[ ]?(\d+[A-Z]*)\.([A-Z].*)/, line) do
                nil -> {:cont, acc}
                [_, id, text] -> {:halt, ~s/[🔺F#{ef}🔺 #{id} #{text}/}
              end
            end)
          _ ->
            line
        end
    end
  end

  def tag_section_efs("F" <> line, efs) when is_binary(line) do
    line = ~s/F#{line}/
    # sections carry a region tag at the end, so we use this to reduce the number of lines processed
    case Regex.match?(~r/(#{@region_regex}|#{@country_regex})$/, line) do
      :true ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          #F246[F245 27ZAApplication of Part 1 to England and WalesE+W
          case Regex.run(~r/^F#{ef}[ ]?(\[?F\d*)[ ](\d+[A-Z]?[A-Z]?)[ ]?([A-Z].*)/, line) do
            [_, ef2, id, text] ->
              {:halt, ~s/🔺F#{ef}🔺 #{ef2} #{id} #{text}/}
            nil ->
              #F34633 Ministerial guidance as respects.E+W+S
              #F37438. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .E+W+S
              case Regex.run(~r/^F#{ef}[ ]?(\d+[A-Z]?[A-Z]?)[ ]?(.*)/, line) do
                nil -> {:cont, acc}
                [_, id, text] -> {:halt, ~s/🔺F#{ef}🔺 #{id} #{text}/}
              end
          end
        end)
      _ ->
        #F674 1 E+W+S. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
        #F705 1 —4.E+W+S. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
        case Regex.match?(~r/F\d+[ ]?\d+[ ].*?(#{@region_regex}|#{@country_regex})/, line) do
          :true ->
            Enum.reduce_while(efs, line, fn ef, acc ->
              #F674 1 E+W+S. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
              #F705 1 —4.E+W+S. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
              case Regex.run(~r/^F#{ef}[ ]?(\[?F?\d*)[ ](\d+[A-Z]?[A-Z]?)[ ]?(.*)/, line) do
                [_, ef2, id, text] ->
                  {:halt, ~s/🔺F#{ef}🔺 #{ef2} #{id} #{text}/}
                nil ->
                  {:cont, acc}
              end
            end)
          _ ->
            line
        end
    end
  end

  def tag_section_efs("🔺X" <> line, efs) when is_binary(line) do
    line = ~s/🔺X#{line}/
    # sections carry a region tag at the end, so we use this to reduce the number of lines processed
    case Regex.match?(~r/(#{@region_regex}|#{@country_regex})$/, line) do
      :true ->
        Enum.reduce_while(efs, line, fn ef, acc ->
          #🔺X4🔺 [F36437A Ramsar sites.E+W
          case Regex.run(~r/^(🔺X\d+🔺)[ ]\[F#{ef}[ ]?(\d+[A-Z]*)[ ]?([A-Z].*)/, line) do
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
    #[F18(6)For
    #[F9(3A) In
    #[F8(3ZA)A
    #[F2(aa)takes
    #F416(1). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
    |> (&Regex.replace(
      ~r/^\[?(F\d+)(\(\d+[A-Z]*\)|\([a-z]+\))[ ]?(.*)/m,
      &1,
      "\[🔺\\g{1}🔺 \\g{2} \\g{3}"
    )).()
    #F28 [(4A)In any proceedings under subsection
    #F60[(7)In any proceedings
    |> (&Regex.replace(
      ~r/^(F\d+)[ ]?\[(\(\d+[A-Z]*\)|\([a-z]+\))[ ]?(.*)/m,
      &1,
      "🔺\\g{1}🔺 \[ \\g{2} \\g{3}"
    )).()
    #F383[F384(1). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
    #[F659[F660(6)The “list of species of special concern” means
    |> (&Regex.replace(
      ~r/^(\[?)(F\d+)\[(F\d+)(\(\d+[A-Z]*\)|\([a-z]+\))[ ]?(.*)/m,
      &1,
      "\\g{1}🔺\\g{2}🔺 \[🔺\\g{3}🔺 \\g{4} \\g{5}"
    )).()
  end

  def tag_schedule_efs(binary) do
    binary
    #F560SCHEDULE 5E+W Animals which are Protected
    #F682 SCHEDULE 12E+W+S Procedure in Connection With Orders Under Section 36
    #[F535SCHEDULE ZA1E+WBirds which re-use their nests
    |> (&Regex.replace(
      ~r/^(\[?)(F\d+)[ ]?(SCHEDULE)[ ]([A-Z]*\d+)(.*)/m,
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
    #|> IO.inspect(label: "collect_tags")
  end

  def space_efs(binary) do
    Regex.replace(
      ~r/(\[?F\d{1,3})([A-Z])/m,
      binary,
      "\\g{1} \\g{2}"
    )
  end

  def list_spare_efs(binary) do
    Regex.scan(~r/^F\d+.*/m, binary)
    |> IO.inspect(label: "efs", limit: :infinity)
    Regex.scan(~r/^\[F\d+.*/m, binary)
    |> IO.inspect(label: "bracketed efs", limit: :infinity)
    binary
  end

end
