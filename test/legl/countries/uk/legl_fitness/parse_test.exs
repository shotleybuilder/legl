defmodule Legl.Countries.Uk.LeglFitness.ParseTest do
  # mix test test/legl/countries/uk/legl_fitness/parse_test.exs:8
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness

  test "regex_printer/1" do
    index = 0

    LeglFitness.Parse.regex_printer(index)
    |> IO.inspect(label: "Regex")
  end

  @disapplies [
    # PERSON_II PROPERTY PERSON_II_VERB PROCESS PERSON_VERB PERSON
    %{
      test: %LeglFitness.Fitness{
        category: "applies-to",
        provision: [],
        rule:
          "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer except that the duties of the employer— "
      },
      result: %LeglFitness.Fitness{
        provision: [],
        person: ["employer"],
        property: "whether-at-work-or-not",
        person_verb: "carried-out-by",
        process: ["work-activity"],
        person_ii_verb: "affected-by",
        person_ii: "person"
      }
    },
    # PERSON_II PERSON_II_VERB PROCESS PERSON_VERB PERSON
    %{
      test: %LeglFitness.Fitness{
        category: "applies-to",
        provision: [],
        rule:
          "Where a duty is placed by these Regulations on an employer in respect of its employees, the employer must, so far as is reasonably practicable, be under a like duty in respect of any other person at work who may be affected by the work carried out by the employer."
      },
      result: %LeglFitness.Fitness{
        provision: [],
        person: ["employer"],
        property: "at-work",
        person_verb: "carried-out-by",
        process: ["work"],
        person_ii_verb: "affected-by",
        person_ii: "person"
      }
    },

    # PROCESS PERSON PERSON_PROCESS PLACE PROPERTY
    %{
      test: %LeglFitness.Fitness{
        category: "applies-to",
        provision: ["information", "training"],
        rule:
          "Information and training does extend to those persons are present in the workplace where the work is being carried out."
      },
      result: %LeglFitness.Fitness{
        provision: ["information", "training"],
        person: ["person"],
        person_verb: "present",
        place: ["workplace"],
        property: "where-the-work-is-being-carried-out"
      }
    },
    # PROCESS PLANT PERSON PROPERTY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        provision: [
          "notification-of-work-with-asbestos",
          "designated-areas",
          "health-records",
          "medical-surveillance"
        ],
        rule:
          "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where the exposure to asbestos of employees is sporadic and of low intensity."
      },
      result: %LeglFitness.Fitness{
        provision: [
          "notification-of-work-with-asbestos",
          "designated-areas",
          "health-records",
          "medical-surveillance"
        ],
        person_verb: "exposure-to",
        plant: "asbestos",
        person: ["employees"],
        property: "sporadic-and-of-low-intensity"
      }
    },
    # PROCESS PERSON_VERB PLANT PERSON
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        provision: [
          "notification-of-work-with-asbestos",
          "designated-areas",
          "health-records",
          "medical-surveillance"
        ],
        rule:
          "Notification of work with asbestos, designated areas, health records, medical surveillance do not apply where it is clear from the risk assessment that the exposure to asbestos of any employee will not exceed the control limit."
      },
      result: %LeglFitness.Fitness{
        provision: [
          "notification-of-work-with-asbestos",
          "designated-areas",
          "health-records",
          "medical-surveillance"
        ],
        process: ["risk-assessment"],
        person_verb: "exposure-to",
        plant: "asbestos",
        person: ["employee"],
        property: nil
      }
    },
    # PROCESS PERSON PLACE PROPERTY
    %{
      test: %LeglFitness.Fitness{
        category: "applies-to",
        provision: ["information", "instruction", "training"],
        rule:
          "Information, instruction and training does extend to those persons are on the premises where the work is being carried out."
      },
      result: %LeglFitness.Fitness{
        provision: ["information", "instruction", "training"],
        person: ["person"],
        place: ["premises"],
        property: "where-the-work-is-being-carried-out"
      }
    },

    # PROCESS PERSON
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        provision: ["health-surveillance"],
        rule: "Health surveillance do not extend to persons who are not its employees."
      },
      result: %LeglFitness.Fitness{
        provision: ["health-surveillance"],
        person: ["x-employee"]
      }
    },
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        provision: ["health-records", "medical-surveillance"],
        rule:
          "Health records and medical surveillance do not extend to persons who are not employees of that employer."
      },
      result: %LeglFitness.Fitness{
        person: ["x-employee"],
        provision: ["health-records", "medical-surveillance"]
      }
    },
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        provision: ["information", "training"],
        rule: "Information and training do not extend to persons who are not its employees."
      },
      result: %LeglFitness.Fitness{
        provision: ["information", "training"],
        person: ["x-employee"]
      }
    },
    # PROCESS ONLY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule:
          "These Regulations shall not apply to or in relation to any diving project to and in relation to which the Diving at Work Regulations 1997 apply by virtue of regulation 3 of those Regulations."
      },
      result: %LeglFitness.Fitness{
        process: ["diving-project"]
      }
    },
    # PLACE PROPERTY PROCESS
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule:
          "These Regulations shall not apply to any workplace on a construction site which is set aside for purposes other than construction work."
      },
      result: %LeglFitness.Fitness{
        place: ["workplace-on-a-construction-site"],
        property: "set-aside-for-purposes-other-than",
        process: ["construction-work"]
      }
    },
    # PLACE ONLY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule:
          "These Regulations shall not apply to or in relation to any place below ground in a mine."
      },
      result: %LeglFitness.Fitness{
        place: ["place-below-ground-in-a-mine"]
      }
    },
    # PERSON PLACE PROPERTY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        provision: ["cleanliness-of-premises", "cleanliness-of-plant"],
        rule:
          "Cleanliness of premises, cleanliness of plant, to the extent that it requires an employer to ensure that premises are thoroughly cleaned, does not apply to the employer of persons who attend a ship in dock premises for the purpose of fighting a fire or in an emergency, in respect of any ship so attended"
      },
      result: %LeglFitness.Fitness{
        provision: ["cleanliness-of-premises", "cleanliness-of-plant"],
        person: ["employer-of-persons"],
        place: ["ship-in-dock-premises"],
        property: "fighting-a-fire-or-in-an-emergency"
      }
    },
    # PERSON PROCESS
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule:
          "These Regulations shall not apply to or in relation to the master or crew of a sea-going ship or to the employer of such persons in respect of the normal ship-board activities carried out solely by a ship's crew under the direction of the master."
      },
      result: %LeglFitness.Fitness{
        person: ["master", "crew-of-a-sea-going-ship", "to-the-employer-of-such-persons"],
        process: [
          "normal-ship-board-activities-carried-out-solely-by-a-ship's-crew-under-the-direction-of-the-master"
        ]
      }
    },

    # PLANT PROPERTY PROCESS
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule:
          "These Regulations shall not apply to vessels which are registered outside the United Kingdom and are on passage through territorial waters."
      },
      result: %LeglFitness.Fitness{
        plant: "vessels",
        property: "registered-outside-the-united-kingdom",
        process: ["passage-through-territorial-waters"]
      }
    },
    %{
      test: %LeglFitness.Fitness{category: "disapplies-to", rule: ""},
      result: %{unmatched_text: ""}
    }
  ]

  test "api_parse/1" do
    Enum.each(@disapplies, fn %{test: test, result: result} ->
      result =
        if test.rule == "",
          do: result,
          else: Map.merge(result, %{category: test.category, rule: test.rule})

      assert ^result = LeglFitness.Parse.api_parse(test) |> List.first()
    end)
  end
end
