defmodule Legl.Services.Supabase.UserCache do
  require Logger

  @table_name :user_cache
  @user_id System.get_env("SUPABASE_USER_ID")

  def start_link do
    case :ets.whereis(@table_name) do
      :undefined -> :ets.new(@table_name, [:set, :protected, :named_table])
      _ -> :ok
    end
  end

  @doc """
  Puts a token into the user cache.

  ## Examples

      iex> UserCache.put_token(123, "abc123")
      "abc123"

  ## Parameters

    * `user_id` - The ID of the user.
    * `token` - The token to be stored in the cache.
    * `opts` (optional) - Additional options for the cache entry.
      * `:ttl` - The time-to-live (in seconds) for the cache entry. Defaults to 3600 seconds.

  ## Returns

  The token that was inserted into the cache.

  """
  def put_token(user_id, token, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 3600)
    expiration = :os.system_time(:seconds) + ttl
    record = :ets.insert(@table_name, {user_id, token, expiration})
    Logger.info("\nPut token successful: #{inspect(record)}")
  end

  @doc """
  Lookup a cached result and check the freshness
  """
  def get_token() do
    user_id = user_id() |> IO.inspect(label: "USER_ID")
    value = :ets.lookup(@table_name, user_id)

    case value do
      [result | _] -> check_freshness(result)
      [] -> nil
    end
  end

  def remove_token() do
    :ets.delete(@table_name, user_id())
  end

  defp check_freshness({_, token, expiration}) do
    cond do
      expiration > :os.system_time(:seconds) ->
        token

      :else ->
        remove_token()
        nil
    end
  end

  defp user_id() do
    case @user_id do
      x when x in ["", nil] -> raise "SUPABASE_USER_ID is not set"
      user_id when not is_nil(user_id) and is_binary(user_id) -> user_id
    end
  end
end
