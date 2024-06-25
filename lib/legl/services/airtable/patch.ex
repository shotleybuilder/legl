defmodule Legl.Services.Airtable.Patch do
  @moduledoc false
  require Logger
  alias Legl.Services.Airtable, as: AT

  def patch(base, table, data) do
    base_url = Legl.Services.Airtable.Endpoint.base_url()
    {:ok, url} = AT.Url.url(base, table, %{})
    headers = Legl.Services.Airtable.Headers.headers()

    data =
      %{"records" => make_airtable_dataset(data), "typecast" => true}

    Logger.info("PATCH DATA: #{inspect(data)}")

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
        Logger.info("PATCH failed: 422\n#{inspect(body)}")
        :error

      {:ok, %{status: status, body: _body}} ->
        Logger.info("PATCH successful: #{inspect(status)}")
        :ok

      {:error, error} ->
        Logger.error("PATCH failed: #{inspect(error)}")
        :error
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
