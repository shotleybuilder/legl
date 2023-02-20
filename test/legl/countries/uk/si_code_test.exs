# mix test test/legl/countries/uk/si_code_test.exs
# mix test test/legl/countries/uk/si_code_test.exs:11

defmodule Lgl.Countries.Uk.SiCodeTest do

  use ExUnit.Case
  import Legl.Countries.Uk.SiCode

  @moduletag :uk

  describe "get_at_records_with_empty_si_code/1" do
    test "uk" do
      response = get_at_records_with_empty_si_code("UK E")
      assert {:ok, {json, records}} = response
      IO.inspect(records)
      IO.inspect(Enum.count(records))
    end
  end

  describe "get_si_code_from_legl_gov_uk/1" do
    test "using airtable data response" do
      records =
        [%{
          "createdTime" => "2023-02-16T14:38:14.000Z",
          "fields" => %{
            "Name" => "UK_2014_2_LAAA",
            "SI Code" => ["Empty"],
            "leg.gov.uk intro text" => "http://www.legislation.gov.uk/ukpga/2014/2/introduction/made"
          },
          "id" => "rec5r5LunOF4l6RF4"
        },
        %{
          "createdTime" => "2023-02-17T16:17:22.000Z",
          "fields" => %{
            "Name" => "UK_2008_373_PROPWARNI",
            "SI Code" => ["Empty"],
            "leg.gov.uk intro text" => "http://www.legislation.gov.uk/nisr/2008/373/introduction/made"
          },
          "id" => "rec5v3jwxYikGJXRQ"
        },
        %{
          "createdTime" => "2023-02-17T16:15:18.000Z",
          "fields" => %{
            "Name" => "UK_2014_117_CWDCARNI",
            "SI Code" => ["Empty"],
            "leg.gov.uk intro text" => "http://www.legislation.gov.uk/nisr/2014/117/introduction/made"
          },
          "id" => "rec5vHx2vQBLL6fZa"
        }]
        response = get_si_code_from_legl_gov_uk(records)
        assert {:ok, res} = response
        IO.inspect res
    end
  end

  describe "make_csv/1" do
    test "a dataset of 3 records" do
      records =
        [
          %{
            "createdTime" => "2023-02-16T14:38:14.000Z",
            "fields" => %{
              "Name" => "UK_2014_2_LAAA",
              "SI Code" => "",
              "leg.gov.uk intro text" => "http://www.legislation.gov.uk/ukpga/2014/2/introduction/made"
            },
            "id" => "rec5r5LunOF4l6RF4"
          },
          %{
            "createdTime" => "2023-02-17T16:17:22.000Z",
            "fields" => %{
              "Name" => "UK_2008_373_PROPWARNI",
              "SI Code" => "PUBLIC HEALTH",
              "leg.gov.uk intro text" => "http://www.legislation.gov.uk/nisr/2008/373/introduction/made"
            },
            "id" => "rec5v3jwxYikGJXRQ"
          },
          %{
            "createdTime" => "2023-02-17T16:15:18.000Z",
            "fields" => %{
              "Name" => "UK_2014_117_CWDCARNI",
              "SI Code" => "ENVIRONMENTAL PROTECTION",
              "leg.gov.uk intro text" => "http://www.legislation.gov.uk/nisr/2014/117/introduction/made"
            },
            "id" => "rec5vHx2vQBLL6fZa"
          }
        ]
      response = make_csv(records)
      assert {:ok, 3} = response
    end
  end

  describe "si_code_process/1" do
    test "uk e" do
      response = si_code_process("UK E")
      assert :ok = response
    end
  end

end
