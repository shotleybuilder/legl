defmodule Legl.Countries.Uk.Support.LeglFitnessProvisionTest do
  @moduledoc false

  alias alias Legl.Countries.Uk.LeglFitness.Rule

  @data [
    {
      %Rule{
        rule: "These regulations shall not apply to a workplace which is or is in or on a ship"
      },
      result: []
    },
    {
      %Rule{rule: "Regulation 20 applies"},
      result: ["20"]
    },
    {
      %Rule{
        rule: "Regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to a"
      },
      result: ["7(1A)", "12", "14", "15", "16", "18", "19", "26(1)"]
    },
    {
      %Rule{rule: "Regulations 18 and 25A apply to a"},
      result: ["18", "25A"]
    },
    {
      %Rule{
        rule: "Regulations 8(1) and (3) and 12(1) and (3) apply to a"
      },
      result: ["8(1)", "8(3)", "12(1)", "12(3)"]
    },
    {%Rule{rule: "Regulation 13 shall apply to a"}, result: ["13"]},
    {%Rule{
       rule: "Regulations 5 to 7 and 14 to 20 shall not apply to a"
     }, result: ["5", "6", "7", "14", "15", "16", "17", "18", "19", "20"]},
    {%Rule{
       rule:
         "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply"
     }, result: ["9", "18(1)(a)", "22"]},
    {%Rule{
       rule:
         "The duties of the employer under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees."
     }, result: ["9", "11(1)", "11(2)", "12"]},
    {%Rule{
       rule:
         "As respects any workplace which is in fields, woods or other land forming part of an agricultural or forestry undertaking but which is not inside a building and is situated away from the undertaking's main buildings any requirement to ensure that any such workplace complies with any of regulations 20 to 22 shall have effect as a requirement to so ensure so far as is reasonably practicable."
     }, result: ["20", "21", "22"]}
  ]

  def data(), do: @data
end
