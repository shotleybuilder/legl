defmodule Legl.Services.Supabase.Client do
  require Logger
  alias Legl.Services.Supabase.Http

  def refresh_token(opts) do
    # Refresh the JWT token
    data = %{
      email: System.get_env("SUPABASE_EMAIL"),
      password: System.get_env("SUPABASE_PASSWORD")
    }

    opts
    |> Map.merge(%{method: :post, api: :auth, data: data})
    |> request()
  end

  def find_or_create_legal_register_record(opts) do
    case get_legal_register_record(opts) do
      {:ok, body} -> {:ok, body}
      {:error, _} -> create_legal_register_record(opts)
    end
  end

  def get_legal_register_record(opts) do
    request(opts)
  end

  def create_legal_register_record(opts) do
    opts
    |> Map.put(:method, :post)
    |> request()
  end

  def update_legal_register_record(opts) do
    opts
    |> Map.put(:method, :patch)
    |> request()
  end

  defp request(opts) do
    Http.request(opts)
    |> handle_response()
  end

  defp handle_response(resp) do
    case resp do
      {:ok,
       %{
         status: 200,
         body: %{"access_token" => token, "expires_in" => ttl, "user" => %{"id" => user_id}}
       }} ->
        Legl.Services.Supabase.UserCache.start_link()
        Legl.Services.Supabase.UserCache.put_token(user_id, token, ttl: ttl)

      {:ok, %{status: 200, body: body}} ->
        Logger.info("Request successful: #{inspect(body)}")
        :ok

      {:ok, %{status: 201, body: body}} ->
        Logger.info("Request successful: #{inspect(body)}")
        {:ok, body}

      {:ok, %{status: 401, body: %{"code" => "PGRST301", "message" => "JWT expired"} = body}} ->
        Logger.info("JWT Expired: #{inspect(body)}")
        {:error, :jwt_expired}

      {:ok, %{status: status_code, body: body}} ->
        Logger.error("Request failed with status code #{status_code}: #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
