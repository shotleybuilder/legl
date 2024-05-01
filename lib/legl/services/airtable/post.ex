defmodule Legl.Services.Airtable.Post do
  @moduledoc """
  This module is responsible for posting data to Airtable.
  """
  require Logger
  alias Legl.Services.Airtable, as: AT

  def post(base, table, data) do
    base_url = Legl.Services.Airtable.Endpoint.base_url()
    {:ok, url} = AT.Url.url(base, table, %{})
    headers = Legl.Services.Airtable.Headers.headers()

    data = make_airtable_dataset(data)

    # data = Map.drop(data, [:offence_breaches])

    req_opts = [
      {:base_url, base_url},
      {:url, url},
      {:headers, headers},
      {:body, :iodata},
      {:json, data},
      {:method, :post}
    ]

    req = Req.new(req_opts)
    # |> Req.Request.append_request_steps(debug_body: debug_body())

    case Req.request(req) do
      {:ok, %{status: 422, body: body}} ->
        Logger.info("Request failed: 422\n#{inspect(body)}")
        :ok

      {:ok, %{status: status, body: _body}} ->
        Logger.info("Request successful: #{inspect(status)}")
        :ok

      {:error, error} ->
        Logger.error("Request failed: #{inspect(error)}")
        :ok
    end
  end

  defp make_airtable_dataset(records) when is_list(records) do
    records =
      Enum.map(records, fn record ->
        %{fields: record}
      end)

    %{"records" => records, "typecast" => true}
  end

  defp make_airtable_dataset(record) do
    record =
      %{fields: record}
      |> List.wrap()

    %{"records" => record, "typecast" => true}
  end
end
