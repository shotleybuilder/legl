defmodule Legl.Services.Airtable.Get do
  require Logger
  alias Legl.Services.Airtable, as: AT

  def get(base, table, params) do
    base_url = AT.Endpoint.base_url()
    {:ok, url} = AT.Url.url(base, table, params)
    headers = AT.Headers.headers()

    req_opts = [
      {:base_url, base_url},
      {:url, url},
      {:headers, headers},
      {:method, :get}
    ]

    req =
      Req.new(req_opts)
      |> Req.Request.append_request_steps(debug_url: debug_url())

    # |> Req.Request.append_request_steps(debug_body: debug_body())

    case Req.request(req) do
      {:ok, %{status: 422, body: body}} ->
        Logger.info("GET failed: 422\n#{inspect(body)}")
        :ok

      {:ok, %{status: _status, body: %{"records" => records}}} ->
        Logger.info("GET successful: #{inspect(records)}")
        {:ok, records}

      {:error, error} ->
        Logger.error("GET failed: #{inspect(error)}")
        :ok
    end
  end

  def get_id(base, table, params) do
    base_url = Legl.Services.Airtable.Endpoint.base_url()
    {:ok, url} = AT.Url.url(base, table, params)
    headers = Legl.Services.Airtable.Headers.headers()

    req_opts = [
      {:base_url, base_url},
      {:url, url},
      {:headers, headers},
      {:method, :get}
    ]

    case Req.get(req_opts) do
      {:ok, %{status: 422, body: body}} ->
        Logger.info("Request failed: 422\n#{inspect(body)}")
        :ok

      {:ok,
       %{
         status: _status,
         body: %{"records" => [%{"createdTime" => _, "fields" => _, "id" => record_id}]}
       }} ->
        Logger.info("Request returned RECORD_ID: #{inspect(record_id)}")
        {:ok, record_id}

      {:ok, %{status: status, body: %{"records" => []}}} ->
        Logger.info("Request returned 0 records")
        {:ok, nil}

      {:ok, %{status: _status, body: %{"records" => records}}} ->
        Logger.info("Request returned more than 1 record! #{inspect(records)}")
        :ok

      {:error, error} ->
        Logger.error("Request failed: #{inspect(error)}")
        :ok
    end
  end

  defp debug_url,
    do: fn request ->
      IO.inspect(URI.to_string(request.url), label: "URL")
      request
    end
end
