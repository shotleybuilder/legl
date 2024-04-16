defmodule Legl.Services.Supabase.HttpTest do
  # mix test test/legl/services/supabase/http_test.exs
  use ExUnit.Case, async: true

  alias ElixirSense.Core.Struct
  alias Legl.Services.Supabase.Http

  @opts %{
    supabase_table: "uk_lrt"
  }

  test "token" do
    data = %{email: "foo@example.com", password: "bar"}
    opts = %{api: :auth, method: :post, data: data}

    Req.Test.stub(Http, fn conn ->
      conn
      |> Req.Test.json(%{access_token: "123", expires_in: 3600, user: %{id: "abc"}})

      # |> Plug.Conn.resp(200, ~s|"access_token": "123", "expires_in": 3600, "user": "id": "abc"|)
      # |> Plug.Conn.put_resp_content_type("application/json")
      # |> Plug.Conn.send_resp()
    end)

    assert %Req.Response{} = Http.request(opts)
  end

  test "get" do
    opts = Map.put(@opts, :method, :get)
    opts = Map.put(opts, :sql, "select*&limit=1")

    Req.Test.stub(Http, fn conn ->
      IO.inspect(conn.req_headers, label: "HEADERS")
      # IO.inspect(conn.req_url, label: "URL")
      Plug.Conn.send_resp(conn, 200, "OK")
    end)

    {:ok, result} = Http.request(opts)
    result = Map.from_struct(result)
    IO.inspect(result, label: "RESULT", limit: :infinity)
    print(result)
    # assert result == {:ok, %{status: 200, body: "UK_uksi_2000_1"}}
  end

  @record %{
    name: "UK_uksi_1900_XXXXX",
    type_code: "uksi",
    year: 1900,
    number: "XXXXX"
  }

  test "patch" do
    opts = Map.put(@opts, :method, :patch)
    opts = Map.put(opts, :data, @record)

    Req.Test.stub(Http, fn conn ->
      IO.inspect(conn.req_headers, label: "HEADERS")
      # IO.inspect(conn.req_url, label: "URL")
      Plug.Conn.send_resp(conn, 200, "OK")
    end)

    {:ok, result} = Http.request(opts)
    IO.inspect(result, label: "RESULT", limit: :infinity)
    # assert result == {:ok, %{status: 200, body: "UK_uksi_2000_1"}}
  end

  test "post" do
    opts = Map.put(@opts, :method, :post)
    opts = Map.put(opts, :data, @record)

    Req.Test.stub(Http, fn conn ->
      IO.inspect(conn.req_headers, label: "HEADERS")
      # IO.inspect(conn.req_url, label: "URL")
      Plug.Conn.send_resp(conn, 200, "OK")
    end)

    {:ok, result} = Http.request(opts)
    IO.inspect(result, label: "RESULT", limit: :infinity)
    # assert result == {:ok, %{status: 200, body: "UK_uksi_2000_1"}}
  end

  defp print(result) do
    Enum.each(result, fn {k, v} -> IO.puts(~s/#{k} #{inspect(v)}/) end)
  end
end
