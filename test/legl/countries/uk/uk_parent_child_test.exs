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
    test "get_child_laws_from_leg_gov_uk/" do
      resp = get_child_laws_from_leg_gov_uk(@data)
      assert {:ok, _} = resp
      IO.inspect(resp)
    end
  end
end
