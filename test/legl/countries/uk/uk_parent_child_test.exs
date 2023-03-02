# mix test test/legl/countries/uk/uk_parent_child_test.exs:7

defmodule Legl.Countries.Uk.UkParentChildTest do
  use ExUnit.Case
  import Legl.Countries.Uk.UkParentChild

  @doc """

    RETURN
    [
      %{
        "createdTime" => "2023-02-26T20:03:57.000Z",
        "fields" => %{
          "Name" => "UK_ukla_1995_1_BWA",
          "Number" => "1",
          "Title_EN" => "British Waterways Act",
          "Type" => ["ukla"],
          "Year" => 1995
        },
        "id" => "rec16NkvQB6U4yMsr"
      },
      ...
    ]

  """

  describe "airtable" do
    test "get_at_records_with_empty_child/1" do
      resp = get_at_records_with_empty_child("UK E")
      assert {:ok, _rs} = resp
    end
  end

  @data [
      %{
        "createdTime" => "2023-02-17T14:44:55.000Z",
        "fields" => %{
          "Name" => "UK_uksi_2005_1673_LWEAR",
          "Number" => "1673",
          "Title_EN" => "List of Wastes (England) (Amendment) Regulations",
          "Type" => ["uksi"],
          "Year" => 2005
        },
        "id" => "rec11fTT9XKAlfcTF"
      }
    ]

  describe "leg.gov.uk" do
    test "get_child_laws_from_leg_gov_uk/1" do
      resp = get_child_laws_from_leg_gov_uk(@data)
      assert {:ok,
        [
          %{
            "createdTime" => "2023-02-17T14:44:55.000Z",
            "fields" => %{
              enacting_laws: [{"European Communities Act 1972", "ukpga", "1972", "68"}],
              enacting_text: "The Secretary of State, being a Minister designated f00001 in relation to measures relating to the prevention, reduction and elimination of pollution caused by waste, in exercise of the powers conferred upon her by section 2(2) of the European Communities Act 1972 f00002, makes the following Regulations:",
              urls: %{
                "f00001" => 'http://www.legislation.gov.uk/id/uksi/1992/2870',
                "f00002" => 'http://www.legislation.gov.uk/id/ukpga/1972/68'
              }
            },
            "id" => "rec11fTT9XKAlfcTF"
          }
        ]
      }
      = resp

    end
  end

  describe "csv" do
    test "make_csv/1" do
      {:ok, resp} = get_child_laws_from_leg_gov_uk(@data)
      assert {:ok, _linecount} = make_csv(resp)
    end
  end

  @enact %{
    :enacting_text => "The Secretary of State, being a Minister designated f00001 in relation to measures relating to the prevention, reduction and elimination of pollution caused by waste, in exercise of the powers conferred upon her by section 2(2) of the European Communities Act 1972 f00002 f00003, makes the following Regulations:",
    :urls => %{
      "f00001" => 'http://www.legislation.gov.uk/id/uksi/1992/2870',
      "f00002" => 'http://www.legislation.gov.uk/id/ukpga/1972/68'
    }
  }

  describe "enacting" do
    test "parse_enacting_text/1" do
      resp = parse_enacting_text(@enact)
      assert {:ok,
        %{
          enacting_laws: {"European Communities Act 1972", "ukpga", "1972", "68"},
          enacting_text: "The Secretary of State, being a Minister designated f00001 in relation to measures relating to the prevention, reduction and elimination of pollution caused by waste, in exercise of the powers conferred upon her by section 2(2) of the European Communities Act 1972 f00002 f00003, makes the following Regulations:",
          urls: %{
            "f00001" => 'http://www.legislation.gov.uk/id/uksi/1992/2870',
            "f00002" => 'http://www.legislation.gov.uk/id/ukpga/1972/68'
          }
        }
      } = resp
    end
  end
end
