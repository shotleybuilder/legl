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


end
