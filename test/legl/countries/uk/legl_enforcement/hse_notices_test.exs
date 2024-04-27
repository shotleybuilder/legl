defmodule Legl.Countries.Uk.LeglEnforcement.HseNoticesTest do
  # mix test test/legl/countries/uk/legl_enforcement/hse_notices_test.exs
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglEnforcement.HseNotices

  setup_all do
    {:ok,
     notices:
       Legl.Utility.read_json_records(
         Path.expand("lib/legl/countries/uk/legl_enforcement/hse_notices.json")
       )}
  end

  test "enum_breaches/1", context do
    %{notices: notices} = context

    notices
    |> HseNotices.enum_breaches()
    |> IO.inspect()
    |> Enum.each(fn notice ->
      assert is_map(notice)
      assert is_list(notice.breaches)
    end)
  end

  @records [
    %{
      "createdTime" => "2023-12-06T14:01:05.000Z",
      "fields" => %{
        "Name" => "UK_uksi_2015_255",
        "Number" => "255",
        "Title_EN" => "Animal Feed (Composition, Marketing and Use) (England) Regulations",
        "Year" => 2015,
        "type_code" => "uksi"
      },
      "id" => "rec6WCHpLCCA0GN3E"
    },
    %{
      "createdTime" => "2023-12-07T17:02:40.000Z",
      "fields" => %{
        "Name" => "UK_uksi_2015_840",
        "Number" => "840",
        "Title_EN" => "Rules of the Air Regulations",
        "Year" => 2015,
        "type_code" => "uksi"
      },
      "id" => "rec7eCJoTsa9H5efI"
    },
    %{
      "createdTime" => "2023-12-07T15:48:54.000Z",
      "fields" => %{
        "Name" => "UK_uksi_2015_51",
        "Number" => "51",
        "Title_EN" => "Construction (Design and Management) Regulations",
        "Year" => 2015,
        "type_code" => "uksi"
      },
      "id" => "rec8eJ507CIvSSEGm"
    },
    %{
      "createdTime" => "2023-03-01T11:52:36.000Z",
      "fields" => %{
        "Name" => "UK_uksi_2015_627",
        "Number" => "627",
        "Title_EN" => "Planning (Hazardous Substances) Regulations",
        "Year" => 2015,
        "type_code" => "uksi"
      },
      "id" => "recDKijfVOaCx6Kw2"
    },
    %{
      "createdTime" => "2023-02-16T16:21:52.000Z",
      "fields" => %{
        "Name" => "UK_uksi_2015_1570",
        "Number" => "1570",
        "Title_EN" => "Progress Power (Gas Fired Power Station) Order",
        "Year" => 2015,
        "type_code" => "uksi"
      },
      "id" => "recDogLS6zd00ORLI"
    },
    %{
      "createdTime" => "2023-12-07T13:09:30.000Z",
      "fields" => %{
        "Name" => "UK_uksi_2015_1553",
        "Number" => "1553",
        "Title_EN" => "Pyrotechnic Articles (Safety) Regulations",
        "Year" => 2015,
        "type_code" => "uksi"
      },
      "id" => "recEdg0G1ouxhjXMS"
    }
  ]

  test "match_title/2" do
    result = HseNotices.match_title(@records, "Construction (Design and Management) Regulations")

    assert result == {
             "rec8eJ507CIvSSEGm",
             "Construction (Design and Management) Regulations",
             "uksi",
             "2015",
             "51"
           }
  end
end
