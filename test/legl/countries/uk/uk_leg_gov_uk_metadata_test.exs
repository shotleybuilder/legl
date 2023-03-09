# mix test test/legl/countries/uk/uk_leg_gov_uk_metadata_test.exs:25

defmodule Legl.Countries.Uk.UkLegGovUkMetadataTest do
  use ExUnit.Case
  import Legl.Countries.Uk.UkLegGovUkMetadata


  describe "get from legislation.gov.uk" do
    test "get_properties_from_legislation_gov_uk/1" do
      url =
        "/uksi/2000/1562/introduction/made/data.xml"
      resp = get_properties_from_legislation_gov_uk(url)
      assert {:ok, %{
        md_total_paras: 254,
        md_modified: "10/01/2017"
      }} = resp

    end
  end

  @data [
    %{"createdTime" => "2023-03-07T17:36:46.000Z",
    "fields" =>
      %{
        "Name" => "UK_ukpga_1993_49_PSNIA",
        "Title_EN" => "Pension Schemes (Northern Ireland) Act",
        "leg.gov.uk intro text" =>
        "http://www.legislation.gov.uk/ukpga/1993/49/introduction/made/data.xml"
      },
      "id" => "recdrnyr6JrnsKKdN"
    },
    %{"createdTime" => "2023-03-07T17:36:46.000Z",
    "fields" =>
      %{
        "Name" => "UK_ukpga_1994_18_SSIWA",
        "Title_EN" => "Social Security (Incapacity for Work) Act",
        "leg.gov.uk intro text" =>
        "http://www.legislation.gov.uk/ukpga/1994/18/introduction/made/data.xml"
      },
      "id" => "recEbdcpzVxCUOqrD"
    }
  ]

  describe "make the csv" do

    test "csv_header_row/0" do
      resp = csv_header_row()
      assert :ok = resp
    end

    test "enumerate_at_records/1" do
      resp = enumerate_at_records(@data)
      assert {:ok, "metadata properties saved to csv"} = resp
    end
  end

end
