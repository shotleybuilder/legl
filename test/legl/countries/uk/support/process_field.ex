defmodule Legl.Countries.Uk.Support.ProcessField do
  @moduledoc false

  @data [
    %{
      test: %Legl.Countries.Uk.LeglFitness.Fitness{
        fit_id: "",
        record_id: "",
        lrt: [],
        lfrt: [],
        rule: %Legl.Countries.Uk.LeglFitness.Rule{
          record_id: "",
          rule:
            "The duties of the employer under regulation 10 (medical surveillance) shall extend to employees of another employer who are working under the direction of the first-mentioned employer.",
          lrt: [],
          lft: [],
          heading: "duties under these regulations",
          scope: nil,
          provision_number: ["10"],
          provision: ["medical-surveillance"]
        },
        category: "applies-to",
        ppp: "",
        pattern: ["<person>", "<process>"],
        person: ["employees"],
        process: ["work"],
        place: [],
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
            "The duties of the employer under regulation 10 (medical surveillance) shall extend to employees of another employer who are working under the direction of the first-mentioned employer.",
          lrt: [],
          lft: [],
          heading: "duties under these regulations",
          scope: nil,
          provision_number: ["10"],
          provision: ["medical-surveillance"]
        },
        category: "applies-to",
        ppp: "",
        pattern: ["<provision>", "<person>", "<process>"],
        person: ["employees"],
        process: ["work"],
        place: [],
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
