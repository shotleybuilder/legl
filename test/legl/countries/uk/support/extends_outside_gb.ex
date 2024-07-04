defmodule Legl.Countriess.Uk.Support.ExtendsOutsideGB do
  @moduledoc false
  @data [
    {
      %Legl.Countries.Uk.LeglFitness.Fitness{
        fit_id: "",
        record_id: "",
        lrt: [],
        lfrt: [],
        rule: %Legl.Countries.Uk.LeglFitness.Rule{
          record_id: "",
          rule:
            "These Regulations shall apply to and in relation to any activity outside Great Britain to which sections 1 to 59 and 80 to 82 of the Health and Safety at Work etc. Act 1974 apply by virtue of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2001 M8 as those provisions apply within Great Britain.",
          lrt: [],
          lft: [],
          heading: "extension outside great britain",
          scope: nil,
          provision_number: [],
          provision: []
        },
        category: "applies-to",
        ppp: "",
        pattern: ["<place>"],
        person: [],
        process: [],
        place: ["outside-great-britain"],
        person_verb: "",
        person_ii: "",
        person_ii_verb: "",
        property: "",
        plant: ""
      },
      result: %Legl.Countries.Uk.LeglFitness.Fitness{
        fit_id: "",
        record_id: "",
        lrt: [],
        lfrt: [],
        rule: %Legl.Countries.Uk.LeglFitness.Rule{
          record_id: "",
          rule:
            "These Regulations shall apply to and in relation to any activity outside Great Britain to which sections 1 to 59 and 80 to 82 of the Health and Safety at Work etc. Act 1974 apply by virtue of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2001 M8 as those provisions apply within Great Britain.",
          lrt: [],
          lft: [],
          heading: "extension outside great britain",
          scope: "Whole",
          provision_number: [],
          provision: []
        },
        category: "extends-to",
        ppp: "",
        pattern: ["<process>", "<place>"],
        person: [],
        process: ["activity"],
        place: ["outside-great-britain"],
        person_verb: "",
        person_ii: "",
        person_ii_verb: "",
        property: "",
        plant: ""
      }
    }
  ]

  def data(), do: @data
end
