defmodule Legl.Services.Airtable.Client do
  use HTTPoison.Base

  @endpoint "https://api.airtable.com/v0"

  def process_url(url) do
    @endpoint <> url
  end

  @timeout ~s(timeout: Sorry, there was a delay in getting the information from Airtable and the request has timed out.  Please try again!)

  def request(:get, url, headers) do
    # IO.puts("URL: #{url}")

    case get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: _code, body: body}} ->
        {:ok, body}

      {:error, %HTTPoison.Error{__exception__: _, id: _, reason: :timeout}} ->
        {:error, reason: @timeout}

      {:error, %HTTPoison.Error{__exception__: _exception, id: _id, reason: reason}} ->
        {:error, reason: "#{reason}"}
    end
  end

  def process_request_headers(headers) do
    [{:Authorization, "Bearer #{token()}"} | headers]
  end

  defp token(), do: System.get_env("AT_UK_E_API_KEY")
end
