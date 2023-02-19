# mix test test/legl/services/airtable/airtable_bases_test.exs
# mix test test/legl/services/airtable/airtable_bases_test.exs:7
defmodule Legl.Services.Airtable.AirtableBasesTest do
  use ExUnit.Case
  import Legl.Services.Airtable.ATBases

  describe "get_base_id/1" do
    test "UK E" do
      response = get_base_id("UK E")
      assert {:ok, "appLrnYgsmHOdRUhw"} = response
    end
    test "base id" do
      response = get_base_id("appLrnYgsmHOdRUhw")
      assert {:ok, "appLrnYgsmHOdRUhw"} = response
    end
    test "UK E Climate Change" do
      response = get_base_id("UK E Climate Change")
      assert {:ok, "appGv6qmDJK2Kdr3U"} = response
    end
  end
end
