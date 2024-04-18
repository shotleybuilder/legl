defmodule Legl.Countries.Uk.LeglRegister.PostRecord do
  @moduledoc """
  Module to POST new records to the Legal Register

  """

  alias Legl.Services.Supabase.Client
  alias Legl.Countries.Uk.LeglRegister.Crud.Read

  @headers [{:"Content-Type", "application/json"}]

  # SUPABASE=============================================

  # Posts a record to the Supabase table for the UK Legal Register.
  #
  # The `record` parameter is the data to be posted.
  # The `opts` parameter is a map of options.
  #
  # Returns the result of creating the legal register record.
  def supabase_post_record(record, opts) do
    record =
      record
      |> Map.drop(Legl.Countries.Uk.LeglRegister.DropFields.drop_supabase_fields())
      # Converts AT struct atoms to PG atoms
      |> Legl.Countries.Uk.LeglRegister.LegalRegister.supabase_conversion()
      |> conv_hearts_to_new_lines()
      |> linked_array_fields()

    # |> IO.inspect(label: "POSTGRES RECORD")

    opts = Map.put(opts, :supabase_table, "uk_lrt")
    opts = Map.put(opts, :data, record)
    Client.create_legal_register_record(opts)
  end

  defp conv_hearts_to_new_lines(record) do
    Enum.reduce(record, %{}, fn
      {:family, v}, acc ->
        Map.put(acc, :family, v)

      {k, v}, acc when is_binary(v) ->
        case String.contains?(v, "💚️") do
          true -> Map.put(acc, k, Regex.replace(~r/💚️/m, v, "\n"))
          false -> Map.put(acc, k, v)
        end

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end

  defp linked_array_fields(record) do
    Enum.reduce(record, %{}, fn
      {k, v}, acc when k in [:enacted_by, :amending, :amended_by, :rescinding, :rescinded_by] ->
        acc
        |> Map.put(k, ~s/{#{v}}/)
        |> Map.put(~s/linked_#{k}/ |> String.to_atom(), ~s/{#{find_records(v)}}/)

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end

  defp find_records(names) do
    names = names |> String.split(",") |> Enum.map(&String.trim/1)
    opts = %{supabase_table: "uk_lrt", name: names, select: "name"}

    case Client.get_legal_register_record(opts) do
      {:ok, body} -> body |> Enum.map(&Map.get(&1, "name")) |> Enum.join(",")
      {:error, _} -> ""
    end
  end

  # AIRTABLE=============================================

  def post_single_record(record, opts) do
    params = %{base: opts.base_id, table: opts.table_id, options: %{}}

    record =
      record
      # Name is a calculated field in AT
      |> Map.drop([:Name])
      |> (&Map.merge(%{}, %{fields: &1})).()
      |> List.wrap()

    json = Map.merge(%{}, %{"records" => record, "typecast" => true}) |> Jason.encode!()
    # IO.inspect(json, label: "__MODULE__", limit: :infinity)
    Legl.Services.Airtable.AtPost.post_records([json], @headers, params)
  end

  # AT - Collection of Records

  @spec run(map() | list(), map()) :: :ok
  def run([], _), do: {:error, "RECORDS: EMPTY LIST: No data to Post"}

  def run(record, opts) when is_map(record) do
    with false <- Read.exists_at?(record, opts) do
      run([record], opts)
    else
      true -> :ok
    end
  end

  def run(records, opts) when is_list(records) do
    with(
      records <- Legl.Countries.Uk.LeglRegister.Helpers.clean_records(records, opts),
      # {:ok, records} <- Create.filter_delta(records, opts),
      json =
        Map.merge(%{}, %{"records" => records, "typecast" => true}) |> Jason.encode!(pretty: true),
      :ok = Legl.Utility.save_at_records_to_file(json, opts.api_post_path),
      :ok <- post(records, opts)
    ) do
      :ok
    end
  end

  def run(_records, _opts), do: {:error, "OPTS: No :drop_fields list in opts"}

  def post(records, opts) when is_list(records) do
    # Airtable only accepts sets of 10x records in a single PATCH request
    params = %{base: opts.base_id, table: opts.table_id, options: %{}}

    records =
      Enum.chunk_every(records, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.merge(%{}, %{"records" => set, "typecast" => true})
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(records, fn subset ->
      Legl.Services.Airtable.AtPost.post_records(subset, @headers, params)
    end)
  end
end
