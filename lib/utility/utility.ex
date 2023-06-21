defmodule Legl.Utility do
  @moduledoc false

  @doc """
  Utility function to time the parser.
  Arose when rm_header was taking 5 seconds!  Faster now :)
  """
  def parse_timer() do
    {:ok, binary} = File.read(Path.absname(Legl.original()))
    {t, binary} = :timer.tc(UK, :rm_header, [binary])
    display_time("rm_header", t)
    {t, _binary} = :timer.tc(UK, :rm_explanatory_note, [binary])
    display_time("rm_explanatory_note", t)
  end

  def parser_timer(arg, func, name) do
    {t, binary} = :timer.tc(func, [arg])
    display_time(name, t)
    binary
  end

  defp display_time(f, t) do
    IO.puts("#{f} takes #{t} microseconds or #{t / 1_000_000} seconds")
  end

  def todays_date() do
    DateTime.utc_now()
    |> (&"#{&1.day}/#{&1.month}/#{&1.year}").()
  end

  def csv_header_row(fields, at_csv) do
    Enum.join(fields, ",")
    |> Legl.Utility.write_to_csv(at_csv)
  end

  def csv_quote_enclosure(string) do
    if "" != string |> to_string() |> String.trim() do
      ~s/"#{string}"/
    else
      string
    end
  end

  def csv_list_quote_enclosure(string) do
    ~s/[#{string}]/
  end

  def append_to_csv(binary, filename) do
    {:ok, file} =
      "lib/#{filename}.csv"
      |> Path.absname()
      |> File.open([:utf8, :append])

    IO.puts(file, binary)
    File.close(file)
    :ok
  end

  def write_to_csv(binary, filename) do
    {:ok, file} =
      "lib/#{filename}.csv"
      |> Path.absname()
      |> File.open([:utf8, :write])

    IO.puts(file, binary)
    File.close(file)
    :ok
  end

  def save_at_records_to_file(records),
    do: save_at_records_to_file(records, "lib/legl/data_files/txt/airtable.txt")

  def save_at_records_to_file(records, path) when is_list(records) do
    {:ok, file} =
      path
      |> Path.absname()
      |> File.open([:utf8, :write])

    IO.puts(file, inspect(records, limit: :infinity))
    File.close(file)
    :ok
  end

  def save_at_records_to_file(records, path) when is_binary(records) do
    {:ok, file} =
      path
      |> Path.absname()
      |> File.open([:utf8, :write])

    IO.puts(file, records)
    File.close(file)
    :ok
  end

  def count_csv_rows(filename) do
    binary =
      ("lib/" <> filename <> ".csv")
      |> Path.absname()
      |> File.read!()

    binary |> String.graphemes() |> Enum.count(&(&1 == "\n"))
  end

  def resource_path(url) do
    case Regex.run(~r"^https:\/\/www.legislation.gov.uk(.*)", url) do
      [_, path] -> {:ok, path}
      _ -> {:error, "Problem getting path from url: #{url}"}
    end
  end

  def type_year_number(path) do
    Regex.run(~r/\/(a-z)*?\/(\d{2})\/(\d{2})/, path)
  end

  def split_name(name) do
    case Regex.run(~r/_([a-z]*?)_(\d{4})_(.*?)_/, name) do
      [_, type, year, number] ->
        {type, year, number}

      _ ->
        # UK_ukpga_1960_Eliz2/8-9/34_RSA
        case Regex.run(~r/_([a-z]*?)_\d{4}_(.*?)_/, name) do
          [_, type, number] ->
            {type, number}

          nil ->
            {:error, ~s/no match for #{name}/}
        end
    end
  end

  def yyyy_mm_dd(date) do
    [_, year, month, day] = Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, date)
    "#{day}/#{month}/#{year}"
  end

  def duplicate_records(list) do
    list
    |> Enum.group_by(& &1)
    # |> IO.inspect()
    |> Enum.filter(fn
      {_, [_, _ | _]} -> true
      _ -> false
    end)
    # |> IO.inspect()
    |> Enum.map(fn {x, _} -> x end)
    |> Enum.sort()
  end

  @doc """
  Removes duped spaces in a line as captured by the marker
  e.g. "\\[::annex::\\]"
  """
  def rm_dupe_spaces(binary, regex) do
    # remove double, triple and quadruple spaces
    Regex.replace(
      ~r/^(#{regex}.*)/m,
      binary,
      fn _, x -> String.replace(x, ~r/[ ]{2,4}/m, " ") end
    )
  end

  @doc """
  %{"1": "A", "2": "B", ...}
  """
  def alphabet_map() do
    Enum.reduce(
      Enum.zip(1..24, String.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", trim: true)),
      %{},
      fn {x, y}, acc -> Map.put(acc, :"#{x}", y) end
    )
  end

  @doc """
  %{"A" => 65, "B" => 66, ...}
  """
  def alphabet_to_numeric_map() do
    Enum.reduce(
      Enum.zip(String.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", trim: true), 65..(65 + 25)),
      %{},
      fn {x, y}, acc -> Map.put(acc, "#{x}", y) end
    )
    |> Map.put("", 64)
  end

  @doc """
  Columns on screen
  """
  def cols() do
    {_, cols} = :io.columns()
    cols
  end

  def upcaseFirst(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
end
