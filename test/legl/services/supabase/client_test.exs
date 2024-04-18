defmodule Legl.Services.Supabase.ClientTest do
  # mix test test/legl/services/supabase/client_test.exs:5

  use ExUnit.Case

  alias Legl.Services.Supabase

  @name "UK_uksi_2000_1"
  @user_id System.get_env("SUPABASE_USER_ID")

  describe "refesh_token/1" do
    test "token" do
      Req.Test.stub(Supabase.Http, fn conn ->
        conn
        |> Req.Test.json(%{access_token: "123", expires_in: 3600, user: %{id: "#{@user_id}"}})
      end)

      assert "123" = Supabase.Client.refresh_token()

      assert is_reference(:ets.whereis(:user_cache))
      assert Supabase.UserCache.start_link() == :ok
      assert {:ok, %{user_id: user_id, token: token}} = Supabase.UserCache.get_token()
    end
  end

  setup do
    Legl.Services.Supabase.UserCache.start_link()
    Legl.Services.Supabase.UserCache.put_token(@user_id, "12345", ttl: 3600)
    :ok
  end

  describe "get_record/1" do
    test "returns the body when the GET request is successful" do
      # Arrange
      params = %{"table" => "uk_lrt", "name" => @name, api: :rest}

      Req.Test.stub(Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(201, "")
        |> Plug.Conn.send_resp()
      end)

      # Act
      result = Supabase.Client.get_legal_register_record(params)

      # Assert
      assert {:ok, ""} == result
    end

    test "returns an error when the GET request fails with a status code" do
      # Arrange
      params = %{"table" => "uk_lrt", "name" => @name, api: :rest}

      Req.Test.stub(Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(400, "Record not found")
        |> Plug.Conn.send_resp()
      end)

      # Act
      result = Supabase.Client.get_legal_register_record(params)

      # Assert
      assert {:error, "Record not found"} == result
    end

    test "returns an error when the GET request encounters an error" do
      # Arrange
      params = %{"table" => "uk_lrt", "name" => @name, api: :rest}

      Req.Test.stub(Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(500, "connection_failed")
        |> Plug.Conn.send_resp()
      end)

      # Act
      result = Supabase.Client.get_legal_register_record(params)

      # Assert
      assert {:error, "connection_failed"} == result
    end
  end
end
