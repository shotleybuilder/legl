defmodule Legl.Countries.Uk.LeglArticle.Taxa.DutyTypeTest do
  # mix test test/legl/countries/uk/legl_article/taxa/duty_type_test.exs
  use ExUnit.Case
  # import Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib

  describe "DutyTypeLib.workflow/2" do
    test "process_amendment/1" do
      text = "Each employer shall—"
      result = DutyTypeLib.process_amendment(text)
      assert {text, {[], []}} == result
    end

    test "build_lib/2" do
      actors = ["Org: Employer"]
      governed = DutyholderLib.custom_dutyholders(actors, :governed)
      regexes = DutyTypeLib.build_lib(governed, &DutyTypeLib.duty/1)
      assert is_list(regexes)

      assert [
               "Org: Employer": [
                 {"(?:[ “][Ee]mployers?[ \\.,:;”\\]]).*?(?:shall be|is) liable", "Liability"},
                 {"(?:[ “][Ee]mployers?[ \\.,:;”\\]])shall not be (?:guilty|liable)",
                  "Defence, Appeal"},
                 {"(?:[ “][Ee]mployers?[ \\.,:;”\\]])[\\s\\S]*?it shall (?:also )?.*?be a defence",
                  "Defence, Appeal"},
                 {"[Nn]o(?:[ “][Ee]mployers?[ \\.,:;”\\]])shall", "Duty"},
                 {"(?:[Aa]n?|[Tt]he|Each)(?:[ “][Ee]mployers?[ \\.,:;”\\]]).*?must", "Duty"},
                 {"(?:[Aa]n?|[Tt]he|Each)(?:[ “][Ee]mployers?[ \\.,:;”\\]]).*?shall", "Duty"},
                 {"(?:[ “][Ee]mployers?[ \\.,:;”\\]])(?:shall notify|shall furnish the authority)",
                  "Duty"},
                 {"shall be the duty of any(?:[ “][Ee]mployers?[ \\.,:;”\\]])", "Duty"},
                 {"requiring a(?:[ “][Ee]mployers?[ \\.,:;”\\]]).*?to", "Duty"},
                 {"[Aa]pplication.*?shall be made to ?(?:the )?", "Duty"}
               ]
             ] = regexes

      # IO.inspect(regexes)
    end

    test "duty" do
      text = "Each employer shall—"

      textii =
        "4.—(1) Each employer shall—\n(a) so far as is reasonably practicable, avoid the need for his employees to undertake any manual handling operations at work which involve a risk of their being injured; or\n(b) where it is not reasonably practicable to avoid the need for his employees to undertake any manual handling operations at work which involve a risk of their being injured—\n(i) make a suitable and sufficient assessment of all such manual handling operations to be undertaken by them, having regard to the factors which are specified in column 1 of Schedule 1 to these Regulations and considering the questions which are specified in the corresponding entry in column 2 of that Schedule,\n(ii) take appropriate steps to reduce the risk of injury to those employees arising out of their undertaking any such manual handling operations to the lowest level reasonably practicable, and\n(iii) take appropriate steps to provide any of those employees who are undertaking any such manual handling operations with general indications and, where it is reasonably practicable to do so, precise information on—\n(aa) the weight of each load, and\n(bb) the heaviest side of any load whose centre of gravity is not positioned centrally."

      actors = ["Org: Employer"]

      result = DutyTypeLib.workflow(text, actors)
      assert {["Org: Employer"], ["Duty"]} == result

      result = DutyTypeLib.workflow(textii, actors)
      assert {["Org: Employer"], ["Duty"]} == result
    end
  end

  describe "DutyTypeLib.process_dutyholder" do
    test "Org: Employer duty" do
      text = "Each employer shall—"
      actors = ["Org: Employer"]
      duty_types = []
      governed = DutyholderLib.custom_dutyholders(actors, :governed)
      collector = {text, {[], duty_types}}
      library = DutyTypeLib.build_lib(governed, &DutyTypeLib.duty/1)
      result = DutyTypeLib.process_dutyholder(collector, library)
      assert {"—", {["Org: Employer"], ["Duty"]}} = result
      # IO.inspect(result)
    end
  end

  describe "DutyholderLib.custom_dutyholders" do
    test "Org: Employer" do
      actors = ["Org: Employer"]
      result = DutyholderLib.custom_dutyholders(actors, :governed)

      assert ["Org: Employer": {"[Ee]mployers?", "(?:[ “][Ee]mployers?[ \\.,:;”\\]])"}] = result
    end
  end

  describe "DutyholderLib.custom_dutyholder_library/2" do
    test "Org: Employer @governed" do
      result = DutyholderLib.custom_dutyholder_library(["Org: Employer"], :governed)
      assert ["Org: Employer": "[Ee]mployers?"] = result
      result = DutyholderLib.custom_dutyholders(["Org: Employer"], :government)
      assert [] = result
    end
  end

  @text """
  2.—(1) In these Regulations, unless the context otherwise requires—
  “injury” does not include injury caused by any toxic or corrosive substance which—
  (a) has leaked or spilled from a load;
  (b) is present on the surface of a load but has not leaked or spilled from it; or
  (c) is a constituent part of a load;
  and “injured” shall be construed accordingly;
  “load” includes any person and any animal;
  “manual handling operations” means any transporting or supporting of a load (including the lifting, putting down, pushing, pulling, carrying or moving thereof) by hand or by bodily force.
  """

  describe "DutyTypeLib.process_duty_types/1" do
    test "interpretation_definition" do
      collector = {@text, {[], []}}
      result = DutyTypeLib.process_duty_types(collector)
      assert {[], ["Interpretation, Definition"]} = result
      IO.inspect(result)
    end
  end

  describe "DutyTypeLib.process/2" do
    test "process/2 -> interpretation_definition" do
      regexes = DutyTypeLib.interpretation_definition()
      collector = {@text, {[], []}}
      result = DutyTypeLib.process(collector, regexes)
      assert {_text, {[], ["Interpretation, Definition"]}} = result
      IO.inspect(result)
    end
  end
end
