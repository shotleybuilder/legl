defmodule Legl.Countries.Uk.LeglRegister.ExtentTest do
  # mix test test/legl/countries/uk/legl_register/extent_test.exs:8
  use ExUnit.Case

  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR
  alias Legl.Countries.Uk.LeglRegister.Extent

  setup_all do
    name = ExPrompt.get("Name of Law to Test")

    ["UK", type_code, year, number] = String.split(name, "_")

    record =
      Map.merge(%LR{}, %{type_code: type_code, Year: String.to_integer(year), Number: number})

    {:ok, data} = Extent.get_extent_leg_gov_uk(record) |> IO.inspect(label: "DATA")
    {:ok, %{data: data}}
  end

  test "context", context do
    IO.inspect(context, label: "CONTEXT")
  end

  test "clean_data/1", %{data: data} do
    result = Extent.clean_data(data)
    IO.inspect(result, label: "CLEANED DATA")
  end

  test "uniq_extent/1", %{data: data} do
    Extent.clean_data(data)
    |> Extent.uniq_extent()
    |> IO.inspect(label: "UNIQ")
  end

  test "geo_extent/2", %{data: data} do
    Extent.clean_data(data)
    |> Extent.uniq_extent()
    |> (&Extent.geo_extent(data, &1)).()
    |> IO.inspect()
  end

  test "geo_region/1", %{data: data} do
    Extent.clean_data(data)
    |> Extent.uniq_extent()
    |> Extent.geo_region()
    |> IO.inspect(label: "GEO")
    |> Extent.ordered_regions()
    |> IO.inspect(label: "ORDERED")
  end

  test "extent_transformation/1", %{data: data} do
    {:ok, result} = Extent.extent_transformation(data)
    IO.inspect(result)
  end

  test "ordered_regions/1" do
    regions = [
      "England",
      "Wales",
      "Northern Ireland",
      "Scotland"
    ]

    result = Extent.ordered_regions(regions)

    assert result == [
             "England",
             "Wales",
             "Scotland",
             "Northern Ireland"
           ]
  end
end
