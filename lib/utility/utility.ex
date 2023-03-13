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
    |> (&("#{&1.day}/#{&1.month}/#{&1.year}")).()
  end

  def csv_header_row(fields, at_csv) do
    Enum.join(fields, ",")
    |> Legl.Utility.write_to_csv(at_csv)
  end

  def csv_quote_enclosure(string) do
    ~s/"#{string}"/
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

  def save_at_records_to_file(records) when is_list(records) do
    {:ok, file} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.open([:utf8, :write])
    IO.puts(file, inspect(records, limit: :infinity))
    File.close(file)
    :ok
  end

  def resource_path(url) do
    [_, path] = Regex.run(~r"^https:\/\/www.legislation.gov.uk(.*)", url)
    path
  end

  def yyyy_mm_dd(date) do
    [_, year, month, day] = Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, date)
    "#{day}/#{month}/#{year}"
  end

end
