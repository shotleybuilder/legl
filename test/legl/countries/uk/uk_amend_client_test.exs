# mix test test/legl/countries/uk/uk_amend_client_test.exs
# mix test test/legl/countries/uk/uk_amend_client_test.exs:8
defmodule Legl.Countries.Uk.UkAmendClientTest do
  use ExUnit.Case
  import Legl.Countries.Uk.UkAmendClient
  import Legl.Countries.Uk.UkAmend

  describe "get_next_set_of_records/2" do
    test "deletes the k,v pairs" do
      records = MapSet.new(
        [
          UK_uksi_2001_56_abc: [],
          UK_uksi_2002_57_abc: [],
          UK_uksi_2003_58_abc: [],
          UK_uksi_2004_59_abc: []
        ]
      )
      ids = MapSet.new([
        "UK_uksi_2001_56_abc",
        "UK_uksi_2004_59_abc"
      ])
      resp = get_next_set_of_records(records, ids)
      assert %MapSet{} = resp
      IO.inspect(resp)
    end

    test "real data" do
      ids = MapSet.new(["UK_uksi_2022_500_CJACSACR"])
      records =
        MapSet.new([
          UK_ukpga_2017_7_HSRLWMA: ["UK_ukpga_2017_7_HSRLWMA",
           "High Speed Rail (London - West Midlands) Act 2017", "/id/ukpga/2017/7",
           "ukpga", "2017", "7"],
          UK_uksi_2022_651_NREOLCRO: ["UK_uksi_2022_651_NREOLCRO",
           "The Network Rail (Essex and Others Level Crossing Reduction) Order 2022",
           "/id/uksi/2022/651", "uksi", "2022", "651"],
          UK_uksi_2020_1663_NRSLCRO: ["UK_uksi_2020_1663_NRSLCRO",
           "The Network Rail (Suffolk Level Crossing Reduction) Order 2020",
           "/id/uksi/2020/1663", "uksi", "2020", "1663"],
          UK_ukpga_2020_17_SA: ["UK_ukpga_2020_17_SA", "Sentencing Act 2020",
           "/id/ukpga/2020/17", "ukpga", "2020", "17"],
          UK_uksi_2022_500_CJACSACR: ["UK_uksi_2022_500_CJACSACR",
           "The Criminal Justice Act 2003 (Commencement No. 33) and Sentencing Act 2020 (Commencement No. 2) Regulations 2022",
           "/id/uksi/2022/500", "uksi", "2022", "500"],
          UK_uksi_2022_1406_NRCSIEO: ["UK_uksi_2022_1406_NRCSIEO",
           "The Network Rail (Cambridge South Infrastructure Enhancements) Order 2022",
           "/id/uksi/2022/1406", "uksi", "2022", "1406"],
          UK_uksi_2021_1414_NBOWFO: ["UK_uksi_2021_1414_NBOWFO"]
        ])

      resp = get_next_set_of_records(records, ids)
      assert %MapSet{} = resp
    end
  end

  @data [
    ["Scrap Metal Dealers Act 2013", "Finance Act 2021", "/id/ukpga/2021/26",
     "ukpga", "2021", "26", "Yes"],
    ["Scrap Metal Dealers Act 2013", "Finance Act 2021", "/id/ukpga/2021/26",
     "ukpga", "2021", "26", "Yes"],
    ["Scrap Metal Dealers Act 2013",
     "The Environmental Permitting (England and Wales) Regulations 2016",
     "/id/uksi/2016/1154", "uksi", "2016", "1154", "Yes"],
    ["Scrap Metal Dealers Act 2013",
     "The Scrap Metal Dealers Act 2013 (Commencement and Transitional Provisions) Order 2013",
     "/id/uksi/2013/1966", "uksi", "2013", "1966", "Yes"],
    ["Scrap Metal Dealers Act 2013",
     "The Scrap Metal Dealers Act 2013 (Commencement and Transitional Provisions) Order 2013",
     "/id/uksi/2013/1966", "uksi", "2013", "1966", "Yes"],
    ["Scrap Metal Dealers Act 2013",
     "The Scrap Metal Dealers Act 2013 (Commencement and Transitional Provisions) Order 2013",
     "/id/uksi/2013/1966", "uksi", "2013", "1966", "Yes"],
    ["Scrap Metal Dealers Act 2013",
     "The Scrap Metal Dealers Act 2013 (Commencement and Transitional Provisions) Order 2013",
     "/id/uksi/2013/1966", "uksi", "2013", "1966", "Yes"]
  ]

  describe "summary_amendment_stats/1" do
    test "uniq_by_amending_title/1" do
      resp = uniq_by_amending_title(@data)
      assert [
        [_, "Finance Act 2021", _, _, _, _, _],
        [_, _, _, "uksi", _, _, _],
        [_, _, _, _, _, "1966", _]
        ] = resp
    end

    test "amendment_ids/1" do
      resp = amendment_ids(@data)
      assert [
        "UK_ukpga_2021_26_FA",
        "UK_uksi_2016_1154_EPEWR",
        "UK_uksi_2013_1966_SMDACTPO"
        ] = resp
    end

    test "count_self_amendments/1" do
      resp = count_self_amendments(@data)
      assert 0 = resp
    end

    test "count_amendments/1" do
      resp = count_amendments(@data)
      assert 7 = resp
    end

    test "count_amending_laws/" do
      resp = count_amending_laws(@data)
      assert 3 = resp
    end

    test "count_amendments_for_each_law/1" do
      resp = count_amendments_for_each_law(
        amendment_ids(@data), @data
      )
      #|> IO.inspect()
      assert [
        {"UK_uksi_2013_1966_SMDACTPO", 4},
        {"UK_ukpga_2021_26_FA", 2},
        {"UK_uksi_2016_1154_EPEWR", 1}
      ] = resp
    end

    test "pre_uniq_summary_amendment_stats/1" do
      resp = pre_uniq_summary_amendment_stats(@data)
      assert %{} = resp
      assert 0 == resp.self
      assert nil == resp.laws
      assert 7 = resp.amendments
      assert "\"UK_uksi_2013_1966_SMDACTPO - 4💚️UK_ukpga_2021_26_FA - 2💚️UK_uksi_2016_1154_EPEWR - 1\""
    end

    #test "at_stats_amendments_count_per_law/1" do
    #  resp = at_stats_amendments_count_per_law(@data)
    #  assert "" = resp
    #end

  end

end
