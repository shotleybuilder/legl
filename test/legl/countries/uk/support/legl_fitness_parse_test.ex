defmodule Legl.Countries.Uk.Support.LeglFitnessParseTest do
  @moduledoc false
  alias Legl.Countries.Uk.LeglFitness

  @data [
    # PERSON_II PROPERTY PERSON_II_VERB PROCESS PERSON_VERB PERSON
    %{
      test: %LeglFitness.Fitness{
        category: "applies-to",
        rule: %LeglFitness.Rule{
          rule:
            "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer except that the duties of the employer— ",
          provision: []
        }
      },
      result: %LeglFitness.Fitness{
        pattern: [
          "<person_ii>",
          "<property>",
          "<person_ii_verb>",
          "<process>",
          "<person_verb>",
          "<person>"
        ],
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
        rule: %LeglFitness.Rule{
          rule:
            "Where a duty is placed by these Regulations on an employer in respect of its employees, the employer must, so far as is reasonably practicable, be under a like duty in respect of any other person at work who may be affected by the work carried out by the employer.",
          provision: []
        }
      },
      result: %LeglFitness.Fitness{
        pattern: [
          "<person_ii>",
          "<property>",
          "<person_ii_verb>",
          "<process>",
          "<person_verb>",
          "<person>"
        ],
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
        rule: %LeglFitness.Rule{
          rule:
            "Information and training does extend to those persons are present in the workplace where the work is being carried out.",
          provision: ["information", "training"]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person>", "<person_verb>", "<place>", "<property>"],
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
        rule: %LeglFitness.Rule{
          rule:
            "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where the exposure to asbestos of employees is sporadic and of low intensity.",
          provision: [
            "notification-of-work-with-asbestos",
            "designated-areas",
            "health-records",
            "medical-surveillance"
          ]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person_verb>", "<plant>", "<person>", "<property>"],
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
        rule: %LeglFitness.Rule{
          rule:
            "Notification of work with asbestos, designated areas, health records, medical surveillance do not apply where it is clear from the risk assessment that the exposure to asbestos of any employee will not exceed the control limit.",
          provision: [
            "notification-of-work-with-asbestos",
            "designated-areas",
            "health-records",
            "medical-surveillance"
          ]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<process>", "<person_verb>", "<plant>", "<person>"],
        process: ["risk-assessment"],
        person_verb: "exposure-to",
        plant: "asbestos",
        person: ["employee"],
        property: nil
      }
    },
    # PERSON PLACE PROPERTY
    %{
      test: %LeglFitness.Fitness{
        category: "applies-to",
        rule: %LeglFitness.Rule{
          rule:
            "Information, instruction and training does extend to those persons are on the premises where the work is being carried out.",
          provision: ["information", "instruction", "training"]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person>", "<place>", "<property>"],
        person: ["person"],
        place: ["premises"],
        property: "where-the-work-is-being-carried-out"
      }
    },
    # PERSON ONLY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule: "Health surveillance do not extend to persons who are not its employees.",
          provision: ["health-surveillance"]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person>"],
        person: ["x-employee"]
      }
    },
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "Health records and medical surveillance do not extend to persons who are not employees of that employer.",
          provision: ["health-records", "medical-surveillance"]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person>"],
        person: ["x-employee"]
      }
    },
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule: "Information and training do not extend to persons who are not its employees.",
          provision: ["information", "training"]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person>"],
        person: ["x-employee"]
      }
    },
    # PROCESS ONLY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "These Regulations shall not apply to or in relation to any diving project to and in relation to which the Diving at Work Regulations 1997 apply by virtue of regulation 3 of those Regulations.",
          provision: []
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<process>"],
        process: ["diving-project"]
      }
    },
    # PLACE PROPERTY PROCESS
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "These Regulations shall not apply to any workplace on a construction site which is set aside for purposes other than construction work.",
          provision: []
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<place>", "<property>", "<process>"],
        place: ["workplace-on-a-construction-site"],
        property: "set-aside-for-purposes-other-than",
        process: ["construction-work"]
      }
    },
    # PLACE ONLY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "These Regulations shall not apply to or in relation to any place below ground in a mine.",
          provision: []
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<place>"],
        place: ["place-below-ground-in-a-mine"]
      }
    },
    %{
      test: %LeglFitness.Fitness{
        category: "applies-to",
        rule: %LeglFitness.Rule{
          rule:
            "These Regulations shall apply outside Great Britain as sections 1 to 59 and 80 to 82 of the 1974 Act apply by virtue of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2001 M3."
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<place>"],
        category: "applies-to",
        place: ["great-britain"]
      }
    },
    # PLANT & PROCESS
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "Subject to paragraphs (7) to (10), these Regulations shall not impose any obligation in relation to a ship's work equipment (whether that equipment is used on or off the ship)."
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<plant>", "<process>"],
        plant: "ship's-work-equipment",
        process: ["used-on-the-ship", "used-off-the-ship"]
      }
    },
    # PERSON PLACE PROPERTY
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "Cleanliness of premises, cleanliness of plant, to the extent that it requires an employer to ensure that premises are thoroughly cleaned, does not apply to the employer of persons who attend a ship in dock premises for the purpose of fighting a fire or in an emergency, in respect of any ship so attended",
          provision: ["cleanliness-of-premises", "cleanliness-of-plant"]
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person>", "<place>", "<property>"],
        person: ["employer-of-persons"],
        place: ["ship-in-dock-premises"],
        property: "fighting-a-fire-or-in-an-emergency"
      }
    },
    # PERSON PROCESS
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "These Regulations shall not apply to or in relation to the master or crew of a sea-going ship or to the employer of such persons in respect of the normal ship-board activities carried out solely by a ship's crew under the direction of the master."
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<person>", "<process>", "<property>"],
        person: ["master-of-a-ship", "crew-of-a-ship", "employer-of-such-persons"],
        process: [
          "normal-ship-board-activities"
        ],
        property: "carried-out-solely-by-the-crew-under-the-direction-of-the-master"
      }
    },

    # PLANT PROPERTY PROCESS
    %{
      test: %LeglFitness.Fitness{
        category: "disapplies-to",
        rule: %LeglFitness.Rule{
          rule:
            "These Regulations shall not apply to vessels which are registered outside the United Kingdom and are on passage through territorial waters."
        }
      },
      result: %LeglFitness.Fitness{
        pattern: ["<plant>", "<property>", "<process>"],
        plant: "vessels",
        property: "registered-outside-the-united-kingdom",
        process: ["passage-through-territorial-waters"]
      }
    },
    %{
      test: %LeglFitness.Fitness{category: "disapplies-to", rule: %LeglFitness.Rule{}},
      result: %{
        unmatched_fitness: %Legl.Countries.Uk.LeglFitness.Fitness{
          record_id: nil,
          lrt: [],
          rule: %LeglFitness.Rule{},
          category: "disapplies-to",
          pattern: [],
          person: [],
          process: [],
          place: [],
          person_verb: nil,
          person_ii: nil,
          person_ii_verb: nil,
          property: nil,
          plant: nil
        }
      }
    }
  ]

  def data(), do: @data
end
