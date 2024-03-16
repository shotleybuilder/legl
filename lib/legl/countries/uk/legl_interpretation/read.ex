defmodule Legl.Countries.Uk.LeglInterpretation.Read do
  @moduledoc """
  Functions to Read (GET) records from the Legal Interpretation Table
  """
  alias Legl.Countries.Uk.LeglInterpretation.Options, as: LIO
  alias Legl.Services.Airtable.UkAirtable, as: AT

  @default_opts %{
    base_name: "uk ehs",
    table_name: "interpretation",
    print_opts?: true
  }

  @fields ~w[
    Name Term Definition Defined_By Used_By
  ]

  def api_lit_read(opts \\ []) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> LIO.base_table_id()
      |> Map.put(:fields, @fields)
      |> opts()

    case opts.query_name do
      :cancel ->
        :ok

      _ ->
        print_options(opts)

        AT.get_legal_interpretation_records(opts)
    end
  end

  # PRIVATE FUNCTIONS

  @query_names [
    :Term
  ]

  @spec opts(%{query_name: integer()}) :: %{query_name: binary()}
  defp opts(%{query_name: n} = opts) when is_integer(n) do
    Map.put(
      opts,
      :query_name,
      @query_names
      |> Enum.with_index()
      |> Enum.into(%{}, fn {k, v} -> {v, k} end)
      |> Map.get(n)
    )
    |> opts()
  end

  defp opts(%{query_name: query_name} = opts) do
    case query_name do
      :Term ->
        opts
        |> LIO.term()
        |> LIO.formula_term()

      :cancel ->
        opts
    end
  end

  defp opts(opts) do
    case ExPrompt.choose("LIT Read", @query_names) do
      -1 ->
        Map.put(opts, :query_name, :cancel)

      n ->
        opts
        |> Map.put(
          :query_name,
          @query_names
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)
          |> Map.get(n)
        )
    end
    |> opts()
  end

  defp print_options(%{print_opts?: true} = opts) do
    IO.puts("OPTIONS:
      SOURCE___
      Base Name: #{opts.base_name}
      Table ID: #{opts.table_id}
      Formula: #{opts.formula}
      Fields: #{inspect(opts.fields)}
      View: #{opts.view}
      ")
    opts
  end

  defp print_options(opts), do: opts
end
