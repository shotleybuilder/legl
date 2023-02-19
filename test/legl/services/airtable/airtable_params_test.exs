# mix test test/legl/services/airtable/airtable_params_test.exs
# mix test test/legl/services/airtable/airtable_params_test.exs:8
defmodule Legl.Services.Airtable.AirtableParamsTest do
  use ExUnit.Case
  import Legl.Services.Airtable.AirtableParams

  describe "params_validation/1" do
    test "base name and table name" do
      response = params_validation(
        %{"base_name" => "UK E", "table_name" => "UK"}
        )
      assert {:ok,  %{"base" => "appLrnYgsmHOdRUhw", "table" => "tblJW0DMpRs74CJux"}} = response
    end
  end

  describe "params_defaults/1" do
    test "" do
      response = params_defaults(
        %{"base" => "appLrnYgsmHOdRUhw", "table" => "tblJW0DMpRs74CJux"}
        )
      assert {:ok, %{}} = response
    end
  end
end
