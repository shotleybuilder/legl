defmodule Legl.Countries.Uk.LeglArticle.Taxa.DutyActorTest do
  # mix test test/legl/countries/uk/legl_article/taxa/duty_actor_test.exs
  use ExUnit.Case

  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyActor.DutyActor
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib

  describe "DutyActor.process/1" do
  end

  @text "4.—(1) Each employer shall—\n(a) so far as is reasonably practicable, avoid the need for his employees to undertake any manual handling operations at work which involve a risk of their being injured; or\n(b) where it is not reasonably practicable to avoid the need for his employees to undertake any manual handling operations at work which involve a risk of their being injured—\n(i) make a suitable and sufficient assessment of all such manual handling operations to be undertaken by them, having regard to the factors which are specified in column 1 of Schedule 1 to these Regulations and considering the questions which are specified in the corresponding entry in column 2 of that Schedule,\n(ii) take appropriate steps to reduce the risk of injury to those employees arising out of their undertaking any such manual handling operations to the lowest level reasonably practicable, and\n(iii) take appropriate steps to provide any of those employees who are undertaking any such manual handling operations with general indications and, where it is reasonably practicable to do so, precise information on—\n(aa) the weight of each load, and\n(bb) the heaviest side of any load whose centre of gravity is not positioned centrally."

  describe "DutyholderLib.workflow" do
    test "workflow/2" do
      result = DutyholderLib.workflow(@text, :"Duty Actor")
      assert [:"Ind: Employee", :"Org: Employer"] = result
      IO.inspect(result)
    end

    test "process/2" do
      result = DutyholderLib.process({@text, []}, DutyholderDefinitions.governed(), true)
      assert {text, [:"Ind: Employee", :"Org: Employer"]} = result
      # IO.inspect(result)
    end
  end
end
