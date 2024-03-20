defmodule Legl.Countries.Uk.LeglRegister.Crud.Read do
  @moduledoc """
  Functions to GET records from the Legal Register Table (LRT)
  """
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  alias Legl.Services.Airtable.UkAirtable, as: AT

  @default_opts %{
    print_opts?: true,
    formula: ""
  }

  @fields ~w[
    Name record_id Title_EN type_code type_class Number Year Family
  ]

  def api_read(opts \\ []) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Map.put(:base_name, "UK EHS")
      |> LRO.base_table_id()
      |> Map.put(:fields, @fields)
      |> opts()
      |> Map.put_new(:view, "")

    opts =
      case Map.has_key?(opts, "QA_taxa") do
        true -> Map.put(opts, :formula, ~s/#{opts.formula},{QA_taxa}=#{opts."QA_taxa"}/)
        _ -> opts
      end

    case opts.query_name do
      :cancel ->
        []

      _ ->
        print_options(opts)

        AT.get_legal_register_records(opts)
    end
  end

  # PRIVATE FUNCTIONS

  @query_names [
    :Name,
    :"List of Names",
    :View,
    :Family,
    :"Family + Type Class",
    :"Family + Type Code",
    :"Family + Type Class + Type Code"
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
      :Name ->
        opts
        |> LRO.name()
        |> LRO.formula_name()

      :"List of Names" ->
        opts
        |> (&Map.put(&1, :names, ExPrompt.string(~s/Names (as csv)/) |> String.split(","))).()
        |> LRO.formula_names()

      :View ->
        opts
        |> LRO.view()

      :Family ->
        opts
        |> LRO.family()
        |> (&LRO.formula_family([], &1)).()

      :"Family + Type Class" ->
        opts
        |> LRO.family()
        |> LRO.type_class()
        |> (&LRO.formula_family([], &1)).()
        |> (&LRO.formula_type_class([], &1)).()

      :"Family + Type Code" ->
        opts
        |> LRO.family()
        |> LRO.type_code()
        |> (&LRO.formula_family([], &1)).()
        |> (&LRO.formula_type_code([], &1)).()

      :"Family + Type Class + Type Code" ->
        opts
        |> LRO.family()
        |> LRO.type_class()
        |> LRO.type_code()
        |> (&LRO.formula_family([], &1)).()
        |> (&LRO.formula_type_class([], &1)).()
        |> (&LRO.formula_type_code([], &1)).()

      :cancel ->
        :ok

      _ ->
        :ok
    end
  end

  defp opts(opts) do
    case ExPrompt.choose("LRT Read", @query_names) do
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
