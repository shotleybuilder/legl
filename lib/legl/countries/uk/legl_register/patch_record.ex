defmodule Legl.Countries.Uk.LeglRegister.PatchRecord do
  @moduledoc """
  PATCH records in a Legal Register
  """

  alias Legl.Services.Supabase.Client
  alias Legl.Countries.Uk.LeglRegister.LegalRegister

  # SUPABASE=============================================

  @doc """
  Retrieves the HTTP configuration for the Supabase client.

  Returns the HTTP configuration specified in the `:supabase_client` application environment.

  ## Examples

      iex> Supabase.Client.http()
      %HTTPoison.Config{
        ...  # HTTP configuration details
      }

  """

  def supabase_patch_record(record, opts) do
    record =
      record
      |> Map.from_struct()
      |> Map.drop(Legl.Countries.Uk.LeglRegister.DropFields.drop_supabase_fields())
      # Converts AT struct atoms to PG atoms
      |> Legl.Countries.Uk.LeglRegister.LegalRegister.supabase_conversion()
      |> Legl.Countries.Uk.LeglRegister.PostRecord.conv_hearts_to_new_lines()
      |> Legl.Countries.Uk.LeglRegister.PostRecord.linked_array_fields()

    opts = Map.put(opts, :data, record)
    Client.update_legal_register_record(opts)
  end

  # AIRTABLE=============================================

  @doc """

  """
  @spec run(map() | list(), map()) :: :ok
  def run([], _), do: {:error, "RECORDS: EMPTY LIST: No data to PATCH"}

  def run(records, %{drop_fields: _} = opts) when is_list(records) do
    # IO.inspect(records, label: "PATCH")
    records
    |> Enum.map(&build(&1, opts))
    |> patch(opts)
  end

  def run(%LegalRegister{} = record, opts) when is_struct(record) do
    record
    |> Legl.Utility.map_from_struct()
    |> build(opts)
    |> patch(opts)
  end

  def run(record, opts) when is_map(record) do
    build(record, opts)
    |> patch(opts)
  end

  def build(%{id: _, fields: fields} = record, opts)
      when is_map(record) do
    fields
    |> Legl.Countries.Uk.LeglRegister.Helpers.clean_record(opts)
    |> (&Map.put(record, :fields, &1)).()
    |> Map.drop([:createdTime])
  end

  def build(%{record_id: record_id} = record, opts) when is_map(record) do
    # Name is a calculated field in AT
    record =
      Map.drop(record, [:record_id, :Name])
      |> Legl.Countries.Uk.LeglRegister.Helpers.clean_record(opts)

    Map.merge(%{}, %{id: record_id, fields: record})
  end

  @spec patch(map(), map()) :: :ok
  def patch(record, opts) when is_map(record) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    record = Map.merge(%{}, %{"records" => List.wrap(record), "typecast" => true})
    # |> IO.inspect(label: "Record Cleaned for Patch")

    with({:ok, json} <- Jason.encode(record)) do
      Legl.Services.Airtable.AtPatch.patch_records(json, headers, params)
    else
      {:error, %Jason.EncodeError{message: error}} ->
        # IO.puts(~s/#{error}\n#{inspect(record)}/)
        IO.puts(~s/#{error}/)
        :ok
    end
  end

  def patch([], _), do: :ok

  @spec patch(list(), map()) :: :ok
  def patch(records, opts) when is_list(records) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    records =
      Enum.chunk_every(records, 10)
      |> Enum.map(fn set ->
        Map.merge(%{}, %{"records" => set, "typecast" => true})
        |> Jason.encode!()
      end)

    Enum.each(records, fn record_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(record_subset, headers, params)
    end)
  end
end
