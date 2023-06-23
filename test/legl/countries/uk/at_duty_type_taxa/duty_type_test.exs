defmodule Lgl.Countries.Uk.AtDutyTypeTaxa.DutyTypeTest do
  # mix test test/legl/countries/uk/at_duty_type_taxa/duty_type_test.exs
  use ExUnit.Case
  import Legl.Countries.Uk.AtDutyTypeTaxa.DutyType
  import Legl.Countries.Uk.AtDutyTypeTaxa.DutyTypeLib

  @text ~s/"(2) Regulations under subsection (1) above may frame the description of a process by reference to any characteristics of the process or the area or other circumstances in which the process is carried on or the description of person carrying it on."/

  test "regex/1" do
    result = regex(:interpretation_definition)

    assert result ==
             ~r/([a-z]” (means|includes|is the|are|to be read as|are references to|consists)[ —,]| has?v?e? the (?:same )?meanings? | [Ff]or the purpose of determining | any reference in this .*?to | interpretation )/

    result = regex(:exemption)

    assert result ==
             ~r/( shall not apply to (Scotland|Wales|Northern Ireland)| shall not apply in any case where[, ]| [Pp]erson|[Hh]older shall not be liable)/
  end

  test "duty_type?/1" do
    result = duty_type?(@text)
    assert result == %{tag: "Interpretation, Definition"}
  end
end
