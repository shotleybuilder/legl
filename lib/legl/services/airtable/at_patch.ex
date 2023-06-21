defmodule Legl.Services.Airtable.AtPatch do
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  def patch_records(body, headers, params) do
    with(
      {:ok, url} <- Url.url(params.base, params.table, params.options),
      {:ok, _response} <- Client.patch(url, body, headers)
    ) do
      :ok
    else
      {:error, error} ->
        {:error, error}
    end
  end
end
