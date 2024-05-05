defmodule Legl.Countries.Uk.LeglRegister.Crud.Read do
  @moduledoc """
  Functions to GET records from the Legal Register Table (LRT)
  """
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  alias Legl.Services.Airtable.UkAirtable, as: AT

  # SUPABASE=============================================
  def exists_pg?(opts) do
    case Legl.Services.Supabase.Client.get_legal_register_record(opts) do
      {:ok, ""} ->
        IO.puts(~s/#{opts.name} MISSING in Supabase/)
        false

      {:ok, []} ->
        IO.puts(~s/#{opts.name} MISSING in Supabase/)
        false

      {:ok, body} ->
        IO.puts(~s/#{opts.name} EXISTS in Supabase\n#{inspect(body)}/)
        true

      {:error, _} ->
        IO.puts(~s/#{opts.name} MISSING in Supabase/)
        false
    end
  end

  # AIRTABLE=============================================

  @doc """
  Receives a Record map of Number, type_code and Year and options with base_id
  and table_id and returns a boolean true or false

  Function to check presence of law in a Legal Register
  """
  @spec exists_at?(map(), map()) :: boolean()
  def exists_at?(record, opts) when is_map(record) do
    {:ok, url} = Legl.Countries.Uk.LeglRegister.Helpers.Create.setUrl(record, opts)

    with {:ok, body} <- Legl.Services.Airtable.Client.request(:get, url, []),
         %{records: records} = Jason.decode!(body, keys: :atoms) do
      case records do
        [] ->
          IO.puts(~s/#{record."Name"} MISSING in Airtable/)
          false

        _ ->
          IO.puts(~s/#{record."Name"} EXISTS in Airtable/)
          true
      end
    else
      {:ok, _, _} ->
        true

      {:error, reason} ->
        IO.puts("ERROR: #{reason}")
    end
  end

  @fields ~w[
    Name record_id Title_EN type_code type_class Number Year Family
  ]

  @default_opts %{
    base_name: "UK_EHS",
    formula: "",
    fields: @fields,
    view: "",
    print_opts?: true
  }

  def api_read(opts \\ []) do
    opts = api_read_opts(opts)

    case opts.query_name do
      :cancel ->
        []

      _ ->
        print_options(opts)

        AT.get_legal_register_records(opts)
    end
  end

  def api_read_opts(opts) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> LRO.base_table_id()
      |> opts()

    opts =
      case Map.has_key?(opts, "QA_taxa") do
        true -> Map.put(opts, :formula, ~s/#{opts.formula},{QA_taxa}=#{opts."QA_taxa"}/)
        _ -> opts
      end

    params(opts)
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
        opts
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

  defp params(opts) do
    Map.put(opts, :params, %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{
        view: opts.view,
        fields: opts.fields,
        formula: opts.formula
      }
    })
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
