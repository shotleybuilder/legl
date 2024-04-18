defmodule Legl.Services.Airtable.AtPost do
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  def post_records(body, headers, params) do
    with(
      {:ok, url} <- Url.url(params.base, params.table, params.options),
      {:ok, response} <- Client.post(url, body, headers)
    ) do
      case response do
        %HTTPoison.Response{status_code: 422, body: body} ->
          IO.puts("AT Status: 422")
          IO.inspect(body)

        %HTTPoison.Response{status_code: code, body: _body} ->
          IO.puts("AT Status Code: #{code}")
      end
    else
      {:error, error} ->
        {:error, error}
    end
  end
end
