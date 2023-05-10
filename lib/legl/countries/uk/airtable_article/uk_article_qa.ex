defmodule Legl.Countries.Uk.AirtableArticle.UkArticleQa do
  @moduledoc """

  """
  @components %Types.Component{}
  @regex_components Types.Component.mapped_components_for_regex()

  @doc """

  """

  def list_headings(binary, opts) do
    case opts.list_headings do
      true ->
        lines = String.split(binary, "\n")

        Enum.reduce(lines, [], fn line, acc ->
          cond do
            Regex.match?(~r/^[A-Z].*(#{UK.region()}|#{UK.country()})$/, line) -> [line | acc]
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

  @doc """
  Function to sense check the sections.  Run as default.  Use [qa_sections:
  :false] in the options to switch-off

  Function does an automatic fix for section numbers muddled with FXXX numbers
  """
  def qa_sections(binary, opts, counter \\ 0) do
    counter = counter + 1

    case opts.qa_sections do
      true ->
        lines = String.split(binary, "\n")

        {_, {status, values, records}} =
          Enum.reduce(lines, {false, {:ok, [0], []}}, fn line,
                                                         {schedule?, {status, values, records}} ->
            case Regex.match?(~r/^#{@regex_components.annex}/, line) do
              true ->
                qa_sections_schedule(line, {true, {status, values, records}})

              _ ->
                qa_sections_schedule(line, {schedule?, {status, values, records}})
            end
          end)

        case status do
          :error ->
            values
            |> Enum.reverse()
            |> Enum.join(", ")
            |> (&IO.puts("\nSequential Section Numbers:\n#{&1}")).()

            case counter do
              2 ->
                records
                |> Enum.reverse()
                |> Enum.join("\n")

              _ ->
                records
                |> Enum.reverse()
                |> Enum.join("\n")
                |> qa_sections(opts, counter)
            end

          :ok ->
            records
            |> Enum.reverse()
            |> Enum.join("\n")
        end

      _ ->
        binary
    end
  end

  def qa_sections_schedule(line, {true, {status, values, records}}) do
    {true, {status, values, [line | records]}}
  end

  def qa_sections_schedule(line, {schedule?, {status, values, records}}) do
    case Regex.run(~r/^#{@regex_components.section}(\d+)(.*?[ ])/, line) do
      [_match, num, _code] ->
        last = List.first(values)
        num = String.to_integer(num)

        cond do
          num == last ->
            {schedule?, {status, [num | values], [line | records]}}

          num == last + 1 ->
            {schedule?, {status, [num | values], [line | records]}}

          num > last + 1 ->
            IO.puts("MISSED S.? last: #{last}, this: #{num}, line: #{line}")
            {schedule?, {status, [num | values], [line | records]}}

          num < last ->
            # [::section::]0A [F501 0A Protection of wild hares etc. [::region::]S
            # [::section::]1A [F641 1A Snares: train
            # The required value has 'bled' into the F code
            line =
              Regex.replace(
                ~r/^#{@regex_components.section}(\d+)([A-Z]*)[ ]+(\[F\d+)(\d)[ ]+(.*)/,
                line,
                "#{@components.section}\\g{4}\\g{1}\\g{2} \\g{3} \\g{4}\\g{5}"
              )

            [_match, new_num, _code] =
              Regex.run(~r/^#{@regex_components.section}(\d+)(.*?[ ])/, line)

            IO.puts("last: #{last}, this: #{num}, new: #{new_num} line: #{line}")

            {schedule?, {:error, [String.to_integer(new_num) | values], [line | records]}}
        end

      nil ->
        {schedule?, {status, values, [line | records]}}
    end
  end

  @doc """
  Function to print to console the [F and F tags that have not been captured
  with an emoji
  """
  def qa_list_spare_efs(binary, opts) do
    if opts.qa_list_efs,
      do:
        Regex.scan(~r/^F\d+.*/m, binary)
        |> IO.inspect(label: "efs", limit: :infinity)

    if opts.qa_list_bracketed_efs,
      do:
        Regex.scan(~r/^\[F\d+.*/m, binary)
        |> IO.inspect(label: "bracketed efs", limit: :infinity)

    binary
  end
end
