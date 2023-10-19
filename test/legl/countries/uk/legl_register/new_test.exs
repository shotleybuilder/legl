defmodule Legl.Countries.Uk.LeglRegister.NewTest do
  # mix test test/legl/countries/uk/legl_register/new_test.exs
  # mix test test/legl/countries/uk/legl_register/new_test.exs:11
  use ExUnit.Case
  alias Legl.Countries.Uk.LeglRegister.New.New
  alias Legl.Countries.Uk.LeglRegister.New.New.LegUkGov
  alias Legl.Countries.Uk.LeglRegister.New.New.Filters
  alias Legl.Countries.Uk.LeglRegister.New.Create

  @moduletag :uk

  @opts %{
    base_name: "UK S",
    year: 2023,
    month: 10,
    day: "12",
    days: {12, 13},
    type_code: [""]
  }

  describe "url/1" do
    test "url w/o type code" do
      url = LegUkGov.url(@opts)
      assert url == "/new/2023-10-12"
    end

    test "url w/ type code" do
      opts = Map.put(@opts, :type_code, "uksi")
      url = LegUkGov.url(opts)
      assert url == "/new/uksi/2023-10-12"
    end
  end

  describe "getNewLaws/1" do
    test "w/o type code" do
      response = New.getNewLaws(@opts)
      IO.inspect(response, limit: :infinity)
      assert {:ok, _response} = response
    end
  end

  @laws %{
    Number: "1234",
    "Publication Date": "2023-10-01",
    Title_EN: "Health and Safety Regulations",
    Year: 2023,
    txt: "foobar",
    type_code: "uksi"
  }

  describe "terms_filter/1" do
    test "w/ match" do
      result = Filters.terms_filter([@laws])

      assert result ==
               {[Map.put(@laws, :Family, "OH&S: Occupational / Personal Safety")], []}
    end
  end

  describe "run/1" do
    test "records from web" do
      assert :ok == New.run(@opts)
    end

    test "records from file" do
      assert :ok == New.run(Map.put(@opts, :source, :si_coded))
    end
  end

  @titles [
    "Motor Vehicles (Construction and Use) (Amendment) Regulations (Northern Ireland)",
    "Misuse of Drugs Act 1971 (Amendment) Order",
    "Parking Places (Disabled Persons’ Vehicles) (Amendment No. 6) Order (Northern Ireland)",
    "A47 North Tuddenham to Easton Development Consent (Correction) Order",
    "Inspectors of Education, Children’s Services and Skills (No. 3) Order"
  ]

  @geo_regions [
    "England,Wales,Northern Ireland,Scotland",
    "England,Wales",
    "England,Scotland",
    "Northern Ireland"
  ]

  describe "Legl.Countries.Uk.LeglRegister.New.Create" do
    test "tags" do
      result =
        Enum.map(@titles, fn title ->
          Create.tags(title)
        end)

      IO.inspect(result)
      assert is_list(result)
    end

    test "geo_pan_region/1" do
      result =
        Enum.map(@geo_regions, fn geo ->
          Create.geo_pan_region(geo)
        end)

      IO.inspect(result)
      assert is_list(result)
    end
  end
end
