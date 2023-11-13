defmodule Legl.Utility.Test do
  # mix test test/utility/utility_test.exs:7
  use ExUnit.Case
  import Utility.RangeCalc
  alias Legl.Utility, as: U

  describe "range/1" do
    test "pattern \d+[A-Z][A-Z]" do
      data = [
        {"25", "27"},
        {"25", "", "27", ""},
        {"25", "", "25", "E"},
        {"25", "B", "25", "D"},
        {"123F", "A", "D"},
        {"105Z", "A", "I"},
        {"27", "H", "K"},
        {"19", nil, "25", "D"},
        {"24", "A", "26", "A"}
      ]

      result = Enum.map(data, fn x -> Utility.RangeCalc.range(x) end)

      model = [
        ["25", "26", "27"],
        ["25", "26", "27"],
        ["25", "25A", "25B", "25C", "25D", "25E"],
        ["25B", "25C", "25D", "25"],
        ["123FA", "123FB", "123FC", "123FD", "123F"],
        ["105ZA", "105ZB", "105ZC", "105ZD", "105ZE", "105ZF", "105ZG", "105ZH", "105ZI", "105Z"],
        ["27H", "27I", "27J", "27K", "27"],
        ["19", "20", "21", "22", "23", "24", "25", "25A", "25B", "25C", "25D"],
        [
          "24A",
          "24B",
          "24C",
          "24D",
          "24E",
          "24F",
          "24G",
          "24H",
          "24I",
          "24J",
          "24K",
          "24L",
          "24M",
          "24N",
          "24O",
          "24P",
          "24Q",
          "24R",
          "24S",
          "24T",
          "24U",
          "24V",
          "24W",
          "24X",
          "24Y",
          "24Z",
          "24",
          "25A",
          "25B",
          "25C",
          "25D",
          "25E",
          "25F",
          "25G",
          "25H",
          "25I",
          "25J",
          "25K",
          "25L",
          "25M",
          "25N",
          "25O",
          "25P",
          "25Q",
          "25R",
          "25S",
          "25T",
          "25U",
          "25V",
          "25W",
          "25X",
          "25Y",
          "25Z",
          "25",
          "26A",
          "26"
        ]
      ]

      assert model == result
    end
  end

  describe "convert_to_mapset/1" do
    test "string" do
      result = U.convert_to_mapset([""])
      assert %MapSet{} = result
    end
  end

  describe "delta_lists/2" do
    test "delta_lists - matching" do
      old = ["foo"]
      new = ["foo"]
      result = U.delta_lists(old, new)
      assert [] = result
    end

    test "delta_lists - difference" do
      old = ["foo"]
      new = ["foo", "bar"]
      result = U.delta_lists(old, new)
      assert ["bar"] = result
    end

    test "delta_lists - real data" do
      master = [
        "UK_uksi_2016_1142_IIFASDESACPMO",
        "UK_asp_2016_2_IIFASDESA",
        "UK_uksi_2015_374_RRSACMO",
        "UK_uksi_2014_3248_MR",
        "UK_uksi_2013_448_HSMRRAR",
        "UK_ukpga_2008_32_EA",
        "UK_ukpga_2008_20_HSOA",
        "UK_ssi_2006_475_FSACMSO",
        "UK_ukpga_2006_48_PJA",
        "UK_uksi_2005_1541_RRFSO",
        "UK_uksi_2005_1082_MSER",
        "UK_ukpga_2005_14_RA",
        "UK_ukpga_2004_17_HPAA",
        "UK_ukpga_2003_22_FA",
        "UK_asp_2003_8_BSA",
        "UK_uksi_2002_794_MAFFDO",
        "UK_uksi_1996_1513_HSCER",
        "UK_ukpga_1995_25_EA",
        "UK_ukpga_1995_17_HAA",
        "UK_ukpga_1994_19_LGWA"
      ]

      copy = [
        "UK_uksi_2016_1142_IIFASDESACPMO",
        "UK_asp_2016_2_IIFASDESA",
        "UK_uksi_2015_374_RRSACMO",
        "UK_uksi_2014_3248_MR",
        "UK_uksi_2013_448_HSMRRAR",
        "UK_ukpga_2008_32_EA",
        "UK_ukpga_2008_20_HSOA",
        "UK_ssi_2006_475_FSACMSO",
        "UK_ukpga_2006_48_PJA",
        "UK_uksi_2005_1541_RRFSO",
        "UK_uksi_2005_1082_MSER",
        "UK_ukpga_2005_14_RA",
        "UK_ukpga_2004_17_HPAA",
        "UK_asp_2003_8_BSA",
        "UK_uksi_2002_794_MAFFDO",
        "UK_uksi_1996_1513_HSCER",
        "UK_ukpga_1995_25_EA",
        "UK_ukpga_1995_17_HAA",
        "UK_ukpga_1994_19_LGWA"
      ]

      IO.puts("master: #{Enum.count(master)} copy: #{Enum.count(copy)}")
      result = U.delta_lists(copy, master)
      IO.puts("Result #{Enum.count(result)}")
      assert is_list(result)
      assert result == ["UK_ukpga_2003_22_FA"]
    end
  end
end
