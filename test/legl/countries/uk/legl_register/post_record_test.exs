defmodule Legl.Countries.Uk.LeglRegister.PostRecordTest do
  # mix test test/legl/countries/uk/legl_register/post_record_test.exs
  use ExUnit.Case, async: true
  # import Mox
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.PostRecord, as: Post

  describe "supabase_post_record/2" do
    test "creates a legal register record" do
      record = %{name: "UK_uksi_2000_1", type_code: "uksi", year: 2000, number: "1"}
      opts = %{}

      Req.Test.stub(Legl.Services.Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(201, "ok")
        |> Plug.Conn.send_resp()
      end)

      assert Post.supabase_post_record(record, opts) == :ok
    end

    test "wrong content type" do
      record = %{name: "UK_uksi_2000_1", type_code: "uksi", year: 2000, number: "1"}
      opts = %{}

      Req.Test.stub(Legl.Services.Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(
          400,
          ~s|{"code": "PGRST301", "details": null, "hint": null, "message": "Content-Type not acceptable: text/plain"}|
        )
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp()
      end)

      assert {:error, %{"code" => "PGRST301"}} = Post.supabase_post_record(record, opts)
    end

    test "jwt expired" do
      record = %{name: "UK_uksi_2000_1", type_code: "uksi", year: 2000, number: "1"}
      opts = %{}

      Req.Test.stub(Legl.Services.Supabase.Http, fn conn ->
        conn
        |> Plug.Conn.resp(
          401,
          ~s/{"code": "PGRST301", "details": null, "hint": null, "message": "JWT expired"}/
        )
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp()
      end)

      assert {:error, %{"message" => "JWT expired"}} = Post.supabase_post_record(record, opts)
    end
  end
end
