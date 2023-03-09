# mix test test/legl/countries/uk/uk_extent_test.exs:20

defmodule Legl.Countries.Uk.UkExtentTest do

  use ExUnit.Case
  import Legl.Countries.Uk.UkExtent


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
