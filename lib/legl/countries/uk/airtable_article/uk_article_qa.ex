defmodule Legl.Countries.Uk.AirtableArticle.UkArticleQa do
  @moduledoc """

  """
  @components %Types.Component{}
  @regex_components Types.Component.mapped_components_for_regex()

  def scan_and_print(binary, regex, name, all? \\ false) do
    IO.puts("tag_#{name}_efs/1\n#{String.upcase(name)}s")

    results =
      binary
      |> (&Regex.scan(
            ~r/#{regex}/m,
            &1
          )).()

    count = Enum.count(results)
    {_, cols} = :io.columns()

    cond do
      all? -> Enum.each(results, &IO.inspect(&1, width: cols))
      count < 20 -> Enum.each(results, &IO.inspect(&1, width: cols))
      true -> nil
    end

    IO.puts("Count of processed #{String.upcase(name)}s: #{count}\n\n")
    count
  end

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

  def qa(binary, %{qa: false} = _opts), do: binary

  def qa(binary, opts) do
    if opts.qa_sections do
      qa_sections(binary)
    end

    if opts.qa_lcn_part do
      qa_list_clause_numbers(binary, @regex_components.part)
    end

    if opts.qa_lcn_chapter do
      qa_list_clause_numbers(binary, @regex_components.chapter)
    end

    if opts.qa_lcn_annex do
      qa_list_clause_numbers(binary, @regex_components.annex)
    end

    if opts.qa_lcn_section do
      qa_list_clause_numbers(binary, @regex_components.section)
    end

    if opts.qa_lcn_sub_section do
      qa_list_clause_numbers(binary, @regex_components.sub_section)
    end

    binary
  end

  @doc """
  Function to sense check the sections.  Run as default.  Use [qa_sections:
  :false] in the options to switch-off

  """
  def qa_sections(binary) do
    lines = String.split(binary, "\n")

    {_, {_, records}} =
      Enum.reduce(lines, {false, {[0], []}}, fn line, {schedule?, {values, records}} ->
        case Regex.match?(~r/^#{@regex_components.annex}/, line) do
          true ->
            qa_sections_schedule(line, {true, {values, records}})

          _ ->
            qa_sections_schedule(line, {schedule?, {values, records}})
        end
      end)

    records
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def qa_sections_schedule(line, {true, {values, records}}) do
    {true, {values, [line | records]}}
  end

  def qa_sections_schedule(line, {schedule?, {values, records}}) do
    case Regex.run(~r/^#{@regex_components.section}(\d+)(.*?[ ])/, line) do
      [_match, num, _code] ->
        last = List.first(values)
        num = String.to_integer(num)

        cond do
          num == last ->
            {schedule?, {[num | values], [line | records]}}

          num == last + 1 ->
            {schedule?, {[num | values], [line | records]}}

          num > last + 1 ->
            IO.puts("MISSED S.? last: #{last}, this: #{num}, line: #{line}")
            {schedule?, {[num | values], [line | records]}}

          true ->
            {schedule?, {[num | values], [line | records]}}
        end

      nil ->
        {schedule?, {values, [line | records]}}
    end
  end

  @doc """
  Function to print to console the [F and F tags that have not been captured
  with an emoji
  """
  def qa_list_spare_efs(binary, opts) do
    if opts.qa_list_efs || opts.qa_list_bracketed_efs,
      do: IO.puts("qa_list_spare_efs/2\nSpare Efs:")

    cond do
      opts.qa_list_efs ->
        Regex.scan(~r/^\[F\d+.*/m, binary)
        |> Enum.each(&IO.puts("#{&1}"))

        Regex.scan(~r/^F\d+.*/m, binary)
        |> Enum.each(&IO.puts("#{&1}"))

      opts.qa_list_bracketed_efs ->
        Regex.scan(~r/^\[F\d+.*/m, binary)
        |> Enum.each(&IO.puts("#{&1}"))

      opts.qa_list_clean_efs ->
        Regex.scan(~r/^F\d+.*/m, binary)
        |> Enum.each(&IO.puts("#{&1}"))

      true ->
        nil
    end

    binary
  end

  def qa_list_clause_numbers(binary, "\\[::sub_section::\\]" = component) do
    IO.puts("\n\nSUB_SECTION")

    regex = ~s/(?:#{component}|\\[::section::\\]|\\[::annex::\\])(\\d+[A-Z]*-?\\d*)/

    results = Regex.scan(~r/#{regex}/, binary)

    Enum.reduce(results, {0, []}, fn [match, id], {i, acc} ->
      [_, id, suffix, ss] = Regex.run(~r/([0-9]+)([A-Z]*)(-?\d*)/, id)

      iid =
        if ss != "" do
          1
        else
          String.to_integer(id)
        end

      str =
        cond do
          ss != "" -> "\nSECTION #{id}#{suffix}#{ss}\n1"
          String.match?(match, ~r/\[::section/) -> "\nSECTION #{id}#{suffix}"
          String.match?(match, ~r/\[::annex/) -> "\nANNEX #{iid}#{suffix}"
          iid == i -> "#{iid}#{suffix}"
          iid == i + 1 -> "#{iid}#{suffix}"
          iid > i + 1 -> "#{iid} ERROR. Missed #{i + 1}"
          iid < i and iid == 1 -> "\n#{iid}"
          iid < i and iid != 1 -> "\nREBASED and MISSED #{iid}"
        end

      {iid, [str | acc]}
    end)
    |> elem(1)
    |> Enum.reverse()
    |> Enum.join(", ")
    |> IO.write()

    # |> IO.inspect(limit: :infinity)

    binary
  end

  def qa_list_clause_numbers(binary, component) do
    [_, cname] = Regex.run(~r/[^a-z]+([a-z_]*)/m, component)
    # "\\[::" <> cname = component
    IO.puts("\n\n#{String.upcase(cname)}")

    Regex.scan(~r/#{component}(\d+[A-Z]*)/, binary)
    # |> IO.inspect(limit: :infinity)
    |> Enum.reduce({0, []}, fn [_, id], {i, acc} ->
      [_, id, suffix] = Regex.run(~r/([0-9]+)([A-Z]*)/, id)
      id = String.to_integer(id)

      str =
        cond do
          id == i -> "#{id}#{suffix}"
          id == i + 1 -> "#{id}#{suffix}"
          id > i + 1 -> "#{id} ERROR. Missed #{i + 1}"
          id < i and id == 1 -> "\nREBASED #{id}"
          id < i and id != 1 -> "\nREBASED and MISSED #{id}"
        end

      {id, [str | acc]}
    end)
    |> elem(1)
    |> Enum.reverse()
    |> Enum.join(", ")
    |> IO.write()

    # |> IO.inspect(limit: :infinity)

    binary
  end
end
