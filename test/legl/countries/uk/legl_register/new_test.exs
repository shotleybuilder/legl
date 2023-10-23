defmodule Legl.Countries.Uk.LeglRegister.NewTest do
  # mix test test/legl/countries/uk/legl_register/new_test.exs
  # mix test test/legl/countries/uk/legl_register/new_test.exs:11
  use ExUnit.Case
  alias Legl.Countries.Uk.LeglRegister.New.New
  alias Legl.Countries.Uk.LeglRegister.New.New.Airtable
  alias Legl.Countries.Uk.LeglRegister.New.New.LegGovUk
  alias Legl.Countries.Uk.LeglRegister.New.New.Filters
  alias Legl.Countries.Uk.LeglRegister.New.Create
  alias Legl.Countries.Uk.LeglRegister.Helpers.NewLaw
  alias Legl.Countries.Uk.LeglRegister.New.New.PublicationDateTable, as: PDT
  alias Legl.Countries.Uk.LeglRegister.New.New.Options

  @moduletag :uk

  @opts %{
    base_name: "UK S",
    year: 2023,
    month: 10,
    day: "12",
    days: {12, 13},
    type_code: [""]
  }

  describe "Legl.Countries.Uk.LeglRegister.New.New.Airtable" do
    test "get_publication_date_table_records/1" do
      opts =
        Map.merge(
          @opts,
          %{
            base_id: "appRhQoz94zyVh2LR",
            pub_table_id: "tblQtdYg4MGIk3tzb",
            formula: "AND({Day}>=\"1\", {Day}<=\"9\",{Month}=\"10\",{Year}=\"2023\")"
          }
        )

      response = Airtable.get_publication_date_table_records(opts)

      IO.inspect(response)

      assert is_list(response)
    end

    test "get_publication_date_table_records/1 w/ options" do
      {:ok, opts} = Options.setOptions(base_name: "UK S", month: 10, days: {9, 12})
      response = Airtable.get_publication_date_table_records(opts)

      IO.inspect(response)
      assert is_list(response)
    end
  end

  describe "url/1" do
    test "url w/o type code" do
      url = LegGovUk.url(@opts)
      assert url == "/new/2023-10-12"
    end

    test "url w/ type code" do
      opts = Map.put(@opts, :type_code, "uksi")
      url = LegGovUk.url(opts)
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

  describe "Legl.Countries.Uk.LeglRegister.New.New.Filters" do
    test "terms_filter/1 w/ match" do
      result = Filters.terms_filter([@laws], %{base_name: "UK S"})

      assert result ==
               {[Map.put(@laws, :Family, "OH&S: Occupational / Personal Safety")], []}
    end

    @match_si_codes ~w[FOOD GAS]
    @no_match_si_codes ~w[FOO BAR]
    @mix_match_si_codes ["FOO", "BAR", "HEALTH AND SAFETY"]

    test "si_code_member? match" do
      result = Filters.si_code_member?(@match_si_codes)
      assert true == result
    end

    test "si_code_member? no match" do
      result = Filters.si_code_member?(@no_match_si_codes)
      assert false == result
    end

    test "si_code_member? mixed match" do
      result = Filters.si_code_member?(@mix_match_si_codes)
      assert true == result
    end
  end

  @source [
    %{
      Number: "1078",
      Title_EN: "Air Navigation (Restriction of Flying) (Luton) (Emergency) Regulations",
      Year: 2023,
      md_description: "",
      publication_date: "2023-10-11",
      type_code: "uksi"
    },
    %{
      Number: "1073",
      Title_EN: "Air Navigation (Restriction of Flying) (Edinburgh) Regulations",
      Year: 2023,
      md_description: "",
      publication_date: "2023-10-11",
      type_code: "uksi"
    }
  ]

  describe " Legl.Countries.Uk.LeglRegister.Helpers.NewLaw" do
    test "setUrl/2" do
      {:ok, result} = NewLaw.setUrl(@source, %{base_id: "foo", table_id: "bar"})
      assert is_list(result)
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

  describe "Legl.Countries.Uk.LeglRegister.New.New.PublicationDateTable" do
    test "get_publication_date_table_records/1" do
      {:ok, opts} = Options.setOptions(month: 10, days: {19, 20})
      results = PDT.get_publication_date_table_records(opts)
      assert {:ok, _} = results
    end
  end
end
