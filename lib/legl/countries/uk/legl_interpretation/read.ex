defmodule Legl.Countries.Uk.LeglInterpretation.Read do
  @moduledoc """
  Functions to Read (GET) records from the Legal Interpretation Table
  """
  alias Legl.Countries.Uk.LeglInterpretation.Options, as: LIO
  alias Legl.Services.Airtable.UkAirtable, as: AT

  @default_opts %{
    base_name: "uk ehs",
    table_name: "interpretation",
    print_opts?: false
  }

  @fields ~w[
    Name Term Definition Defined_By Used_By
  ]

  def api_lit_read(opts) when is_list(opts), do: api_lit_read(Enum.into(opts, %{}))

  def api_lit_read(opts) when is_map(opts) do
    opts
    |> (&Map.merge(@default_opts, &1)).()
    |> LIO.base_table_id()
    |> Map.put(:fields, @fields)
    |> opts()
    |> get_lit_records_or_cancel()
  end

  # PRIVATE FUNCTIONS

  defp get_lit_records_or_cancel(%{lit_query_name: :cancel}) do
    :ok
  end

  defp get_lit_records_or_cancel(%{test: true} = opts) do
    print_options(opts)
  end

  defp get_lit_records_or_cancel(%{lit_query_name: _query_name} = opts) do
    print_options(opts)

    AT.get_legal_interpretation_records(opts)
  end

  @query_names [
    :Term
  ]

  @spec opts(%{lit_query_name: number()}) :: %{lit_query_name: binary()}
  defp opts(%{lit_query_name: n} = opts) when is_number(n) do
    n = ~s/#{n}/

    Map.put(
      opts,
      :lit_query_name,
      @query_names
      |> Enum.with_index()
      |> Enum.into(%{}, fn {k, v} -> {v, k} end)
      |> Map.put("-1", :cancel)
      |> Map.get(n)
    )
    |> opts()
  end

  defp opts(%{lit_query_name: lit_query_name} = opts) when is_atom(lit_query_name) do
    case lit_query_name do
      :Term ->
        opts =
          opts
          |> LIO.term()
          |> Map.put(:view, "")

        f = LIO.formula_term([], opts)
        Map.put(opts, :formula, ~s/AND(#{Enum.join(f, ",")})/)

      :cancel ->
        opts
    end
  end

  defp opts(opts) do
    case ExPrompt.choose("LIT Read", @query_names) do
      -1 ->
        Map.put(opts, :lit_query_name, :cancel)

      n ->
        opts
        |> Map.put(
          :lit_query_name,
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
