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

  def csv_quote_enclosure(string) do
    ~s/"#{string}"/
  end
end
