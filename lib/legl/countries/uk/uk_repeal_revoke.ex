defmodule Legl.Countries.Uk.UkRepealRevoke do

  alias Legl.Services.LegislationGovUk.RecordGeneric, as: Record

  def leg_gov_uk_record(url) do
    with(
      table_data <- Record.repeal_revoke(url),
      {:ok, data} <- process_amendment_table(table_data)
    ) do
      {:ok, data}
    else
      {nil, _msg} -> nil
    end
  end

  def process_amendment_table([]) do
    IO.puts("record.ex: number of records: 0")
    {nil, []}
  end

  def process_amendment_table([{"tbody", _, records}]) do
    Enum.reduce(records, [], fn {_, _, x}, acc ->
      case proc_amd_tbl_row(x) do
        {:ok, title, "Regulations", "revoked", amending_title, path} ->
          [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)
          [[title, amending_title, path, type, year, number] | acc]

        {:ok, title, "Act", "repealed", amending_title, path} ->
          [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)
          [[title, amending_title, path, type, year, number] | acc]

        _ -> acc
      end
    end)
    |> case do
      [] -> {nil, "not repealed or revoked"}
      [data] -> {:ok, data}
    end
  end

  @pattern quote do: [
    {"td", _, [{_, _, [var!(title)]}]},
    {"td", _, _},
    {"td", _, [{_, [{"href", _}], [var!(amendment_target)]}]},
    {"td", _, [var!(amendment_effect)]},
    {"td", _, [{_, _, [var!(amending_title)]}]},
    {"td", _, [{_, [{"href", var!(path)}], _}]},
    {"td", _, _},
    {"td", _, _},
    {"td", _, _}
  ]

  def proc_amd_tbl_row(row) do
    case row do
      unquote(@pattern) ->
        {:ok, title, amendment_target, amendment_effect, amending_title, path}
      _ -> {:error, "no match"}
    end
  end
end
