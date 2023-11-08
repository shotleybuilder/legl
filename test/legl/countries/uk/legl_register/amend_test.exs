# mix test test/legl/countries/uk/legl_register/amend_test.exs:8
defmodule Legl.Countries.Uk.LeglRegister.AmendTest do
  use ExUnit.Case
  import Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.Amend.Patch
  alias Legl.Countries.Uk.LeglRegister.Amend.AmendedBy

  describe "Legl.Countries.Uk.LeglRegister.Amend.Patch " do
    test "parse_law/1" do
      record = [
        {"td", [], [{"strong", [], ["Consumer Protection Act 1987"]}]},
        {"td", [], [{"a", [{"href", "/id/ukpga/1987/43"}], ["1987 c. 43"]}]},
        {"td", [], [{"a", [{"href", "/id/ukpga/1987/43/schedule/2"}], ["Sch. 2"]}]},
        {"td", [], []},
        {"td", [{"class", "centralCol"}],
         [
           {"strong", [], ["The In Vitro Diagnostic Medical Devices Regulations 2000"]}
         ]},
        {"td", [{"class", "centralCol"}],
         [{"a", [{"href", "/id/uksi/2000/1315"}], ["2000 No. 1315"]}]},
        {"td", [{"class", "centralCol"}],
         [{"a", [{"href", "/id/uksi/2000/1315/regulation/18"}], ["reg. 18"]}]},
        {"td", [], [{"span", [{"class", "effectsApplied"}], ["Yes"]}]},
        {"td", [], []}
      ]

      result = AmendedBy.parse_law(record)
      assert %_{} = result
    end

    test "clean/1" do
      record = %{
        Amending: "UK_ukpga_2003_17_LA,UK_ukpga_2020_16_BPA",
        Name: "UK_uksi_2023_990_ALCREAR",
        Number: "990",
        Title_EN:
          "Alcohol Licensing (Coronavirus) (Regulatory Easements) (Amendment) Regulations",
        Year: 2023,
        record_id: "rec9KtbuTLLQ9VIJr",
        stats_amended_laws_count: 2,
        stats_amending_laws_count: 0,
        stats_amendings_count: 2,
        stats_amendings_count_per_law:
          "UK_ukpga_2003_17_LA - 1💚️https://legislation.gov.uk/id/ukpga/2003/17💚️💚️UK_ukpga_2020_16_BPA - 1💚️https://legislation.gov.uk/id/ukpga/2020/16",
        stats_amendings_count_per_law_detailed:
          "UK_ukpga_2003_17_LA - 1💚️https://legislation.gov.uk/id/ukpga/2003/17💚️ s. 172F(10)(d)(i) words substituted [Not yet]💚️💚️UK_ukpga_2020_16_BPA - 1💚️https://legislation.gov.uk/id/ukpga/2020/16💚️ s. 11(13) words substituted [Not yet]",
        stats_amendments_count: 0,
        stats_self_amending_count: 0,
        stats_self_amendings_count: 0,
        type_code: "uksi"
      }

      result = Patch.clean(record)
      assert %{id: _, fields: _} = result
      # IO.inspect(result)
    end
  end
end
