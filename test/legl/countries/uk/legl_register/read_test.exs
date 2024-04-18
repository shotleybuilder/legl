defmodule Legl.Countries.Uk.LeglRegister.ReadTest do
  # mix test test/legl/countries/uk/legl_register/read_test.exs

  use ExUnit.Case, async: true

  alias Legl.Services.Supabase
  alias Legl.Services.Supabase.UserCache
  alias Legl.Countries.Uk.LeglRegister.Crud.Read

  setup_all do
    UserCache.start_link()
    UserCache.put_token(System.get_env("SUPABASE_USER_ID"), "fake_token", ttl: 3600)
  end

  # LIVE TESTS - these tests require a live connection to the database

  describe "exists_pg?/1" do
    test "returns true if record exists" do
      opts = %{
        supabase_table: "uk_lrt",
        name: "UK_ukpga_1974_32",
        api: :rest
      }

      Req.Test.stub(Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(200, "")
        |> Plug.Conn.send_resp()
      end)

      assert Read.exists_pg?(opts)
    end

    test "returns false if record does not exist" do
      opts = %{
        supabase_table: "uk_lrt",
        name: "UK_uksi_1000_1",
        api: :rest
      }

      Req.Test.stub(Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(401, "No record found")
        |> Plug.Conn.send_resp()
      end)

      refute Read.exists_pg?(opts)
    end
  end
end
