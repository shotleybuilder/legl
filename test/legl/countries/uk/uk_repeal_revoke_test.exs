# mix test test/legl/countries/uk/uk_repeal_revoke_test.exs:10

defmodule Legl.Countries.Uk.UkRepealRevokeTest do

  use ExUnit.Case

  import Legl.Countries.Uk.UkRepealRevoke
  import Legl.Services.LegislationGovUk.RecordGeneric

  test "make_csv_workflow/2" do
    url = "/changes/affected/ukpga/1967/10?results-count=1000&sort=affecting-year-number&order=descending"
    resp = make_csv_workflow("test_name", url)
    assert :ok = resp
  end

  describe "Legl.Services.LegislationGovUk.RecordGeneric.repeal_revoke/1" do
    test "revoked" do
      url =
        "/changes/affected/uksi/2021/705?results-count=1000&sort=affecting-year-number"
      resp = repeal_revoke(url)
      assert is_list(resp)
    end
    test "repealed" do
      url =
        "/changes/affected/ukpga/2003/12?results-count=1000&sort=affecting-year-number"
      resp = repeal_revoke(url)
      assert is_list(resp)
    end
    test "no amendments" do
      url =
        "/changes/affected/uksi/2023/118?results-count=1000&sort=affecting-year-number"
      resp = repeal_revoke(url)
      assert [] = resp
    end
  end

  describe "Record & process_amendment_table" do
    test "process revoked" do
      url =
        "/changes/affected/uksi/2021/705?results-count=1000&sort=affecting-year-number"
      data = repeal_revoke(url)
      resp = process_amendment_table(data)
      assert is_list(resp)
      IO.inspect(resp)
    end
  end

  @data [
    {"tbody", [],
      [
        {"tr", [{"class", "oddRow"}],
          [
            {"td", [], [{"strong", [], ["The Health Protection (Coronavirus, Restrictions) (Steps and Other Provisions) (England) (Amendment) (No. 2) Regulations 2021"]}]},
            {"td", [], [{"a", [{"href", "/id/uksi/2021/705"}], ["2021 No. 705"]}]},
            {"td", [], [{"a", [{"href", "/id/uksi/2021/705"}], ["Regulations"]}]},
            {"td", [], ["revoked"]},
            {"td", [{"class", "centralCol"}], [{"strong", [], ["The Health Protection (Coronavirus, Restrictions) (Steps etc.) (England) (Revocation and Amendment) Regulations 2021"]}]},
            {"td", [{"class", "centralCol"}], [{"a", [{"href", "/id/uksi/2021/848"}], ["2021 No. 848"]}]},
            {"td", [{"class", "centralCol"}], [{"a", [{"href", "/id/uksi/2021/848/schedule"}], ["Sch. "]}, {"a", [{"href", "/id/uksi/2021/848/schedule/paragraph/16"}], ["para. 16"]}]},
            {"td", [], [{"span", [{"class", "effectsApplied"}], ["Yes"]}]},
            {"td", [], []}
          ]
        }
      ]
    }
  ]

  describe "process amendment table" do
    test "proc_amd_tbl_row/1" do
      [{"tbody", _, [{"tr", _, cells}]}] = @data
      resp = proc_amd_tbl_row(cells)
      assert {:ok, _, "Regulations", "revoked", _, _} = resp
    end

    test "process_amendment_table/1 []                                            " do
      resp = process_amendment_table([])
      assert {:ok, []} = resp
    end

    test "process_amendment_table/1" do
      resp = process_amendment_table(@data)
      assert {:ok, _data} = resp
    end
  end

  alias Legl.Services.LegislationGovUk.RecordGeneric, as: Record
  @url "/changes/affected/ukpga/1967/10?results-count=1000&sort=affecting-year-number&order=descending"
  describe "revoke repeal details table" do
    test "revoke_repeal_details/1" do
      {:ok, table} = Record.repeal_revoke(@url)
      resp = revoke_repeal_details(table)
      IO.inspect(resp)
      assert is_list(resp)
    end
    test "make_repeal_revoke_data_structure/1" do
      {:ok, table} = Record.repeal_revoke(@url)
      records = revoke_repeal_details(table)
      resp = make_repeal_revoke_data_structure(records)
      IO.inspect(resp)
      assert is_map(resp)
    end
    test "sort_on_amending_law_year/1" do
      {:ok, table} = Record.repeal_revoke(@url)
      records = revoke_repeal_details(table)
      records = make_repeal_revoke_data_structure(records)
      resp = sort_on_amending_law_year(records)
      IO.inspect(resp)
      assert is_list(resp)
    end
    test "convert_to_string/1" do
      {:ok, table} = Record.repeal_revoke(@url)
      records = revoke_repeal_details(table)
      records = make_repeal_revoke_data_structure(records)
      records = sort_on_amending_law_year(records)
      resp = convert_to_string(records)
      IO.inspect(resp)
      assert is_list(resp)
    end
    test "string_for_at_field/1" do
      {:ok, table} = Record.repeal_revoke(@url)
      records = revoke_repeal_details(table)
      records = make_repeal_revoke_data_structure(records)
      records = sort_on_amending_law_year(records)
      records = convert_to_string(records)
      resp = string_for_at_field(records)
      IO.inspect(resp)
      assert is_binary(resp)
    end
  end
end
