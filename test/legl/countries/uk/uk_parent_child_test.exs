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
    test "get_at_records_with_empty_parent/1" do
      resp = get_at_records_with_empty_parent("UK E")
      assert {:ok, _rs} = resp
    end
  end

  @data_enact [
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

  @data_intro [
    %{
      "createdTime" => "2023-02-17T14:44:55.000Z",
      "fields" => %{
        "Name" => "UK_uksi_2022_1336_GGETSANO",
        "Number" => "1336",
        "Title_EN" => "Greenhouse Gas Emissions Trading Scheme (Amendment) (No. 3) Order",
        "Type" => ["uksi"],
        "Year" => 2022
      },
      "id" => "rec11fTT9XKAlfcTF"
    }
  ]

  describe "leg.gov.uk" do

    test "get_parent_enact/1" do
      path = introduction_path("uksi", 2005, "1673")
      resp = get_parent(path)
      assert {:ok,
        %{
          enacting_text: "The Secretary of State, being a Minister designated f00001 in relation to measures relating to the prevention, reduction and elimination of pollution caused by waste, in exercise of the powers conferred upon her by section 2(2) of the European Communities Act 1972 f00002, makes the following Regulations:",
          introductory_text: nil,
          urls:
          %{
            "f00001" => 'http://www.legislation.gov.uk/id/uksi/1992/2870',
            "f00002" => 'http://www.legislation.gov.uk/id/ukpga/1972/68'}
          }
        } = resp
    end

    test "get_parent_intro/1" do
      path = introduction_path("uksi", 2022, "1336")
      resp = get_parent(path)
      assert {
        :ok,
        %{
          enacting_text: "Accordingly, His Majesty, by and with the advice of His Privy Council, makes the following Order:",
          introductory_text: "This Order is made in exercise of the powers conferred by sections 44 and 90(3) of, and Schedule 2 and paragraph 9 of Schedule 3 to, the Climate Change Act 2008 f00001.In accordance with paragraph 10 of Schedule 3 to that Act, before the recommendation to His Majesty in Council to make this Order was made—athe advice of the Committee on Climate Change was obtained and taken into account; andbsuch persons likely to be affected by the Order as the Secretary of State, the Scottish Ministers and the Welsh Ministers considered appropriate were consulted.In accordance with paragraph 11 of that Schedule, a draft of the instrument containing this Order was laid before Parliament, the Scottish Parliament and Senedd Cymru and approved by resolution of each House of Parliament, the Scottish Parliament and Senedd Cymru.",
          urls:
          %{
            "f00001" => 'http://www.legislation.gov.uk/id/ukpga/2008/27'
          }
        }
      } = resp
    end

    test "get_parent_laws_from_leg_gov_uk/1 - enact" do
      resp = get_parent_laws_from_leg_gov_uk(@data_enact)
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
      } = resp
    end

    test "get_parent_laws_from_leg_gov_uk/1 - intro" do
      resp = get_parent_laws_from_leg_gov_uk(@data_intro)
      assert {:ok,
        [
          %{
            "createdTime" => "2023-02-17T14:44:55.000Z",
            "fields" => %{
              :enacting_laws => [{"Climate Change Act 2008", "ukpga", "2008", "27"}],
              :enacting_text => _etext,
              :introductory_text => _itext,
              :urls => %{"f00001" => 'http://www.legislation.gov.uk/id/ukpga/2008/27'},
              "Name" => "UK_uksi_2022_1336_GGETSANO",
              "Number" => "1336",
              "Title_EN" => "Greenhouse Gas Emissions Trading Scheme (Amendment) (No. 3) Order",
              "Type" => ["uksi"],
              "Year" => 2022
            },
            "id" => "rec11fTT9XKAlfcTF"
          }
        ]
      } = resp
    end
  end

  describe "csv" do
    test "make_csv/1" do
      {:ok, resp} = get_parent_laws_from_leg_gov_uk(@data_enact)
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
    test "parse_text/1" do
      resp = parse_text(@enact.enacting_text, @enact.urls, @enact)
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
