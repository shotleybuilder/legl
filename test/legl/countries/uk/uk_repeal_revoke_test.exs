# mix test test/legl/countries/uk/uk_repeal_revoke_test.exs:10

defmodule Legl.Countries.Uk.UkRepealRevokeTest do

  use ExUnit.Case

  import Legl.Countries.Uk.UkRepealRevoke

  test "leg_gov_uk_record/1" do
    url = "/changes/affected/uksi/2021/705?results-count=1000&sort=affecting-year-number"
    resp = leg_gov_uk_record(url)
    assert {:ok, _data} = resp
    IO.inspect(resp)
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
end
