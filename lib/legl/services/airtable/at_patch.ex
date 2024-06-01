defmodule Legl.Services.Airtable.AtPatch do
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  @spec patch_records(
          any(),
          any(),
          atom()
          | %{:base => binary(), :options => any(), :table => binary(), optional(any()) => any()}
        ) :: any()
  def patch_records(body, headers, params) do
    with(
      {:ok, url} <- Url.url(params.base, params.table, params.options),
      # print(url, headers, body),
      {:ok, response} <- Client.patch(url, body, headers)
    ) do
      case response do
        %HTTPoison.Response{status_code: 403, body: body} ->
          IO.puts("AT Status Code: 403")
          IO.inspect(body)

        %HTTPoison.Response{status_code: 422, body: body} ->
          IO.puts("AT Status Code: 422")
          IO.inspect(body)

        %HTTPoison.Response{status_code: code, body: _body} ->
          IO.puts("AT Status Code: #{code}")
      end
    else
      {:error, error} ->
        {:error, error}
    end
  end

  # defp print(url, headers, body) do
  #  IO.inspect(url)
  #  IO.inspect(headers)
  #  IO.inspect(body)
  # end
end
