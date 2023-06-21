defmodule Legl.Services.Airtable.Records do
  @moduledoc """
  Functions for working on the records retrieved from Airtable
  """
  # require Logger
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  def get_bases() do
    # {:ok, records} =
    get("/meta")
    # Jason.decode!(records)
  end

  @doc """
    Action: get data from Airtable

    $ curl https://api.airtable.com/v0/appj4oaimWQfwtUri/UK%20-%20England%20&%20Wales%20-%20Pollution \
    -H "Authorization: Bearer YOUR_SECRET_API_TOKEN"

    Ensure the params are correct by enforcing against a %Params{} struct.
    Uses sensible defaults

    Handles pagination.
    Airtable returns {"records": [], "offset": "a_record_id"}
    when more records than pageSize or default of 100 are returned
  """
  def get_records({jsonset, recordset}, params) when is_list(recordset) do
    with(
      {:ok, url} <- Url.url(params.base, params.table, params.options),
      # IO.inspect(url),
      {:ok, json} <- get(url),
      # IO.inspect(json),
      data <- Jason.decode!(json),
      %{
        "json" => json,
        "records" => records,
        "offset" => offset
      } <- set_params(json, data)
    ) do
      IO.puts("Call to Airtable returned #{Enum.count(records)} records")
      options = Map.put(params.options, :offset, offset)
      params = Map.put(params, :options, options)
      get_records({jsonset ++ json, recordset ++ records}, params)
    else
      %{"json" => _json, "records" => records} ->
        json = Jason.encode!(%{"records" => recordset ++ records})
        {:ok, {json, recordset ++ records}}

      # {:ok, {jsonset ++ json, recordset ++ records}}

      {:error, error} ->
        {:error, error}
    end
  end

  def set_params(json, %{"records" => records, "offset" => offset}) do
    %{"json" => json, "records" => records, "offset" => offset}
  end

  def set_params(json, %{"records" => records}) do
    %{"json" => json, "records" => records}
  end

  def set_params(_, %{"error" => error}) do
    {:error, error}
  end

  def set_params(json, records) do
    %{"json" => json, "records" => records}
  end

  @doc """
    Get the records from the Airtable API endpoint as a stream
  """
  def get(url) do
    Stream.resource(
      fn ->
        Client.get!(
          url,
          [Accept: "Application/json; Charset=utf-8"],
          stream_to: self(),
          async: :once
        )
      end,
      fn %HTTPoison.AsyncResponse{id: id} = resp ->
        receive do
          %HTTPoison.AsyncStatus{id: ^id, code: _code} ->
            # IO.inspect(code, label: "STATUS: ")
            HTTPoison.stream_next(resp)
            {[], resp}

          %HTTPoison.AsyncHeaders{id: ^id, headers: _headers} ->
            # IO.inspect(headers, label: "HEADERS: ")
            HTTPoison.stream_next(resp)
            {[], resp}

          %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
            HTTPoison.stream_next(resp)
            {[chunk], resp}

          %HTTPoison.AsyncEnd{id: ^id} ->
            {:halt, resp}
        end
      end,
      fn resp -> :hackney.close(resp.id) end
    )
    |> Enum.into([])
    |> (&{:ok, &1}).()
  end
end
