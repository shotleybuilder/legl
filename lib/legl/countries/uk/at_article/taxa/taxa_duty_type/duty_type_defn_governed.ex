defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGoverned do
  @moduledoc """
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

  defp determiners(), do: ~s/(?:[Aa]n?y?|[Tt]he|[Ee]ach|[Ee]very|[Ee]ach such|[Tt]hat|,)/

  defp neg_lookbehind(),
    do:
      ~s/(?<! by | of |send it to |given |appointing | to expose | to whom | to pay | to permit )/

  @spec duty(binary()) :: list({{regex(), remove?()}, duty_type()}) | list({regex(), duty_type()})
  def duty(governed) do
    duty_type = "Duty"

    modals = ~s/(?:shall|must|may[ ]only|may[ ]not)/

    determiners = determiners()

    # 'of' might create problems ...
    neg_lookbehind = neg_lookbehind()

    # and has to be added to parse e.g.
    # "Every employer and every self-employed person shall"
    neg_lookbehind_rm = String.trim_trailing(neg_lookbehind, ")") <> ~s/|and )/

    # Qualifies and excludes the 'governed' based on text immediately after
    # e.g. "person who is responsible for appointing a designer or contractor to carry out"
    # The 'contractor' is excluded
    mid_neg_lookahead = ~s/(?!is found to |is likely to |to a |to carry |to assess |to analyse )/

    #  These have to be literals for the lookahead to work
    eds =
      ~s/be construed|be consulted|be notified|be informed|be appointed|be retained|be included|be extended|be treated|be necessary/

    neg_lookahead =
      ~s/(?!be carried out by|#{eds}|not apply|be suitable|include|be made|consist|have effect|apply)/

    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ]#{modals}", true},

      # MUST & SHALL w/ REMOVAL
      # The subject and the modal verb are adjacent and are removed from further text processing
      {"#{neg_lookbehind_rm}#{determiners}#{governed}#{modals}[[:blank:][:punct:]—]#{neg_lookahead}",
       true},

      # SHALL - MUST - MAY ONLY - MAY NOT

      "#{modals} be (?:carried out|reviewed|prepared).*?#{governed}",

      # Pattern when there are dutyholder options and MODALS start on a new line
      "(?:[Aa]n?y?|[Tt]he|Each|[Ee]very|that|or) person(?s:.)*?^#{modals} (?!be carried out by)",

      # Pattern when the 'governed' start on a new line
      "#{modals} be carried out by—$[\\s\\S]*?#{governed}",

      #
      "[Nn]o#{governed}(?:at work )?(?:shall|is to)",

      # Where the subject of the 'shall' is either not a 'governed' or another preceding 'governed'
      # e.g. "the employer of that employee shall—"
      # e.g. "Where, as a result of health surveillance, an employee is found to have an identifiable disease or adverse health effect which is considered by a relevant doctor or other occupational health professional to be the result of exposure to a substance hazardous to health the employer of that employee shall—"
      # e.g. "Personal protective equipment provided by an employer in accordance with this regulation shall be suitable for the purpose and shall—"
      # e.g. "the result of that review shall be notified to the employee and employer"
      # e.g. "Every employer who undertakes work which is liable to expose an employee to a substance hazardous to health shall provide that employee with suitable and sufficient information, instruction and training"
      "#{neg_lookbehind}#{determiners}#{governed}#{mid_neg_lookahead}(?:[^,]*?|.*?he )#{modals}[[:blank:][:punct:]—][ ]?#{neg_lookahead}",

      # When the subject precedes and then gets referred to as 'he'
      # e.g. competent person referred to in paragraph (3) is the user ... or owner ... shall not apply, but he shall
      "#{governed}#{mid_neg_lookahead}[^—\\.]*?he[ ]shall",
      #
      # e.g. "An employer who undertakes a fumigation to which this regulation applies shall ensure that"
      # e.g. "Every employer who undertakes work which is liable to expose an employee to a substance hazardous to health shall"

      "#{governed}(?:shall notify|shall furnish the authority)",

      # SUBJECT 'governed' comes AFTER the VERB 'shall'
      # e.g. "These Regulations shall apply to a self-employed person as they apply to an employer and an employee"
      "shall apply to a.*?#{governed}.*?as they apply to",
      "shall be the duty of any#{governed}",
      "shall be (?:selected by|reviewed by) the#{governed}",
      "shall also be imposed on a#{governed}",
      # "[Aa]pplication.*?shall be made to ?(?:the )?",

      # OTHER VERBS
      "[Nn]o#{governed}may",
      "#{governed}may[ ](?:not|only)",
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
    # duty_type = "Right"

    determiners = determiners()

    neg_lookbehind = neg_lookbehind()

    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ]may", true},

      # SUBJECT after the VERB
      "requested by a#{governed}",
      # e.g. "the result of that review shall be notified to the employee and employer"
      "(?:shall|must) (?:be notified to the|consult).*?#{governed}",
      # e.g. may be presented to the CAC by a relevant applicant
      "may be presented.*?by an?#{governed}",

      # MAY
      # Does not include 'MAY NOT' and 'MAY ONLY' which are DUTIES
      # Uses a negative lookbehind (?<!element)
      {"#{governed}may[[:blank:][:punct:]][ ]?(?!exceed|need|have|require|be[ ]|not|only)", true},
      "#{neg_lookbehind}#{determiners}#{governed}.*?(?<!which|who)[ ]may[[:blank:][:punct:]][ ]?(?!need|have|require|be[ ]|not|only)",
      "#{governed}.*?shall be entitled",
      "permission of that#{governed}",
      "#{governed}.*?is not required",
      "#{governed}may.*?, but may not"
    ]

    # |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end
end
