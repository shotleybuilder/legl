defmodule Legl.Services.Supabase.SupabaseUrlTest do
  # mix test test/legl/services/supabase/test_supabase_url.exs:7

  use ExUnit.Case

  describe "single_record_url/2" do
    test "returns the correct URL" do
      table = "uk_lrt"
      name = "UK_uksi_2000_1"
      user = System.get_env("SUPABASE_USER")
      expected_url = ~s[https://#{user}.supabase.co/rest/v1/uk_lrt?name=eq.UK_uksi_2000_1]

      assert Legl.Services.Supabase.SupabaseUrl.single_record_url(table, name) == expected_url
    end
  end
end
