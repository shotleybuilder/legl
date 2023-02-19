# mix test test/legl/services/airtable/records_test.exs
# mix test test/legl/services/airtable/records_test.exs:14

defmodule Legl.Services.Airtable.RecordsTest do
  use ExUnit.Case
  import Legl.Services.Airtable.Records
  import Legl.Services.Airtable.AirtableParams

  @moduletag :airtable

  #@json_file Path.absname( "../../sgre_hse_plan_web/controllers/factory/hse_plan.json", __DIR__ )

  describe "run/1" do
    test "base & plan" do
      params = %{"base_name" => "UK E", "table_name" => "UK"}
      response = run(params)
      assert {:ok, _} = response
    end
  end

  describe "params_validation/1" do
    test "no base" do
      params = %{"plan" => "foobar"}
      assert params_validation(params) ==  {:error, "No base name given. URL should contain the base id number."}
    end
    test "wrong base" do
      params = %{"base" => "foobar", "plan" => "foobar"}
      assert params_validation(params) ==  {:error, "Not a valid Airtable base id number."}
    end
    test "no plan" do
      params = %{"base" => "appfoobar"}
      assert params_validation(params) ==  {:error, "No HSE plan name given. URL should contain: plan=[plan name]. Note: this is the name of the Airtable table"}
    end
    test "no sector" do
      params = %{"base" => "appfoobar", "plan" => "foobar"}
      assert params_validation(params) == :ok
    end
    test "wrong sector" do
      params = %{"base" => "appfoobar", "plan" => "foobar", "sector" => "ox"}
      assert params_validation(params) ==  {:error, ~s(Sector is optional and defaults to onshore. URL should contain: sector=offshore or sector=onshore. Note: anything beginning "on" or "off" will work. You used **#{params["sector"]}**)}
    end
    test "with sector" do
      params = %{"base" => "appfoobar", "plan" => "foobar", "sector" => "on"}
      assert params_validation(params) == :ok
    end
  end

  describe "params_defaults/1" do
    test "no sector and media" do
      params = %{ "base" => "appfoobar", "plan" => "foobar"}
      {:ok, result } = params_defaults(params)
      assert result.base == "appfoobar"
      assert result.plan == "foobar"
      assert result.sector == "on"
      assert result.media == "json"
      assert result.env == :test
    end
    test "sector = oo" do
      params = %{ "base" => "appfoobar", "plan" => "foobar", "sector" => "oo"}
      {:ok, result } = params_defaults(params)
      assert result.sector == "on"
    end
    test "sector = on" do
      params = %{ "base" => "appfoobar", "plan" => "foobar", "sector" => "on"}
      {:ok, result } = params_defaults(params)
      assert result.sector == "on"
    end
    test "sector = of" do
      params = %{ "base" => "appfoobar", "plan" => "foobar", "sector" => "of"}
      {:ok, result } = params_defaults(params)
      assert result.sector == "off"
    end
  end


end
