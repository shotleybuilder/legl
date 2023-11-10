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
    string = string |> to_string() |> String.trim()

    if "" != string do
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

  def write_to_csv(binary, "lib" <> _rest = path) do
    {:ok, file} =
      path
      |> Path.absname()
      |> File.open([:utf8, :write])

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

  @doc """
  Receives a path as string and returns atom keyed map
  """
  @spec open_and_parse_json_file(binary()) :: map()
  def open_and_parse_json_file(path) do
    path
    |> Path.absname()
    |> File.read()
    |> elem(1)
    |> Jason.decode!(keys: :atoms)
  end

  @doc """
  Function to save records as .json
  """
  @spec save_json(list(), binary()) :: :ok
  def save_json(records, path) do
    json = Map.put(%{}, "records", records) |> Jason.encode!(pretty: true)
    save_at_records_to_file(~s/#{json}/, path)
  end

  @spec save_json_returning(list(), binary()) :: {:ok, list()}
  def save_json_returning(records, path) do
    json = Map.put(%{}, "records", records) |> Jason.encode!(pretty: true)
    {save_at_records_to_file(~s/#{json}/, path), records}
  end

  @spec save_structs_as_json(list(), binary()) :: :ok
  def save_structs_as_json(records, path) do
    maps_from_structs(records)
    |> (&Map.put(%{}, "records", &1)).()
    |> Jason.encode!(pretty: true)
    |> save_at_records_to_file(path)
  end

  @doc """

  """
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

  def append_records_to_file(records, path) when is_binary(records) do
    {:ok, file} =
      path
      |> Path.absname()
      |> File.open([:utf8, :append])

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
    case Regex.run(~r"^https:\/\/(?:www\.)?legislation\.gov\.uk(.*)", url) do
      [_, path] -> {:ok, path}
      _ -> {:error, "Problem getting path from url: #{url}"}
    end
  end

  @spec type_number_year(binary()) ::
          {UK.law_type_code(), UK.law_year(), UK.law_number()} | {:error, :no_match}
  def type_number_year("/id" <> path) do
    type_number_year(path)
  end

  def type_number_year(path) do
    case Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d+)/, path) do
      [_match, type, year, number] -> {type, number, year}
      nil -> {:error, :no_match}
    end
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
  %{"A": 1, "B": 2, ...}
  """
  def alphabet_to_numeric_map_base() do
    Enum.reduce(
      Enum.zip(String.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", trim: true), 1..26),
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

  def numericalise_ordinal(value) do
    ordinals = %{
      "first" => "1",
      "second" => "2",
      "third" => "3",
      "fourth" => "4",
      "fifth" => "5",
      "sixth" => "6",
      "seventh" => "7",
      "eighth" => "8",
      "ninth" => "9",
      "tenth" => "10",
      "eleventh" => "11",
      "twelfth" => "12",
      "thirteenth" => "13",
      "fourteenth" => "14",
      "fifteenth" => "15",
      "sixteenth" => "16",
      "seventeenth" => "17",
      "eighteenth" => "18",
      "nineteenth" => "19",
      "twentieth" => "20"
    }

    search = String.downcase(value)

    case Map.get(ordinals, search) do
      nil -> value
      x -> x
    end
  end

  def map_filter_out_empty_members(records) do
    Enum.map(records, fn record ->
      Map.filter(record, fn {_k, v} -> v not in [nil, "", []] end)
    end)
  end

  @spec maps_from_structs([]) :: []
  def maps_from_structs([]), do: []

  @spec maps_from_structs(list()) :: list()
  def maps_from_structs(records) when is_list(records) do
    Enum.map(records, fn
      record when is_struct(record) -> Map.from_struct(record)
      record when is_map(record) -> record
    end)
  end

  @doc """
  Function to return the members
  """
  @spec delta_lists(list(), list()) :: :no_change | String.t()
  def delta_lists(old, new) do
    MapSet.difference(convert_to_mapset(new), convert_to_mapset(old))
    |> MapSet.to_list()
  end

  def convert_to_mapset(list) when list in [nil, ""], do: MapSet.new()

  def convert_to_mapset(list) when is_binary(list) do
    list
    |> String.split(",")
    |> Enum.map(&String.trim(&1))
    |> MapSet.new()
  end

  def convert_to_mapset(list), do: MapSet.new(list)
end
