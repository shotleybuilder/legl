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

  defp determiners(), do: ~s/(?:[Aa]n?y?|[Tt]he|[Ee]ach|[Ee]very|[Ee]ach such|[Tt]hat|[Nn]ew|,)/

  defp modals, do: ~s/(?:shall|must|may[ ]only|may[ ]not)/

  defp neg_lookbehind(),
    do:
      ~s/(?<! by | of |send it to |given |appointing | to expose | to whom | to pay | to permit |before which )/

  defp mid_neg_lookahead,
    do: ~s/(?!is found to |is likely to |to a |to carry |to assess |to analyse|to perform )/

  defp eds,
    do:
      ~s/be entitled|be carried out by|be construed|be consulted|be notified|be informed|be appointed|be retained|be included|be extended|be treated|be necessary|be subjected|be suitable|be made/

  defp neg_lookahead, do: ~s/(?!#{eds()}|not apply|consist|have effect|apply)/

  defp emdash, do: <<226, 128, 148>>

  def duty_pattern(governed),
    do:
      "#{neg_lookbehind()}#{determiners()}#{governed}#{mid_neg_lookahead()}.*?#{modals()}[[:blank:][:punct:]#{emdash()}][ ]?#{neg_lookahead()}"

  # e.g. "Generators and distributors shall take"
  def no_determiner_pattern(governed),
    do:
      "#{governed}#{mid_neg_lookahead()}.*?#{modals()}[[:blank:][:punct:]#{emdash()}][ ]?#{neg_lookahead()}"

  def responsible_for_pattern(governed),
    do:
      "#{governed}#{mid_neg_lookahead()}.*?(?:remains|is) (?:responsible|financially liable) for"

  @spec duty(binary()) :: list({{regex(), remove?()}, duty_type()}) | list({regex(), duty_type()})
  def duty("[[:blank:][:punct:]“][Hh]e[[:blank:][:punct:]”]" = governed) do
    modals = modals()
    # There is no determiner for 'he'
    # A 'wash-up' after all other alts
    [{"#{governed}#{modals}", true}]
  end

  def duty(governed) do
    # duty_type = "Duty"

    emdash = emdash()

    modals = modals()

    determiners = determiners()

    # 'of' might create problems ...
    neg_lookbehind = neg_lookbehind()

    # and has to be added to parse e.g.
    # "Every employer and every self-employed person shall"
    neg_lookbehind_rm = String.trim_trailing(neg_lookbehind, ")") <> ~s/|and )/

    # Qualifies and excludes the 'governed' based on text immediately after
    # e.g. "person who is responsible for appointing a designer or contractor to carry out"
    # The 'contractor' is excluded
    mid_neg_lookahead = mid_neg_lookahead()

    #  These have to be literals for the lookahead to work
    neg_lookahead = neg_lookahead()

    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ]#{modals}", true},

      # MUST & SHALL w/ REMOVAL
      # The subject and the modal verb are adjacent and are removed from further text processing
      {"#{neg_lookbehind_rm}#{determiners}#{governed}#{modals}[[:blank:][:punct:]#{emdash}]#{neg_lookahead}",
       true},

      # SHALL - MUST - MAY ONLY - MAY NOT

      "#{modals} be (?:carried out|reviewed|prepared).*?#{governed}",

      # Pattern when the 'governed' start on a new line
      "#{modals} be (?:affixed|carried out) by—$[\\s\\S]*?#{governed}",

      # Pattern when there are dutyholder options and MODALS start on a new line
      # s modifier: single line. Dot matches newline characters
      "#{determiners}#{governed}(?s:.)*?^#{modals} (?!be carried out by)",
      #
      "[Nn]o#{governed}(?:at work )?(?:shall|is to)",
      #
      duty_pattern(governed),
      no_determiner_pattern(governed),

      # When the subject precedes and then gets referred to as 'he'
      # e.g. competent person referred to in paragraph (3) is the user ... or owner ... shall not apply, but he shall
      "#{governed}#{mid_neg_lookahead}[^#{emdash}\\.]*?he[ ]shall",

      # SUBJECT 'governed' comes AFTER the VERB 'shall'
      # e.g. "These Regulations shall apply to a self-employed person as they apply to an employer and an employee"
      "shall apply to a.*?#{governed}.*?as they apply to",
      "shall be the duty of #{determiners}#{governed}",
      "shall be the duty of the.*?and of #{determiners}#{governed}",
      "shall be (?:selected by|reviewed by|given.*?by) the#{governed}",
      "shall also be imposed on a#{governed}",
      # "[Aa]pplication.*?shall be made to ?(?:the )?",

      # OTHER VERBS
      "[Nn]o#{governed}may",
      "#{governed}may[ ](?:not|only)",
      "requiring a#{governed}.*?to",
      "#{governed}is.*?under a like duty",
      "#{governed}has taken all.*?steps",
      "Where a duty is placed.*?on an?#{governed}",
      "provided by an?#{governed}",
      responsible_for_pattern(governed),
      "#{governed}.*?(?:shall be|is) liable (?!to)"
    ]

    # |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def rights_pattern(governed),
    do:
      "#{neg_lookbehind()}#{determiners()}#{governed}.*?(?<!which|who)[ ]may[[:blank:][:punct:]][ ]?(?!need|have|require|be[ ]|not|only)"

  def rights_new_line_pattern(governed),
    # s modifier: single line. Dot matches newline characters
    do: "may be made—(?s:.)*\\([a-z]\\) by #{determiners()}#{governed}"

  def right(governed) do
    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ]may", true},

      # SUBJECT after the VERB
      "requested by a#{governed}",
      # e.g. "the result of that review shall be notified to the employee and employer"
      "(?:shall|must) (?:be notified to the|consult).*?#{governed}",
      # e.g. may be presented to the CAC by a relevant applicant
      "may be (?:varied|terminated|presented).*?by #{determiners()}#{governed}",

      # MAY
      # Does not include 'MAY NOT' and 'MAY ONLY' which are DUTIES
      # Uses a negative lookbehind (?<!element)
      {"#{governed}may[[:blank:][:punct:]][ ]?(?!exceed|need|have|require|be[ ]|not|only)", true},
      rights_pattern(governed),
      "#{governed}.*?shall be entitled",
      "#{governed}.*?is not required",
      "#{governed}may.*?, but may not",
      #
      "permission of that#{governed}",
      "may be made by #{determiners()}.*?#{governed}",
      rights_new_line_pattern(governed)
    ]
  end
end
