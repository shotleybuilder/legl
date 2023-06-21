defmodule Lgl.Countries.Uk.AtDutyTypeTaxa.DutyTypeTest do
  # mix test test/legl/countries/uk/at_duty_type_taxa/duty_type_test.exs
  use ExUnit.Case
  import Legl.Countries.Uk.AtDutyTypeTaxa.DutyType
  import Legl.Countries.Uk.AtDutyTypeTaxa.DutyTypeLib

  @text ~s/the person carrying it on must use the best available techniques not entailing excessive cost/

  test "regex/1" do
    result = regex(:interpretation_definition)

    assert result ==
             ~r/([a-z]” (means|includes|is the|are|to be read as|are references to|consists)[ —,]| has?v?e? the (?:same )?meanings? | [Ff]or the purpose of determining | any reference in this .*?to | interpretation | [Ff]or the purposes of.*?(Part|Chapter|[sS]ection|subsection))/
  end

  test "duty_type?/1" do
    result = duty_type?(@text)
    assert result == %{tag: "Interpretation, Definition"}
  end
end
