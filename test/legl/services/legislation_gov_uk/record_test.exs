# mix test test/legl/services/legislation_gov_uk/record_test.exs
# mix test test/legl/services/legislation_gov_uk/record_test.exs:10
defmodule Legl.Services.LegislationGovUk.RecordTest do

  use ExUnit.Case
  import Legl.Services.LegislationGovUk.Record

    @moduletag :legislation_gov_uk

    describe "Legl.Services.LegislationGovUk.Record.legislation/1" do
      test "prelims" do
        response = legislation(
          "/uksi/2016/547/introduction/made/data.xml")
        assert {:ok, :xml, md} = response
        IO.inspect(md)
      end
    end
end
