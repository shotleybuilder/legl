# mix test test/legl/countries/uk/uk_extent_test.exs:20

defmodule Legl.Countries.Uk.UkExtentTest do

  use ExUnit.Case
  import Legl.Countries.Uk.UkExtent

  describe "persist data for at upload" do
    test "make_csv_workflow" do
      resp = make_csv_workflow("test", "/ukpga/2023/1/contents/data.xml")
      assert :ok = resp
    end
  end

  describe "get a leg_gov_uk record" do
    test "get_extent_leg_gov_uk/1" do
      url =  "/ukpga/2023/1/contents/data.xml"
      {:ok, resp} = get_extent_leg_gov_uk(url)
      assert {"section-1", "E+W+S+NI"} = List.first(resp)
    end
  end

  @data [
    {"section-1", "E+W+S+NI"},
    {"section-2", "E+W+S+NI"},
    {"section-3", "E+W+S+NI"},
    {"section-4", "E+W+S"},
    {"section-5", "NI"},
    {"section-6", "E+W"},
    {"section-7", "E+W"}
  ]

  describe "transforming the records" do
    test "uniq_extent" do
      resp = uniq_extent(@data)
      assert [
        "E+W+S+NI",
        "E+W+S",
        "E+W",
        "NI"
      ] = resp
    end
    test "create_map/1" do
      resp = uniq_extent(@data) |> create_map()
      assert %{
        "E+W+S+NI" => [],
        "E+W+S" => [],
        "E+W" => [],
        "NI" => []
      } = resp
    end
    test "extent_transformation" do
      resp = extent_transformation(@data)
      assert %{
        geo_extent: "E+W+S+NI\nsection-1, section-2, section-3\nE+W+S\nsection-4\nE+W\nsection-6, section-7\nNI\nsection-5\n",
        geo_region: "\"Northern Ireland,England,Wales,Scotland,Northern Ireland\""
      } = resp
    end
  end

  @data_wales [
    {"section-1", "W"},
    {"section-2", "W"},
    {"section-3", "W"},
    {"section-4", "W"},
    {"section-5", "W"},
    {"section-6", "W"},
    {"section-7", "W"},
    {"section-8", "W"},
    {"section-9", "W"},
    {"section-10", "W"},
    {"section-11", "W"},
    {"section-12", "W"},
    {"section-13", "W"},
    {"section-14", "W"},
    {"section-15", "W"},
    {"section-16", "W"},
    {"section-17", "W"},
    {"section-17A", "W"},
    {"section-18", "W"},
    {"section-19", "W"},
    {"section-20", "W"},
    {"section-21", "W"},
    {"section-22", "W"},
    {"schedule-paragraph-1", "W"},
    {"schedule-paragraph-2", "W"}
  ]

  describe "w transforming the records" do
    test "w uniq_extent" do
      resp = uniq_extent(@data_wales)
      assert [
        "W"
      ] = resp
    end
    test "w create_map/1" do
      resp = uniq_extent(@data_wales) |> create_map()
      assert %{
        "W" => []
      } = resp
    end
    test "w regions/1" do
      resp = uniq_extent(@data_wales) |> regions()
      assert is_bitstring(resp)
    end
    test "w emoji_flags/1" do
      resp = emoji_flags("W")
      res = Legl.wales_flag_emoji()<>" W"
      assert res = resp
    end
    test "w extent_transformation" do
      resp = extent_transformation(@data_wales)
      assert {:ok, %{geo_extent: "\"W💚️All provisions\"", geo_region: "\"Wales\""}} = resp
    end
  end


end
