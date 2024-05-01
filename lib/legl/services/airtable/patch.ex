defmodule Legl.Services.Airtable.Patch do
  require Logger
  alias Legl.Services.Airtable, as: AT

  def patch(base, table, data) do
    base_url = Legl.Services.Airtable.Endpoint.base_url()
    {:ok, url} = AT.Url.url(base, table, %{})
    headers = Legl.Services.Airtable.Headers.headers()

    data =
      %{"records" => make_airtable_dataset(data), "typecast" => true}
      |> IO.inspect(label: "PATCH DATA")

    # data = Map.drop(data, [:offence_breaches])

    req_opts = [
      {:base_url, base_url},
      {:url, url},
      {:headers, headers},
      {:body, :iodata},
      {:json, data},
      {:method, :patch}
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
    Enum.map(records, fn %{record_id: record_id} = record ->
      record = Map.drop(record, [:record_id])
      %{id: record_id, fields: record}
    end)
  end

  defp make_airtable_dataset(%{record_id: record_id} = record) do
    record = Map.drop(record, [:record_id])

    %{id: record_id, fields: record}
    |> List.wrap()
  end
end
