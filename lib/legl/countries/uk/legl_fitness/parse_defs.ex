defmodule Legl.Countries.Uk.LeglFitness.ParseDefs do
  @person [
            "individual",
            "(?:any other )?person at work",
            "master (?:or (?:a )?|and )crew of a (?:sea-going )?ship,? or to the employer of (?:such )?persons",
            "employer of (?:such )?persons",
            "persons who are not (?:his|its) employees",
            "persons who are not employees of that employer",
            "person other than a self-employed person or relevant self-employed person",
            "self-employed(?: person)?",
            "persons?",
            "people",
            "worker",
            "employees?",
            "employer",
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

  # Verbs linking the person to the process
  @person_verb [
                 "affected by",
                 "present",
                 "carried out by",
                 # phrasal verb 'exposed to'
                 "exposure to",
                 "engaged in",
                 "control to any extent of",
                 "supplied by him by way of sale, agreement for sale or hire-purchase agreement"
               ]
               |> Enum.join("|")

  def person_verb, do: @person_verb

  # Noun - subject of the process (use when there is another 'person' in the rule)
  @person_ii [
               "employer of (?:such )?persons",
               "employer",
               "person at work",
               "person under his control",
               "persons?"
             ]
             |> Enum.join("|")

  def person_ii, do: @person_ii

  # Verb & phrasal verbs - doing words
  @person_ii_verb [
                    "affected by",
                    "carried out by",
                    "uses or supervises or manages the use of"
                  ]
                  |> Enum.join("|")

  def person_ii_verb, do: @person_ii_verb

  # Nouns - the thing / subject of the rule
  @process [
             "work in compressed air which is construction work",
             "construction work",
             # A noun phrase
             "work activity",
             "work involves any of the relevant operations (?:in dock premises|in a shipyard)",
             "uses?d? at work",
             "work",
             "construction, reconstruction, alteration, repair, maintenance, cleaning, demolition and dismantling of any building or other structure not being a vessel",
             "passage through territorial waters",
             "diving (?:project|operation)",
             "normal ship-?board activities(?: of a ship's crew)?",
             "risk assessment",
             "fish loading"
           ]
           |> Enum.join("|")

  @standard_processes [
    "normal-ship-board-activities"
  ]
  def process, do: @process
  def standard_processes, do: @standard_processes

  @place [
           "construction site",
           "outside Great Britain",
           "Great Britain",
           "outside-gb",
           "territorial waters",
           "workplace on a construction site",
           "(?:work)?place (?:located )?below ground (?:at|in) a mine",
           "workplace located above ground at a mine that is a tip",
           "workplace which is or is in or on a ship",
           "workplace which is in fields, woods or other land forming part of an agricultural or forestry undertaking",
           "workplace which is or is in or on an aircraft, locomotive or rolling stock, trailer or semi-trailer used as a means of transport",
           "ship in dock premises",
           "(?:premises|workplace)"
         ]
         |> Enum.join("|")

  def place, do: @place

  # A noun - the thing / subject of the rule other than a person
  @plant [
           "vessels",
           "asbestos",
           "installation",
           "ship's work equipment",
           "work equipment"
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
              "at work",
              "indoors",
              # work on ships
              "carried out solely by (?:a ship's|the) crew under the direction of the master",
              "not liable to expose persons at work other than the master and crew to a risk to their safety"
            ]
            |> Enum.join("|")

  @standard_properties [
    "carried-out-solely-by-the-crew-under-the-direction-of-the-master"
  ]

  def property, do: @property
  def standard_properties, do: @standard_properties
end
