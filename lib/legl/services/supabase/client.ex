defmodule Legl.Services.Supabase.Client do
  require Logger
  alias Legl.Services.Supabase.Http
  alias Legl.Services.Supabase.UserCache

  def token?() do
    UserCache.start_link()

    case UserCache.get_token() do
      nil -> false
      _ -> true
    end
  end

  def refresh_token() do
    # Refresh the JWT token
    data = %{
      email: System.get_env("SUPABASE_EMAIL"),
      password: System.get_env("SUPABASE_PASSWORD")
    }

    %{method: :post, api: :auth, data: data}
    |> Http.request()
    |> handle_response()
  end

  def find_or_create_legal_register_record(opts) do
    case get_legal_register_record(opts) do
      {:ok, body} -> {:ok, body}
      {:error, _} -> create_legal_register_record(opts)
    end
  end

  def get_legal_register_record(opts) do
    if token?() == false, do: refresh_token()
    opts = Map.put(opts, :api, :rest)
    opts = Map.put_new(opts, :supabase_table, "uk_lrt")

    case handle_response(Http.request(opts)) do
      {:ok, %{user_id: _user_id, token: _token}} -> get_legal_register_record(opts)
      resp -> resp
    end
  end

  def create_legal_register_record(opts) do
    opts = Map.merge(opts, %{method: :post, api: :rest})
    opts = Map.put_new(opts, :supabase_table, "uk_lrt")

    case handle_response(Http.request(opts)) do
      {:ok, %{user_id: _user_id, token: _token}} -> create_legal_register_record(opts)
      resp -> resp
    end
  end

  def update_legal_register_record(opts) do
    opts = Map.merge(opts, %{method: :patch, api: :rest})
    opts = Map.put_new(opts, :supabase_table, "uk_lrt")

    case handle_response(Http.request(opts)) do
      {:ok, %{user_id: _user_id, token: _token}} -> update_legal_register_record(opts)
      resp -> resp
    end
  end

  defp handle_response(resp) do
    case resp do
      {:ok,
       %{
         status: 200,
         body: %{
           "access_token" => token,
           "expires_in" => ttl,
           "user" => %{"id" => user_id} = body
         }
       }} ->
        Logger.info("\nToken request successful: #{inspect(body)}")
        Legl.Services.Supabase.UserCache.start_link()
        Legl.Services.Supabase.UserCache.put_token(user_id, token, ttl: ttl)

        {:ok, %{user_id: user_id, token: token}}

      {:ok, %{status: 200, body: body}} ->
        Logger.info("Request successful: #{inspect(body)}")
        {:ok, body}

      {:ok, %{status: 201, body: body}} ->
        Logger.info("Request successful: #{inspect(body)}")
        {:ok, body}

      {:ok, %{status: 204, body: _}} ->
        Logger.info("Request successful: No content")
        {:ok, %{}}

      {:ok, %{status: 401, body: %{"code" => "PGRST301", "message" => "JWT expired"} = body}} ->
        Logger.info("JWT Expired: #{inspect(body)}")
        refresh_token()

      {:ok, %{status: status_code, body: body}} ->
        Logger.error("Request failed with status code #{status_code}: #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
