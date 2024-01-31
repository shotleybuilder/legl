defmodule Legl.Countries.Uk.LeglRegister.TaxaTest do
  @moduledoc """

  Tests for the functions in legl_register/taxa

  Calling code is legl_register/taxa/taxa.ex

  This calls the workflow here:
  at_article/taxa/lrt_taxa.ex

  with two parameters.

  1. The records from the LAT
  2. The LRT record

  Each function updates the LRT record and the LRT record is unchanged


  mix test test/legl/countries/uk/legl_register/taxa_test.exs

  """

  use ExUnit.Case

  @moduletag :uk

  alias Legl.Countries.Uk.LeglRegister.Taxa

  alias Legl.Countries.Uk.LeglRegister.Taxa.GovernmentRoles
  alias Legl.Countries.Uk.LeglRegister.Taxa.GovernedRoles

  alias Legl.Countries.Uk.LeglRegister.Taxa.ResponsibilityHolder
  alias Legl.Countries.Uk.LeglRegister.Taxa.PowerHolder
  alias Legl.Countries.Uk.LeglRegister.Taxa.DutyHolder
  alias Legl.Countries.Uk.LeglRegister.Taxa.RightsHolder

  alias Legl.Countries.Uk.LeglRegister.Taxa.DutyType

  alias Legl.Countries.Uk.LeglRegister.Taxa.Popimar

  describe "lrt/1" do
    test "choose taxa" do
      response = UK.lat(selection: 1, taxa_selection: 3)
      assert response == %{selection: 1, taxa_selection: 3}
    end
  end

  describe "set_taxa_leg_gov_uk/1" do
    test "!=made" do
      response =
        UK.lrt(
          name: "UK_uksi_1992_2793",
          # "LRT: UPDATE Single Law using 'Name'"
          selection: 0,
          # :Taxa_from_leg_gov_uk
          lrt_workflow_selection: 11,
          filesave?: true,
          print_opts?: true
        )

      IO.inspect(response, pretty: true)
    end
  end

  describe "Legl.Countries.Uk.Article.Taxa.LATTaxa" do
    test "api_update_lat_taxa_from_text/2" do
      path = ~s[lib/legl/data_files/json/at_schema.json] |> Path.absname()
      records = Legl.Utility.read_json_records(path)
      records = Enum.map(records, fn record -> Kernel.struct(%UK.Regulation{}, record) end)
      opts = Legl.Countries.Uk.Article.Taxa.Options.taxa_workflow(%{taxa_workflow_selection: 0})
      opts = Map.merge(opts, %{filesave?: false, Name: "UK_uksi_1992_2793"})
      result = Legl.Countries.Uk.Article.Taxa.LATTaxa.api_update_lat_taxa_from_text(records, opts)
      assert {:ok, _} = result
    end
  end

  describe "xxx_article_clause_field/1" do
    @text {"Gvt: Agency: Office of Rail and Road",
           [
             {"https://legislation.gov.uk/ukpga/1974/37/section/18",
              [
                "POWER\n 👤Gvt: Agency: Health and Safety Executive\n 📌 the Executive] may",
                "POWER\n 👤Gvt: Minister\n 📌 Secretary of State may\nPOWER\n 👤Gvt: Authority: Local\n 📌 local authorities responsible for the enforcement of the relevant statutory provisions to such extent as may\nPOWER\n 👤Gvt: Agency: Office for Nuclear Regulation\n 📌 Office for Nuclear Regulation responsible for the enforcement of the relevant statutory provisions to such extent as may",
                "POWER\n 👤Gvt: Authority\n 📌 the authority by the preceding paragraph and any other functions conferred on the authority by any of the relevant statutory provisions in accordance with such guidance as [F87 the Executive] may\nPOWER\n 👤Gvt: Agency: Office of Rail and Road\n 📌 Office of Rail and Road],]to perform the duty imposed on the authority by the preceding paragraph and any other functions conferred on the authority by any of the relevant statutory provisions in accordance with such guidance as [F87 the Executive] may\nPOWER\n 👤Gvt: Agency: Health and Safety Executive\n 📌 the Executive] may",
                "POWER\n 👤Gvt: Authority: Enforcement\n 📌 enforcing authority where that authority is the Executive) in any provision of this Part which relates to that function shall, so far as may\nPOWER\n 👤Gvt: Agency: Office for Nuclear Regulation\n 📌 Office for Nuclear Regulation () ] (or to an enforcing authority where that authority is the Executive) in any provision of this Part which relates to that function shall, so far as may\nPOWER\n 👤Gvt: Agency: Health and Safety Executive\n 📌 the Executive [F92 or the Office for Nuclear Regulation () ] (or to an enforcing authority where that authority is the Executive) in any provision of this Part which relates to that function shall, so far as may"
              ]}
           ]}

    test "office of rail and road" do
      result = Taxa.xxx_article_clause_field(@text)
      IO.inspect(result, label: "XXX_ARTICLE_CLAUSE_FIELD")

      assert """
             [Gvt: Agency: Office of Rail and Road]
             https://legislation.gov.uk/ukpga/1974/37/section/18
             POWER
             👤Gvt: Agency: Office of Rail and Road
             📌 Office of Rail and Road],]to perform the duty imposed on the authority by the preceding paragraph and any other functions conferred on the authority by any of the relevant statutory provisions in accordance with such guidance as [F87 the Executive] may
             """
             |> String.trim_trailing("\n") == result
    end
  end

  # @lrt [
  #  Kernel.struct(
  #    %Legl.Countries.Uk.LeglRegister.LegalRegister{},
  #    %{Title_EN: "K_CMCHA_ukpga_2007_19", Year: 2000, Number: 100, type_code: "ukpga"}
  #  )
  # ]
  @lat Legl.Utility.read_json_records("test/legl/countries/uk/legl_register/taxa_lat_source.json")

  describe "Government Roles" do
    test "duty_actor_gvt/1" do
      result = GovernmentRoles.actor_gvt(@lat)

      assert result.actor_gvt == [
               "Gvt: Agency:",
               "Gvt: Authority",
               "Gvt: Authority: Enforcement",
               "Gvt: Authority: Local",
               "Gvt: Authority: Public",
               "Gvt: Devolved Admin: Northern Ireland Assembly",
               "Gvt: Devolved Admin: Scottish Parliament",
               "Gvt: Emergency Services: Police",
               "Gvt: Judiciary",
               "Gvt: Minister",
               "Gvt: Ministry:",
               "Gvt: Ministry: Ministry of Defence"
             ]
    end

    test "actor_gvt_article/1" do
      result = GovernmentRoles.actor_gvt_article(@lat)

      assert """
             [Gvt: Agency:]
             https://legislation.gov.uk/ukpga/2007/19/section/6
             https://legislation.gov.uk/ukpga/2007/19/section/13
             """ <> _ = result.actor_gvt_article
    end

    test "article_actor_gvt/1" do
      result = GovernmentRoles.article_actor_gvt(@lat)

      assert "https://legislation.gov.uk/ukpga/2007/19/crossheading/2" <> _ =
               result.article_actor_gvt

      # IO.puts(result.article_actor_gvt)
    end
  end

  describe "Governed Roles" do
    test "actor/1" do
      result = GovernedRoles.actor(@lat)

      assert result.actor == [
               "Ind: Employee",
               "Ind: Holder",
               "Ind: Person",
               "Org: Company",
               "Org: Employer",
               "Org: Occupier",
               "Org: Partnership",
               "Organisation",
               "Public",
               "Spc: Trade Union"
             ]
    end

    test "actor_article/1" do
      result = GovernedRoles.actor_article(@lat)

      assert """
             [Ind: Employee]
             https://legislation.gov.uk/ukpga/2007/19/section/2
             https://legislation.gov.uk/ukpga/2007/19/section/5
             https://legislation.gov.uk/ukpga/2007/19/section/25
             """ <> _ = result.actor_article

      # IO.puts(result.actor_article)
    end

    test "article_actor/1" do
      result = GovernedRoles.article_actor(@lat)

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/1
             Ind: Person; Org: Employer; Org: Partnership; Organisation; Spc: Trade Union
             """ <> _ = result.article_actor

      #      IO.puts(result.article_actor)
    end
  end

  describe "Aggregate Clauses" do
    test "aggregate/2 responsibility_holder" do
      keys = Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_keys(@lat)

      # IO.inspect(keys, label: "KEYS")

      assert is_list(keys)
      assert hd(keys) == {"UK_CMCHA_ukpga_2007_19___21_28", "reczkPZhYqGze1Tce"}

      aggregates =
        Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregates(
          keys,
          :responsibility_holder_txt,
          @lat
        )

      # IO.inspect(aggregates, label: "AGGREGATES")

      assert is_list(aggregates)
      assert hd(aggregates) == {"reczkPZhYqGze1Tce", []}

      result =
        Legl.Countries.Uk.Article.Taxa.LATTaxa.aggregate_result(
          aggregates,
          :responsibility_holder_txt_aggregate,
          @lat
        )

      # IO.inspect(result, label: "AGGREGATE RESULT")

      assert is_list(result)
    end
  end

  describe "Responsibility Holder" do
    test "responsibility_holder/1" do
      result = ResponsibilityHolder.responsibility_holder(@lat)

      assert ["Gvt: Judiciary"] = result.responsibility_holder
    end

    test "responsibility_holder_article/1" do
      result = ResponsibilityHolder.responsibility_holder_article(@lat)

      assert """
             [Gvt: Judiciary]
             https://legislation.gov.uk/ukpga/2007/19/section/10
             """
             |> String.trim_trailing("\n") == result.responsibility_holder_article

      # IO.puts(result.responsibility_holder_article)
    end

    test "responsibility_holder_article_clause/1" do
      result = ResponsibilityHolder.responsibility_holder_article_clause(@lat)
      # IO.inspect(result, label: "RESP_HOLDER_ARTICLE_CLAUSE")
      # heredoc
      assert """
             [Gvt: Judiciary]
             https://legislation.gov.uk/ukpga/2007/19/section/10
             RESPONSIBILITY
             👤Gvt: Judiciary
             📌 court must
             """
             |> String.trim_trailing("\n") == result.responsibility_holder_article_clause
    end

    test "article_responsibility_holder/1" do
      result = ResponsibilityHolder.article_responsibility_holder(@lat)
      # IO.inspect(result, label: "ARTICLE_RESP_HOLDER")

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/9
             Gvt: Judiciary

             https://legislation.gov.uk/ukpga/2007/19/section/10
             Gvt: Judiciary
             """
             |> String.trim_trailing("\n") == result.article_responsibility_holder
    end

    test "article_responsibility_holder_clause/1" do
      result = ResponsibilityHolder.article_responsibility_holder_clause(@lat)

      # IO.inspect(result, label: "ARTICLE_RESP_HOLDER_CLAUSE")

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/9
             RESPONSIBILITY
             👤Gvt: Judiciary
             📌 court must

             https://legislation.gov.uk/ukpga/2007/19/section/10
             RESPONSIBILITY
             👤Gvt: Judiciary
             📌 court must
             """
             |> String.trim_trailing("\n") == result.article_responsibility_holder_clause
    end
  end

  describe "Power Holder" do
    test "power_holder/1" do
      result = PowerHolder.power_holder(@lat)
      # IO.inspect(result, label: "POWER_HOLDER")

      assert result ==
               %{power_holder: ["Gvt: Judiciary", "Gvt: Minister", "Gvt: Ministry:"]}
    end

    test "power_holder_article/1" do
      result = PowerHolder.power_holder_article(@lat)

      # IO.inspect(result, label: "POWER_HOLDER_ARTICLE")

      assert is_map(result)

      assert """
             [Gvt: Judiciary]
             https://legislation.gov.uk/ukpga/2007/19/section/9
             https://legislation.gov.uk/ukpga/2007/19/section/10
             """ <> _ = result.power_holder_article
    end

    test "power_holder_article_clause/1" do
      result = PowerHolder.power_holder_article_clause(@lat)

      # IO.inspect(result, label: "POWER_HOLDER_ARTICLE_CLAUSE")

      assert is_map(result)

      assert """
             [Gvt: Judiciary]
             https://legislation.gov.uk/ukpga/2007/19/section/9
             POWER
             👤Gvt: Judiciary
             📌 court before which an organisation is convicted of corporate manslaughter or corporate homicide may
             https://legislation.gov.uk/ukpga/2007/19/section/10
             POWER
             👤Gvt: Judiciary
             📌 court before which an organisation is convicted of corporate manslaughter or corporate homicide may
             """ <> _ = result.power_holder_article_clause
    end

    test "article_power_holder/1" do
      result = PowerHolder.article_power_holder(@lat)

      # IO.inspect(result, label: "ARTICLE_POWER_HOLDER")

      assert is_map(result)

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/9
             Gvt: Judiciary

             https://legislation.gov.uk/ukpga/2007/19/section/9
             Gvt: Judiciary
             """ <> _ = result.article_power_holder
    end

    test "article_power_holder_clause/1" do
      result = PowerHolder.article_power_holder_clause(@lat)

      # IO.inspect(result, lable: "ARTICLE_POWER_HOLDER_CLAUSE")

      assert is_map(result)

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/9
             POWER
             👤Gvt: Judiciary
             📌 court before which an organisation is convicted of corporate manslaughter or corporate homicide may

             https://legislation.gov.uk/ukpga/2007/19/section/9
             POWER
             👤Gvt: Judiciary
             📌 court before which an organisation is convicted of corporate manslaughter or corporate homicide may
             """ <> _ = result.article_power_holder_clause
    end
  end

  describe "Duty Holder" do
    test "duty_holder" do
      result = DutyHolder.duty_holder(@lat)

      # IO.inspect(result, label: "DUTY_HOLDER")

      assert is_map(result)

      assert %{duty_holder: ["Organisation"]} = result
    end

    test "duty_holder_article/1" do
      result = DutyHolder.duty_holder_article(@lat)

      # IO.inspect(result, label: "DUTY_HOLDER_ARTICLE")

      "[Organisation]\nhttps://legislation.gov.uk/ukpga/2007/19/section/1" =
        result.duty_holder_article
    end

    test "duty_holder_article_clause/1" do
      result = DutyHolder.duty_holder_article_clause(@lat)

      # IO.inspect(result, label: "DUTY_HOLDER_ARTICLE_CLAUSE")

      assert """
             [Organisation]
             https://legislation.gov.uk/ukpga/2007/19/section/1
             DUTY
             👤Organisation
             📌 organisation that is guilty of corporate manslaughter or corporate homicide is liable
             """
             |> String.trim_trailing("\n") == result.duty_holder_article_clause
    end

    test "article_duty_holder/1" do
      result = DutyHolder.article_duty_holder(@lat)
      # IO.inspect(result, label: "ARTICLE_DUTY_HOLDER")

      assert is_map(result)

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/1
             Organisation

             https://legislation.gov.uk/ukpga/2007/19/section/1
             Organisation
             """
             |> String.trim_trailing("\n") == result.article_duty_holder
    end

    test "article_duty_holder_clause/1" do
      result = DutyHolder.article_duty_holder_clause(@lat)

      # IO.inspect(result, label: "ARTICLE_DUTY_HOLDER_CLAUSE")

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/1\nDUTY
             👤Organisation
             📌 organisation that is guilty of corporate manslaughter or corporate homicide is liable

             https://legislation.gov.uk/ukpga/2007/19/section/1
             DUTY
             👤Organisation
             📌 organisation that is guilty of corporate manslaughter or corporate homicide is liable
             """
             |> String.trim_trailing("\n") == result.article_duty_holder_clause
    end
  end

  describe "Rights Holder" do
    test "rights_holder/1" do
      result = RightsHolder.rights_holder(@lat)

      # IO.inspect(result, label: "RIGHTS_HOLDER")

      assert is_map(result)

      assert %{rights_holder: ["Organisation"]} = result
    end

    test "rights_holder_article/1" do
      result = RightsHolder.rights_holder_article(@lat)

      # IO.inspect(result, label: "RIGHTS_HOLDER_ARTICLE")

      "[Organisation]\nhttps://legislation.gov.uk/ukpga/2007/19/section/19" =
        result.rights_holder_article
    end

    test "rights_holder_article_clause/1" do
      result = RightsHolder.rights_holder_article_clause(@lat)

      # IO.inspect(result, label: "RIGHTS_HOLDER_ARTICLE_CLAUSE")

      assert """
             [Organisation]
             https://legislation.gov.uk/ukpga/2007/19/section/19\nRIGHT
             👤Organisation
             📌An organisation that has been convicted of corporate manslaughter or corporate homicide arising out of a particular set of circumstances may,
             """
             |> String.trim_trailing("\n") == result.rights_holder_article_clause
    end

    test "article_rights_holder/1" do
      result = RightsHolder.article_rights_holder(@lat)
      # IO.inspect(result, label: "ARTICLE_RIGHTS_HOLDER")

      assert is_map(result)

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/15
             Organisation

             https://legislation.gov.uk/ukpga/2007/19/section/19
             Organisation
             """
             |> String.trim_trailing("\n") == result.article_rights_holder
    end

    test "article_rights_holder_clause/1" do
      result = RightsHolder.article_rights_holder_clause(@lat)

      # IO.inspect(result, label: "ARTICLE_RIGHTS_HOLDER_CLAUSE")

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/15
             RIGHT
             👤Organisation
             📌An organisation that has been convicted of corporate manslaughter or corporate homicide arising out of a particular set of circumstances may,

             https://legislation.gov.uk/ukpga/2007/19/section/19
             RIGHT
             👤Organisation
             📌An organisation that has been convicted of corporate manslaughter or corporate homicide arising out of a particular set of circumstances may,
             """
             |> String.trim_trailing("\n") == result.article_rights_holder_clause
    end
  end

  describe "Duty Type" do
    test "duty_type/1" do
      result = DutyType.duty_type(@lat)

      # IO.inspect(result, label: "DUTY_TYPE")

      assert is_map(result)

      assert %{
               duty_type: [
                 "Duty",
                 "Right",
                 "Responsibility",
                 "Power",
                 "Enactment, Citation, Commencement",
                 "Interpretation, Definition",
                 "Application, Scope",
                 "Extent",
                 "Process, Rule, Constraint, Condition",
                 "Power Conferred",
                 "Offence",
                 "Enforcement, Prosecution",
                 "Repeal, Revocation",
                 "Amendment"
               ]
             } = result
    end

    test "duty_type_article/1" do
      result = DutyType.duty_type_article(@lat)

      # IO.inspect(result, label: "DUTY_TYPE_ARTICLE")

      assert is_map(result)

      assert """
             [Duty]
             https://legislation.gov.uk/ukpga/2007/19/section/1

             [Right]
             https://legislation.gov.uk/ukpga/2007/19/section/19
             """ <> _ = result.duty_type_article
    end

    test "article_duty_type/1" do
      result = DutyType.article_duty_type(@lat)
      # IO.puts("ARTICLE_DUTY_TYPE\n#{result.article_duty_type}")

      assert is_map(result)

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/1
             Application, Scope; Duty; Enforcement, Prosecution; Interpretation, Definition; Offence
             """ <> _ = result.article_duty_type
    end
  end

  describe "POPIMAR" do
    test "popimar/1" do
      result = Popimar.popimar(@lat)
      # IO.inspect(result, label: "POPIMAR")
      assert is_map(result)

      assert [
               "Policy",
               "Organisation - Control",
               "Organisation - Communication & Consultation",
               "Organisation - Competence",
               "Organisation - Costs",
               "Notification",
               "Aspects and Hazards",
               "Risk Control",
               "Maintenance, Examination and Testing"
             ] == result.popimar
    end

    test "popimar_article/1" do
      result = Popimar.popimar_article(@lat)
      # IO.inspect(result, label: "POPIMAR_ARTICLE")
      assert is_map(result)

      assert """
             [Policy]
             https://legislation.gov.uk/ukpga/2007/19/section/2
             https://legislation.gov.uk/ukpga/2007/19/section/3
             https://legislation.gov.uk/ukpga/2007/19/section/5
             https://legislation.gov.uk/ukpga/2007/19/section/8
             https://legislation.gov.uk/ukpga/2007/19/section/13
             """ <> _ = result.popimar_article
    end

    test "article_popimar/1" do
      result = Popimar.article_popimar(@lat)
      # IO.inspect(result, label: "ARTICLE_POPIMAR")
      assert is_map(result)

      assert """
             https://legislation.gov.uk/ukpga/2007/19/crossheading/1
             Risk Control

             https://legislation.gov.uk/ukpga/2007/19/section/1
             Risk Control

             https://legislation.gov.uk/ukpga/2007/19/crossheading/2
             Aspects and Hazards; Maintenance, Examination and Testing; Organisation - Competence; Policy; Risk Control
             """ <> _ = result.article_popimar
    end
  end
end
