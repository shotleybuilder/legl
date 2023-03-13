# mix test test/legl/services/legislation_gov_uk/record_test.exs
# mix test test/legl/services/legislation_gov_uk/record_test.exs:10
defmodule Legl.Services.LegislationGovUk.RecordTest do

  use ExUnit.Case
  import Legl.Services.LegislationGovUk.Record
  import Legl.Services.LegislationGovUk.RecordGeneric

    @moduletag :legislation_gov_uk

    describe "Legl.Services.LegislationGovUk.Record.legislation/1" do
      test "metadata" do
        response = legislation(
          "/uksi/2000/1562/introduction/made/data.xml")
        assert {:ok, :xml, md} = response
        IO.inspect(md)
      end
    end

    describe "Legl.Services.LegislationGovUk.Record.amendments_table/1" do
      test "amendments" do
        response = amendments_table(
          "/changes/affected/ukpga/2013/10/data.xml?results-count=1000&sort=affecting-year-number"
        )
        assert is_list(response)
      end
    end

    describe "applied/1" do
      test "records with unapplied changes" do
        records = [
          ~w[title amending_title path type year number yes],
          ~w[title amending_title path type year number no],
          ~w[title amending_title path type year number see_note],
          ~w[title amending_title2 path type year number yes],
          ~w[title amending_title3 path type year number yes],
          ~w[title amending_title3 path type year number no]
        ]
        resp = applied(records)
        assert is_list(resp)
        IO.inspect(resp)
      end
    end



end
