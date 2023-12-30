defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGoverned do
  @doc """
  Function to tag sub-sections that impose a duty on persons other than
  government, regulators and agencies The function is a repository of phrases
  used to assign these duties. The phrases are joined together to form a valid
  regular expression.

  params.  Dutyholder should accommodate intial capitalisation eg [Pp]erson,
  [Ee]mployer

  Certain matches can take the third :true param to flag removal of the match
  from the text before further processing

  Employer SHALLs
    shall—
    shall adapt [any measure taken]
    shall apply [the following measures]
    shall assess [the levels of noise]
    shall avoid
    shall comply
    shall ensure [that|that—]
    shall keep [a suitable record|a copy of the plan]
    shall make [a suitable and sufficient assessment|personal hearing protectors available]
    shall not [permit|undertake]
    shall permit [him]
    shall provide [that]
    shall record|record—
    shall reduce [exposure]
    shall take [all reasonable steps]
    shall, {other text}, [ensure]

    actions taken by the employer ... shall be based on ...

  Pattern when a VERB precedes 'governed'
    shall be selected by the employer
    shall be reviewed by the employer who made it

  'Where' pattern
    Where [the|... an] employer ..., he [shall|may]
    e.g. Where the employer employs 5 or more employees, he shall record—
    e.g. Where a duty is placed by these Regulations on an employer in respect of his employees, he shall
    e.g. Where an employee or an employer is aggrieved by a decision recorded in the health record by a relevant doctor to suspend an employee ..., he may

  Employee SHALLs
    shall report
    shall make [full and proper use]
    shall, {other text}, [present himself]
  """
  @type regex :: String.t()
  @type duty_type :: String.t()
  @type remove? :: boolean()

  @spec duty(binary()) :: list({{regex(), remove?()}, duty_type()}) | list({regex(), duty_type()})
  def duty(governed) do
    duty_type = "Duty"

    exceptions =
      ~s/be carried out by|be construed|not apply|be suitable|be consulted|be notified|be informed|be appointed|be retained|include|be made|consist/

    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ](?:shall|must)", true},

      # MUST & SHALL
      # The subject and the modal verb are adjacent and are removed from further text processing
      {"(?:[Aa]n?y?|[Tt]he|[Ee]ach|[Ee]very)#{governed}(?:shall|must)[[:blank:][:punct:]—](?!#{exceptions})",
       true},

      # MUST
      # ?! is a negative lookahead
      "(?:[Aa]n?y?|[Tt]he|Each|[Ee]very|that|or)#{governed}.*?must[[:blank:][:punct:]—](?!#{exceptions})",

      # Pattern when there are dutyholder options and must starts on a new line
      "(?:[Aa]n?y?|[Tt]he|Each|[Ee]very|that|or) person(?s:.)*?^must (?!be carried out by)",
      "must be (?:carried out|reviewed|prepared).*?#{governed}",

      # SHALL
      "[Nn]o#{governed}(?:at work )?(?:shall|is to)",

      # Where the subject of the 'shall' is either not a 'governed' or another preceding 'governed'
      # e.g. "the employer of that employee shall—"
      # e.g. "Where, as a result of health surveillance, an employee is found to have an identifiable disease or adverse health effect which is considered by a relevant doctor or other occupational health professional to be the result of exposure to a substance hazardous to health the employer of that employee shall—"
      # e.g. "Personal protective equipment provided by an employer in accordance with this regulation shall be suitable for the purpose and shall—"
      # e.g. "the result of that review shall be notified to the employee and employer"
      # e.g. "Every employer who undertakes work which is liable to expose an employee to a substance hazardous to health shall provide that employee with suitable and sufficient information, instruction and training"
      "(?<!by|cost of)[ ](?:[Aa]n?y?|[Tt]he|[Ee]ach|[Ee]very)#{governed}(?!is found to|to a).*?shall[[:blank:][:punct:]—][ ]?(?!#{exceptions})",

      # regex101 (?:[Aa]n?y?|[Tt]he|[Ee]ach|[Ee]very) employee (?!is found to).*?shall[—]
      # e.g. "An employer who undertakes a fumigation to which this regulation applies shall ensure that"
      # e.g. "Every employer who undertakes work which is liable to expose an employee to a substance hazardous to health shall"
      # "(?:An?y?|The|Each|Every)#{governed}(?!is found to|to a).*?shall[[:blank:][:punct:]—](?!#{exceptions})",

      "#{governed}(?:shall notify|shall furnish the authority)",

      # SUBJECT 'governed' comes AFTER the VERB 'shall'
      # e.g. "These Regulations shall apply to a self-employed person as they apply to an employer and an employee"
      "shall apply to an?.*?#{governed} as they apply to",
      "shall be the duty of any#{governed}",
      "shall be (?:selected by|reviewed by) the#{governed}",
      "shall also be imposed on a#{governed}",
      # "[Aa]pplication.*?shall be made to ?(?:the )?",

      # OTHER VERBS
      "[Nn]o#{governed}may",
      "requiring a#{governed}.*?to",
      "#{governed}is.*?under a like duty",
      "#{governed}has taken all.*?steps",
      "Where a duty is placed.*?on an?#{governed}",
      "provided by an?#{governed}"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
    |> (&Kernel.++(&1, duty_like(governed))).()
  end

  defp duty_like(governed),
    do: [
      {"#{governed}.*?(?:shall be|is) liable (?!to)", "Liability"},
      {"#{governed}shall not be (?:guilty|liable)", "Defence, Appeal"},
      {"#{governed}[\\s\\S]*?it shall (?:also )?.*?be a defence", "Defence, Appeal"}
    ]

  def right(governed) do
    duty_type = "Right"

    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ]may", true},

      # SUBJECT after the VERB
      "requested by a#{governed}",
      # e.g. "the result of that review shall be notified to the employee and employer"
      "shall (?:be notified to the|consult).*?#{governed}",

      # MAY
      # Uses a negative lookbehind (?<!element)
      "#{governed}.*?(?<!which|who)[ ]may[[:blank:][:punct:]][ ]?(?!need|have|require|be[ ])",
      "#{governed}.*?shall be entitled",
      "permission of that#{governed}",
      "#{governed}.*?is not required"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
    |> (&Kernel.++(&1, right_like(governed))).()
  end

  defp right_like(governed),
    do: [
      {"#{governed}may.*?, but may not", ["Duty", "Right"]},
      {"#{governed}.*?may appeal", ["Right", "Defence, Appeal"]},
      {"[Ii]t is a defence for a #{governed}", "Defence, Appeal"}
    ]
end
