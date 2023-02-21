# mix test test/legl/services/legislation_gov_uk/record_test.exs
# mix test test/legl/services/legislation_gov_uk/record_test.exs:10
defmodule Legl.Services.LegislationGovUk.RecordTest do

  use ExUnit.Case
  import Legl.Services.LegislationGovUk.Record

    @moduletag :legislation_gov_uk

    describe "Legl.Services.LegislationGovUk.Record.legislation/1" do
      test "metadata" do
        response = legislation(
          "/uksi/2016/547/introduction/made/data.xml")
        assert {:ok, :xml, md} = response
        IO.inspect(md)
      end
    end


    describe "Legl.Services.LegislationGovUk.Record.amendments_table/1" do
      test "amendments" do
        response = amendments_table(
          "/changes/affected/ukpga/2013/10/data.xml?results-count=1000&sort=affecting-year-number"
        )
        assert {:ok, _} = response
        IO.inspect response
      end
    end
end
