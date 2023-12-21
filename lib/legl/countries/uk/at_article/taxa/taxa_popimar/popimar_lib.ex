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
      "[Oo]rganisation chart"
    ]
  end

  def organisation_control() do
    [
      "[Pp]rocess",
      "[Pp]rocedure",
      "[Ww]ork instruction",
      "[Mm]ethod statement",
      "[Ii]nstruction"
    ]
  end

  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def organisation_communication_consultation() do
    [
      "[Cc]omminiate?i?o?n?g?",
      "[Cc]onsulti?n?g?",
      "[Cc]onsultation",
      "send a copy of it to"
    ]
  end

  @doc """
  Powers vested in government and agencies that they can exercise with discretion
  """
  def organisation_collaboration_coordination_cooperation() do
    [
      "[Cc]ollaborate?i?o?n?g?",
      "[Cc]oordinate?i?o?n?g?",
      "[Cc]ooperate?i?o?n?g?"
    ]
  end

  def organisation_competence() do
    [
      "[Cc]ompetent?c?e?y?",
      "[Tt]raining",
      "[Ii]nformation, instruction and training",
      "provide.*?information"
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
      "[Ff]ee[ \\.,:;”]",
      "[Cc]harge",
      "[Ff]inancial loss"
    ]
  end

  def records() do
    [
      "[Rr]ecord",
      "[Rr]egister",
      "[Ll]ogbook",
      "[Ii]ventory",
      "[Dd]atabase",
      "([Ee]nforcement|[Pp]rohibition|[Ii]mprovement) notice",
      "[Dd]ocuments?"
    ]
  end

  @doc """

  """
  def permit_authorisation_license() do
    [
      "[ “][Pp]ermit[ \\.,:;”]",
      "[Aa]uthorisation",
      "[Aa]uthorised",
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
      "[Aa]nnual plan",
      "[Ss]trategic plan",
      "[Bb]usiness plan",
      "[Ii]mpact [Aa]ssessment",
      "[Rr]isk [Aa]ssessment",
      "assessment of any risks",
      "suitable and sufficient assessment"
    ]
  end

  def risk_control() do
    [
      "avoid the need",
      "[Rr]isk [Cc]ontrol",
      "[Rr]isk mitigation",
      "use the best available techniques not entailing excessive cost",
      "reduce the risk",
      "shall make full and proper use"
    ]
  end

  def notification() do
    [
      "given.*?notice",
      "[Nn]otify",
      "[Nn]otification",
      "[Aa]pplication for"
    ]
  end

  def maintenance_examination_and_testing() do
    [
      "[Mm]aintenance",
      "[Ee]xamination",
      "[Tt]esting"
    ]
  end

  def checking_monitoring() do
    [
      "[Cc]heck",
      "[Mm]onitor"
    ]
  end

  def review() do
    [
      "[Mm]anagement review",
      "shall be reviewed"
    ]
  end
end
