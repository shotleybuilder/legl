defmodule Legl.Countries.Uk.LeglRegister.Helpers do
end

defmodule Legl.Countries.Uk.LeglRegister.Helpers.NewLaw do
  @moduledoc """
  Module to filter a list of laws based on whether they are a record or not a
  record in the Legal Register Base
    Records parameter should have this shape:
    [
      %{
        Name: "UK_uksi_2003_3073_RVRLAR",
        Number: "3073",
        Title_EN: "Road Vehicles (Registration and Licensing) (Amendment) (No. 4) Regulations",
        Year: "2003",
        type_code: "uksi"
      }
    ]
  """
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  @doc """
  Function to filter out laws that are present in the Base.
  Laws that are a record in the the Base are removed from the records.
  To create a list of records suitable for a POST request.
  """
  def filterDelta([], _), do: {:ok, []}

  def filterDelta(records, opts) do
    with {:ok, records} <- setUrl(records, opts),
         records <- filter(:delta, records) do
      {:ok, records}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Function to filter out laws that are NOT present in the Base.
  Laws that are NOT in the Base are removed from the list
  To create a list suitable for a PATCH request
  """
  def filterMatch(records, opts) do
    with {:ok, records} <- setUrl(records, opts),
         records <- filter(:match, records) do
      {:ok, records}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def setUrl(records, opts) when is_list(records) do
    records =
      Enum.reduce(records, [], fn
        %{Number: number, Year: year, type_code: type_code} = record, acc ->
          options = [
            formula: ~s/AND({Number}="#{number}", {Year}="#{year}", {type_code}="#{type_code}")/,
            fields: ["Name"]
          ]

          with({:ok, url} <- Url.url(opts.base_id, opts.table_id, options)) do
            [Map.put(record, :url, url) | acc]
          else
            {:error, msg} ->
              IO.puts("ERROR: #{msg}")
              [record | acc]
          end

        record, acc ->
          IO.puts("ERROR: Incomplete record.\nCannot check presence in Base.\n#{inspect(record)}")
          [record | acc]
      end)

    case records do
      [] -> {:error, "\nNo record URLs could be set\n#{__MODULE__}.setUrl"}
      _ -> {:ok, records}
    end
  end

  defp filter(:delta, records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            Map.drop(record, [:url])
            |> (&[&1 | acc]).()

          _ ->
            acc
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR: #{record[:Title_EN]}\n#{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end

  defp filter(:match, records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            acc

          _ ->
            Map.drop(record, [:url])
            |> (&[&1 | acc]).()
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR #{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord do
  @moduledoc """
  Module to POST new records to the Legal Register

  """
  def run([], _), do: {:error, "RECORDS: EMPTY LIST: No data to Post"}

  def run(records, %{drop_fields: drop_fields} = opts) do
    with(
      records <- clean_records(records, drop_fields),
      json =
        Map.merge(%{}, %{"records" => records, "typecast" => true}) |> Jason.encode!(pretty: true),
      :ok = Legl.Utility.save_at_records_to_file(json, opts.api_path),
      :ok <- post(records, opts)
    ) do
      :ok
    end
  end

  def run(_records, _opts), do: {:error, "OPTS: No :drop_fields list in opts"}

  def post(records, opts) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    records =
      Enum.chunk_every(records, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.merge(%{}, %{"records" => set, "typecast" => true})
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(records, fn subset ->
      Legl.Services.Airtable.AtPost.post_records(subset, headers, params)
    end)
  end

  def clean_records(records, drop_fields) when is_list(records) do
    Enum.map(records, fn
      # Airtable records w/ :fields param
      %{fields: fields} ->
        Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
        |> Map.drop(drop_fields)
        |> (&Map.put(%{}, :fields, &1)).()

      # Flat records map
      record ->
        Map.filter(record, fn {_k, v} -> v not in [nil, "", []] end)
        |> Map.drop(drop_fields)
        |> (&Map.put(%{}, :fields, &1)).()
    end)
  end
end
