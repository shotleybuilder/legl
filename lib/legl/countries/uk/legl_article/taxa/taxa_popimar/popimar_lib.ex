defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaPopimar.PopimarLib do
  @moduledoc """
  Function to tag sub-sections that impose a management duty on government, agencies or orgs
  The function is a repository of phrases used to assign these management duties.
  The phrases are joined together to form a valid regular expression.

  """

  def regex(function) do
    case Kernel.apply(__MODULE__, function, []) do
      nil ->
        nil

      term ->
        term = Enum.join(term, "|")
        ~r/(#{term})/
    end
  end

  def policy() do
    [
      "[Pp]olicy?i?e?s?",
      "[Oo]bjectives?",
      "[Ss]trateg"
    ]
  end

  def organisation() do
    [
      "[Oo]rg.? chart",
      "[Oo]rganisation chart",
      "making of appointments?",
      "(?:must|may|shall)[ ]?(?:jointly)?[ ]?appoint",
      "person.*?appointed",
      "appoint a person"
    ]
  end

  def organisation_control() do
    [
      "[Pp]rocess",
      "[Pp]rocedure",
      "[Ww]ork instruction",
      "[Mm]ethod statement",
      "[Ii]nstruction",
      "comply?i?e?s? with.*?(?:duties|requirements)",
      "is responsible for",
      "has control over",
      "must ensure, insofar as they are matters within that person’s control",
      "take such measures as it is reasonable for a person in his position to take",
      "(?:supervised?|supervising)"
    ]
  end

  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def organisation_communication_consultation() do
    [
      "[Cc]omminiate?i?o?n?g?",
      "[Cc]onsult",
      "[Cc]onsulti?n?g?",
      "[Cc]onsultation",
      "(?:send a copy of it|be sent) to",
      "must identify to",
      "publish a report",
      "must (?:immediately )?inform[[:blank:][:punct:]—]",
      "report to",
      "(?:by|to) provide?i?n?g?.*?information",
      "made available to (?:the public)",
      "supplied (?:in writing|with a copy)",
      "aware of the contents of"
    ]
  end

  @doc """
  Powers vested in government and agencies that they can exercise with discretion
  """
  def organisation_collaboration_coordination_cooperation() do
    [
      "[Cc]ollaborat",
      "[Cc]oordinat",
      "[Cc]ooperat"
    ]
  end

  def organisation_competence() do
    [
      "[Cc]ompetent?c?e?y?[ ](?!authority)",
      "[Tt]raining",
      "[Ii]nformation, instruction and training",
      "[Ii]nformation.*?provided to every person",
      "provide.*?information",
      "person satisfies the criteria",
      "skills, knowledge and experience",
      "organisational capability",
      "instructe?d?"
    ]
  end

  @doc """
  Function to tag clauses providing government and agencies with powers
  Uses the 'Dutyholder' field to pre-filter records for processing
  """
  def organisation_costs() do
    [
      "[Cc]ost[- ]benefit",
      "[Nn]ett? cost",
      "[Ff]ee[[:blank:][:punct:]”]",
      "[Cc]harge",
      "[Ff]inancial loss"
    ]
  end

  def records() do
    [
      "(?:[Rr]ecord|[Rr]eport (?!to)|[Rr]egister)",
      "[Ll]ogbook",
      "[Ii]ventory",
      "[Dd]atabase",
      "(?:[Ee]nforcement|[Pp]rohibition|[Ii]mprovement) notice",
      "[Dd]ocuments?",
      "(?:marke?d?i?n?g?|labelled)",
      "must be kept",
      "certificate",
      "health and safety file"
    ]
  end

  @doc """

  """
  def permit_authorisation_license() do
    [
      "[ “][Pp]ermit[[:blank:][:punct:]”]",
      "[Aa]uthorisation",
      "[Aa]uthorised (?:^representative)",
      "[Ll]i[sc]en[sc]ed?",
      "[Ll]i[sc]en[sc]ing"
    ]
  end

  def aspects_and_hazards() do
    [
      "[Aa]spects and impacts",
      "[Hh]azard"
    ]
  end

  def planning_risk_impact_assessment() do
    [
      # Plan
      "[Aa]nnual plan",
      "[Ss]trategic plan",
      "[Bb]usiness plan",
      "[Pp]lan of work",
      "construction phase plan",
      "written plan",
      "measures? to be specified in the plan",
      "(?:project|action) plan",
      "project is planned",
      # Assessment
      "[Ii]mpact [Aa]ssessment",
      "[Rr]isk [Aa]ssessment",
      "assessment of any risks",
      "suitable and sufficient assessment",
      "[Ii]n making the assessment",
      "(?:reassess|reassessed|reassessment)",
      "general principles of prevention",
      "identify and eliminate"
    ]
  end

  def risk_control() do
    [
      "avoid the need",
      # STEPS
      "suitable and sufficient steps",
      "steps as are reasonable in the circumstances must be taken",
      "taken? all reasonable steps",
      "takes immediate steps",
      # RISK
      "[Rr]isk [Cc]ontrol",
      "control.*?risk",
      "[Rr]isk mitigation",
      "use the best available techniques not entailing excessive cost",
      "eliminates.*?the risk",
      "reduces? the risk",
      # PROVIDES
      "provided to.*?employees",
      "provision and use of",
      # MEASURES
      "safety management system",
      "corrective measures?",
      "meets the requirements?",
      "standards for the construction",
      "shall make full and proper use",
      "measures?.*?specified.*?plan",
      "take such measures"
    ]
  end

  def notification() do
    [
      "given?.*?notice",
      "accident report",
      "[Nn]otify",
      "[Nn]otification",
      "[Aa]pplication for",
      "publish.*?a notice"
    ]
  end

  def maintenance_examination_and_testing() do
    [
      "[Mm]aintenance",
      "[Mm]aintaine?d?",
      "[Ee]xamination",
      "[Tt]esting",
      "[Ii]nspecti?o?n?e?d?"
    ]
  end

  def checking_monitoring() do
    [
      "[Cc]heck",
      "[Mm]onitor",
      "medical exam",
      "at least once every.*?years",
      "kept available for inspection"
    ]
  end

  def review() do
    [
      "[Mm]anagement review",
      "(?:[Rr]eviewed|is [Rr]evised)",
      "(?:conduct|carry out|carrying out) (?:a|the) review",
      "review the (?:assessment)"
    ]
  end
end
