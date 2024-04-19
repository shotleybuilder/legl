defmodule Legl.Services.Supabase.Http do
  @moduledoc """
  This module provides functions for making HTTP requests to the Supabase API.

  ## Functions

  - `get(url)`: Sends a GET request to the specified URL.
  - `patch(url, params)`: Sends a PATCH request to the specified URL with the given parameters.
  - `post(url, params)`: Sends a POST request to the specified URL with the given parameters.

  The base URL and headers used in the requests are determined by the `base_url/0` and `headers/0` private functions.

  """

  alias Legl.Services.Supabase.UrlRest
  alias Legl.Services.Supabase.UrlAuth

  def request(opts) do
    req_opts = req_opts(opts)

    Req.new(req_opts)
    |> Req.Request.append_request_steps(debug_url: debug_url(), debug_method: debug_method())
    |> Req.request()
  end

  def req_opts(opts) do
    with req_opts <- [{:base_url, base_url()} | []],
         req_opts <- url(req_opts, opts),
         req_opts <- [{:headers, headers(opts)} | req_opts],
         req_opts <- method(req_opts, opts),
         req_opts <-
           if(Map.has_key?(opts, :data), do: [{:json, opts.data} | req_opts], else: req_opts),

         # req_opts <- if(Map.has_key?(opts, :plug), do: [{:plug, opts.plug} | req_opts], else: req_opts),

         # SWITCH for testing sets the :plug option
         req_opts <-
           Keyword.merge(req_opts, Application.get_env(:legl, :supabase_http, [])) do
      # Only runs if the :plug option is set during testing
      if Keyword.has_key?(req_opts, :plug), do: IO.inspect(req_opts, label: "Request Options")

      req_opts
    end
  end

  defp url(req_opts, %{api: :auth} = opts), do: [{:url, UrlAuth.url(opts)} | req_opts]

  defp url(req_opts, %{api: :rest} = opts), do: [{:url, UrlRest.url(opts)} | req_opts]

  defp method(req_opts, %{method: method} = _opts) when method in [:patch, :post] do
    [{:method, method}, {:body, :iodata} | req_opts]
  end

  defp method(req_opts, _opts), do: [{:method, :get} | req_opts]

  defp base_url() do
    "https://#{System.get_env("SUPABASE_USER")}.supabase.co/"
  end

  defp debug_url,
    do: fn request ->
      IO.inspect(URI.to_string(request.url), label: "URL")
      request
    end

  defp debug_method,
    do: fn request ->
      IO.inspect(request.method, label: "METHOD")
      request
    end

  defp headers(%{api: :auth}) do
    [
      {:content_type, "application/json"},
      {:apikey, System.get_env("SUPABASE_KEY")}
    ]
  end

  defp headers(%{method: method, data: data})
       when is_map(data) and method in [:post, :patch] do
    headers(nil) ++
      [
        {:content_type, "application/json"},
        {:prefer, "return=minimal"}
      ]
  end

  defp headers(%{method: :post, data: data}) when is_list(data) do
    headers(nil) ++
      [
        {:content_type, "application/json"}
      ]
  end

  defp headers(_) do
    [
      {:accept, "application/json"},
      {:apikey, System.get_env("SUPABASE_KEY")},
      {:authorization, "Bearer #{Legl.Services.Supabase.UserCache.get_token()}"}
    ]
  end
end
