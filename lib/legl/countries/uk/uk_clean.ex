defmodule Legl.Countries.Uk.UkClean do
  @region_regex UK.region()
  @country_regex UK.country()

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
      |> opening_quotes()
      |> closing_quotes()

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

  def opening_quotes(binary) do
    Regex.replace(~r/[ ]\"(.)/m, binary, " “\\g{1}")
  end

  def closing_quotes(binary) do
    Regex.replace(~r/(.)\"(\.| |\))/m, binary, "\\g{1}”\\g{2}")
  end

  def tag_section_efs(binary, opts) when is_map(opts) do
    efs = Legl.Countries.Uk.AirtableArticle.UkAnnotations.collect_tags("🔻F(\\d+)🔻", binary)

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
end
