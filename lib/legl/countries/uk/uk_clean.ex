defmodule Legl.Countries.Uk.UkClean do

  def clean_original("CLEANED\n" <> binary, _type) do
    binary
    |> (&IO.puts("cleaned: #{String.slice(&1, 0, 100)}...")).()

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
      |> tag_efs()
      |> tag_txt_amend_efs()

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
        ~r/^((?:SCHEDULE|Schedule)[ ]?\d*)([A-Z a-z]+)/m,
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
            ~r/^(SCHEDULES?)([A-Z a-z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()
      |> (&Regex.replace(
            ~r/^(SCHEDULE[ ]\d+)([A-Z a-z]+)/m,
            &1,
            "\\g{1} \\g{2}"
          )).()

  @spec collapse_amendment_text_between_quotes(binary) :: binary
  def collapse_amendment_text_between_quotes(binary) do
    Regex.replace(
      ~r/(?:inserte?d?—|substituted?—|adde?d?—|inserted the following Schedule—)(?:\r\n|\n)^[“][\s\S]*?(?:\.”\.|\.”|”\.)/m,
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
    case Regex.run(~r/#{ef}/, binary) do
      nil ->
        {last_ef, binary}
      _ ->
        binary = Regex.replace(~r/#{ef}/m, binary, "🔺\\g{0}🔺")
        "F" <> index = ef
        next_ef = ~s/F#{String.to_integer(index) + 1}/
        tag_efs({ef, next_ef, binary})
    end
  end

  def tag_txt_amend_efs(binary) do
    Regex.replace(
      ~r/^(F\d+)(S\.[ ]|Words)/m,
      binary,
      "🔺\\g{1}🔺\\g{2}"
    )
  end
end
