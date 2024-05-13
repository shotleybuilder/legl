defmodule Legl.Countries.Uk.LeglFitness.ParseDefs do
  @person [
            "individual",
            "(?:any other )?person at work",
            "master or (?:a )?crew of a (?:sea-going )?ship or to the employer of such persons",
            "employer of persons",
            "persons who are not (?:his|its) employees",
            "persons who are not employees of that employer",
            "persons?",
            "people",
            "worker",
            "employees?",
            "employer",
            "self-employed",
            "self employed",
            "self-employment",
            "self employment",
            "contractor",
            "sub-contractor",
            "subcontractor",
            "sub contractor",
            "agency worker",
            "agency-worker",
            "agency"
          ]
          |> Enum.join("|")

  def person, do: @person

  # Noun - subject of the process (use when there is another 'person' in the rule)
  @person_ii [
               "employer",
               "person at work",
               "persons?"
             ]
             |> Enum.join("|")

  def person_ii, do: @person_ii

  # Verbs linking the person to the process
  @person_verb [
                 "affected by",
                 "present",
                 "carried out by",
                 # phrasal verb 'exposed to'
                 "exposure to"
               ]
               |> Enum.join("|")

  def person_verb, do: @person_verb

  # Verb & phrasal verbs - doing words
  @person_ii_verb [
                    "affected by",
                    "carried out by"
                  ]
                  |> Enum.join("|")

  def person_ii_verb, do: @person_ii_verb

  # Nouns - the thing / subject of the rule
  @process [
             "construction work",
             # A noun phrase
             "work activity",
             "work",
             "construction, reconstruction, alteration, repair, maintenance, cleaning, demolition and dismantling of any building or other structure not being a vessel",
             "passage through territorial waters",
             "diving project",
             "normal ship-?board activities(?: of a ship's crew which are)? carried out solely by (?:a ship's|the) crew under the direction of the master",
             "risk assessment"
           ]
           |> Enum.join("|")

  def process, do: @process

  @place [
           "construction site",
           "outside-gb",
           "territorial waters",
           "workplace on a construction site",
           "place below ground in a mine",
           "ship in dock premises",
           "(?:premises|workplace)"
         ]
         |> Enum.join("|")

  def place, do: @place

  # A noun - the thing / subject of the rule other than a person
  @plant [
           "vessels",
           "asbestos"
         ]
         |> Enum.join("|")

  def plant, do: @plant

  # Property of the plant, place or process
  @property [
              "registered outside the United Kingdom",
              "set aside for purposes other than",
              "where the work is (?:being )?carried out",
              "sporadic and of low intensity",
              "fighting a fire or in an emergency",
              "whether at work or not",
              "at work"
            ]
            |> Enum.join("|")

  def property, do: @property
end
