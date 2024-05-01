defmodule Legl.Services.Airtable.GetTest do
  # mix test test/legl/services/airtable/get_test.exs

  use ExUnit.Case, async: true
  import Legl.Services.Airtable.Get

  @base "appq5OQW9bTHC1zO5"
  @table "tbl6NZm9bLU2ijivf"

  test "get" do
    base = @base
    table = @table
    regulator_id = "4762430"
    params = %{formula: ~s/{id}="HSE_#{regulator_id}"/, fields: ["id"]}

    assert {:ok, _} = get(base, table, params)
  end

  describe "get_id/3" do
    test "record exists" do
      base = @base
      table = @table
      regulator_id = "4762430"
      params = %{formula: ~s/{id}="HSE_#{regulator_id}"/, fields: ["id"]}

      assert {:ok, _} = get_id(base, table, params)
    end

    test "record does not exist" do
      base = @base
      table = @table
      regulator_id = "1234567"
      params = %{formula: ~s/{id}="HSE_#{regulator_id}"/, fields: ["id"]}

      assert {:ok, nil} = get_id(base, table, params)
    end
  end
end
