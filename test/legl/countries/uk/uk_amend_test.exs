# mix test test/legl/countries/uk/uk_amend_test.exs
# mix test test/legl/countries/uk/uk_amend_test.exs:8
defmodule Legl.Countries.Uk.UkAmendTest do
  use ExUnit.Case
  import Legl.Countries.Uk.UkAmend

  #test will timeout
  describe "amendments_using_client/3" do
    test "real data and http call" do
      id = "UK_2013_10_SMDA"
      title = "abcd"
      path = "/changes/affected/ukpga/2013/10/data.xml?results-count=1000&sort=affecting-year-number"
      response = parse_amendments_using_client(id, title, path)
      assert is_list(response)
      IO.inspect(response)
    end
  end

  describe "get_next_set_of_records/2" do
    test "deletes the k,v pairs" do
      records =
        [
          UK_uksi_2001_56_abc: [],
          UK_uksi_2002_57_abc: [],
          UK_uksi_2003_58_abc: [],
          UK_uksi_2004_59_abc: []
        ]
      ids = MapSet.new([
        "UK_uksi_2001_56_abc",
        "UK_uksi_2004_59_abc"
      ])
      resp = get_next_set_of_records(records, ids)
      assert [{:UK_uksi_2002_57_abc, []}, {:UK_uksi_2003_58_abc, []}]
      = resp
    end
  end
end
