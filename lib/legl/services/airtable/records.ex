defmodule Legl.Services.Airtable.Records do

  @moduledoc """
  Functions for working on the records retrieved from Airtable
  """
  #require Logger
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  def get_bases() do
    #{:ok, records} =
      get("/meta")
    #Jason.decode!(records)
  end

  @doc """
  Action: get data from Airtable

  $ curl https://api.airtable.com/v0/appj4oaimWQfwtUri/UK%20-%20England%20&%20Wales%20-%20Pollution \
  -H "Authorization: Bearer YOUR_SECRET_API_TOKEN"

  Ensure the params are correct by enforcing against a %Params{} struct.
  Uses sensible defaults

  @doc """
  Handles pagination.
  Airtable returns {"records": [], "offset": "a_record_id"}
  when more records than pageSize or default of 100 are returned
  """
  def get_records({jsonset, recordset}, params) when is_list(recordset) do
    with(
      {:ok, url} <- Url.url(params.base, params.table, params.options),
      {:ok, json} <- get(url),
      data <- Jason.decode!(json),
      %{"json" => json, "records" => records, "offset" => offset} <- get_records(json, data),
      options = Map.put(params.options, :offset, offset),
      params = Map.put(params, :options, options)
    ) do
      get_records({jsonset ++ json, recordset ++ records}, params)
    else
      %{"json" => json, "records" => records} ->
        {:ok, {jsonset ++ json, recordset ++ records}}
      {:error, error} ->
        {:error, error}
    end
  end
  def get_records(json, %{"records" => records, "offset" => offset}) do
    %{"json" => json, "records" => records, "offset" => offset}
  end
  def get_records(json, %{"records" => records}) do
    %{"json" => json, "records" => records}
  end
  def get_records(_, %{"error" => error}) do
    {:error, error}
  end
  def get_records(json, records) do
    %{"json" => json, "records" => records}
  end

  @doc """
    Get the records from the Airtable API endpoint as a stream
  """
  def get(url) do
    Stream.resource(
      fn -> Client.get!(
          url,
          ["Accept": "Application/json; Charset=utf-8"],
          [stream_to: self(), async: :once])
      end,
      fn %HTTPoison.AsyncResponse{id: id} = resp ->
        receive do
          %HTTPoison.AsyncStatus{id: ^id, code: _code}->
            #IO.inspect(code, label: "STATUS: ")
            HTTPoison.stream_next(resp)
            {[], resp}
          %HTTPoison.AsyncHeaders{id: ^id, headers: _headers}->
            #IO.inspect(headers, label: "HEADERS: ")
            HTTPoison.stream_next(resp)
            {[], resp}
          %HTTPoison.AsyncChunk{id: ^id, chunk: chunk}->
            HTTPoison.stream_next(resp)
            {[chunk], resp}
          %HTTPoison.AsyncEnd{id: ^id}->
            {:halt, resp}
        end
      end,
      fn resp -> :hackney.close(resp.id) end
    )
    |> Enum.into([])
    |> (&{:ok, &1}).()
  end



end
