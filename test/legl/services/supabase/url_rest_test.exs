defmodule Legl.Services.Supabase.UrlRestTest do
  # mix test test/legl/services/supabase/url_rest_test.exs:7

  use ExUnit.Case
  alias Legl.Services.Supabase.UrlRest

  describe "single_record_url/2" do
    test "returns the correct URL" do
      table = "uk_lrt"
      name = "UK_uksi_2000_1"

      opts = %{table: table, name: name}

      expected_url = ~s[?name=eq.UK_uksi_2000_1]

      assert UrlRest.url(opts) == expected_url
    end

    test "returns the correct URL with a list of names" do
      table = "uk_lrt"
      name = ["UK_uksi_2000_1", "UK_uksi_2000_2"]

      opts = %{table: table, name: name}

      expected_url = ~s[?name=in.(UK_uksi_2000_1,UK_uksi_2000_2)]

      assert UrlRest.url(opts) == expected_url
    end

    test "returns the correct URL with a list of names and a column" do
      table = "uk_lrt"
      name = ["UK_uksi_2000_1", "UK_uksi_2000_2"]
      column = "name"

      opts = %{table: table, name: name, column: column}

      expected_url = ~s[?name=in.(UK_uksi_2000_1,UK_uksi_2000_2)]

      assert UrlRest.url(opts) == expected_url
    end
  end
end
