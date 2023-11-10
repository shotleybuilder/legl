# mix test test/legl/countries/uk/uk_repeal_revoke_test.exs:10

defmodule Legl.Countries.Uk.UkRepealRevokeTest do
  use ExUnit.Case

  import Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke

  @data [
    {"tbody", [],
     [
       {"tr", [{"class", "oddRow"}],
        [
          {"td", [],
           [
             {"strong", [],
              [
                "The Health Protection (Coronavirus, Restrictions) (Steps and Other Provisions) (England) (Amendment) (No. 2) Regulations 2021"
              ]}
           ]},
          {"td", [], [{"a", [{"href", "/id/uksi/2021/705"}], ["2021 No. 705"]}]},
          {"td", [], [{"a", [{"href", "/id/uksi/2021/705"}], ["Regulations"]}]},
          {"td", [], ["revoked"]},
          {"td", [{"class", "centralCol"}],
           [
             {"strong", [],
              [
                "The Health Protection (Coronavirus, Restrictions) (Steps etc.) (England) (Revocation and Amendment) Regulations 2021"
              ]}
           ]},
          {"td", [{"class", "centralCol"}],
           [{"a", [{"href", "/id/uksi/2021/848"}], ["2021 No. 848"]}]},
          {"td", [{"class", "centralCol"}],
           [
             {"a", [{"href", "/id/uksi/2021/848/schedule"}], ["Sch. "]},
             {"a", [{"href", "/id/uksi/2021/848/schedule/paragraph/16"}], ["para. 16"]}
           ]},
          {"td", [], [{"span", [{"class", "effectsApplied"}], ["Yes"]}]},
          {"td", [], []}
        ]}
     ]}
  ]

  describe "process amendment table" do
    test "proc_amd_tbl_row/1" do
      [{"tbody", _, [{"tr", _, cells}]}] = @data
      resp = proc_amd_tbl_row(cells)
      assert {:ok, _, "Regulations", "revoked", _, _} = resp
    end
  end

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RRDescription, as: Desc

  @rr_data [
    %{
      Number: "40",
      Title_EN: "Consumer Protection Act 1987",
      Year: 2002,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "repealed",
      amending_title: "Enterprise Act 2002",
      amending_title_and_path: "Enterprise Act 2002💚️https://legislation.gov.uk/id/ukpga/2002/40",
      path: "/id/ukpga/2002/40",
      target: "Sch. 4  para. 7",
      type_code: "ukpga"
    },
    %{
      Number: "27",
      Title_EN: "Consumer Protection Act 1987",
      Year: 2000,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "words repealed",
      amending_title: "Utilities Act 2000",
      amending_title_and_path: "Utilities Act 2000💚️https://legislation.gov.uk/id/ukpga/2000/27",
      path: "/id/ukpga/2000/27",
      target: "s. 10(7)(c)",
      type_code: "ukpga"
    },
    %{
      Number: "27",
      Title_EN: "Consumer Protection Act 1987",
      Year: 2000,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "words repealed",
      amending_title: "Utilities Act 2000",
      amending_title_and_path: "Utilities Act 2000💚️https://legislation.gov.uk/id/ukpga/2000/27",
      path: "/id/ukpga/2000/27",
      target: "s. 11(7)(c)",
      type_code: "ukpga"
    },
    %{
      Number: "47",
      Title_EN: "Consumer Protection Act 1987",
      Year: 1998,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "repealed",
      amending_title: "Northern Ireland Act 1998",
      amending_title_and_path:
        "Northern Ireland Act 1998💚️https://legislation.gov.uk/id/ukpga/1998/47",
      path: "/id/ukpga/1998/47",
      target: "s. 49(2)",
      type_code: "ukpga"
    },
    %{
      Number: "41",
      Title_EN: "Consumer Protection Act 1987",
      Year: 1998,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "repealed",
      amending_title: "Competition Act 1998",
      amending_title_and_path: "Competition Act 1998💚️https://legislation.gov.uk/id/ukpga/1998/41",
      path: "/id/ukpga/1998/41",
      target: "s. 38(3)(e) (f)",
      type_code: "ukpga"
    },
    %{
      Number: "2328",
      Title_EN: "Consumer Protection Act 1987",
      Year: 1994,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "repealed",
      amending_title: "The General Product Safety Regulations 1994",
      amending_title_and_path:
        "The General Product Safety Regulations 1994💚️https://legislation.gov.uk/id/uksi/1994/2328",
      path: "/id/uksi/1994/2328",
      target: "s. 10(3)(b)(ii)",
      type_code: "uksi"
    },
    %{
      Number: "26",
      Title_EN: "Consumer Protection Act 1987",
      Year: 1994,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "words repealed",
      amending_title: "Trade Marks Act 1994",
      amending_title_and_path: "Trade Marks Act 1994💚️https://legislation.gov.uk/id/ukpga/1994/26",
      path: "/id/ukpga/1994/26",
      target: "s. 45(1)",
      type_code: "ukpga"
    },
    %{
      Number: "26",
      Title_EN: "Consumer Protection Act 1987",
      Year: 1994,
      __struct__: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke,
      affect: "repealed",
      amending_title: "Trade Marks Act 1994",
      amending_title_and_path: "Trade Marks Act 1994💚️https://legislation.gov.uk/id/ukpga/1994/26",
      path: "/id/ukpga/1994/26",
      target: "s. 45(4)",
      type_code: "ukpga"
    }
  ]

  describe " Legl.Countries.Uk.LeglRegister.RepealRevoke.RRDescription" do
    test "make_repeal_revoke_data_structure/1" do
      resp = Desc.make_repeal_revoke_data_structure(@rr_data)
      IO.inspect(resp)
      assert is_list(resp)
    end

    test "Desc.sort_on_amending_law_year/1" do
      records = Desc.make_repeal_revoke_data_structure(@rr_data)
      resp = Desc.sort_on_amending_law_year(records)
      IO.inspect(resp)
      assert is_list(resp)
    end

    test "Desc.convert_to_string/1" do
      records = Desc.make_repeal_revoke_data_structure(@rr_data)
      records = Desc.sort_on_amending_law_year(records)
      resp = Desc.convert_to_string(records)
      IO.inspect(resp)
      assert is_list(resp)
    end

    test "Desc.string_for_at_field/1" do
      records = Desc.make_repeal_revoke_data_structure(@rr_data)
      records = Desc.sort_on_amending_law_year(records)
      records = Desc.convert_to_string(records)
      resp = Desc.string_for_at_field(records)
      IO.inspect(resp)
      assert is_binary(resp)
    end
  end
end
