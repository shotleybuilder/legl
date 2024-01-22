defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefn do
  def purpose(_opts) do
    []
  end

  def process_rule_constraint_condition() do
  end

  def enaction_citation_commencement() do
    duty_type = "Enactment, Citation, Commencement"

    [
      "(?:Act|Regulations?|Order) may be cited as",
      "(?:Act|Regulations?|Order).*?shall have effect",
      "(?:Act|Regulations?|Order) shall come into (?:force|operation)",
      "comes? into force",
      "has effect.*?on or after",
      "commencement"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  @doc """
  Function to tag interpretation and definintion clauses
  The most common pattern is
    “term” means...
  """
  def interpretation_definition() do
    defn =
      [
        "means",
        "includes",
        "does not include",
        "is (?:information|the)",
        "are",
        "to be read as",
        "are references to",
        "consists"
      ]
      |> Enum.join("|")

    duty_type = "Interpretation, Definition"

    [
      "[A-Za-z\\d ]”.*?(?:#{defn})[ —,]",
      "“.*?” is.*?[ —,]",
      "In thi?e?se? [Rr]egulations?.*?—",
      "has?v?e? the (?:same )?(?:respective )?meanings?",
      # ?<! Negative Lookbehind
      "(?<!prepared) [Ff]or the purposes? of (?:this Act|determining|these Regulations) ",
      "(?:any reference|references?).*?to",
      "[Ii]nterpretation",
      "interpreting these Regulation",
      "for the meaning of “",
      "provisions.*?are reproduced",
      "an?y? reference.*?in these Regulations?",
      "[Ww]here an expression is defined.*?and is not defined.*?it has the same meaning",
      "are to be read",
      "[Ff]or the purposes of (?:this Act|the definition of|subsection)"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def application_scope() do
    duty_type = "Application, Scope"

    [
      "Application",
      "(?:Act|Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?|Article).*?apply?i?e?s?",
      "(?:Act|Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?).*?doe?s? not apply",
      "(?:Act|Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?|[Ss]chedules?).*?has effect",
      "This.*?was enacted.*?for the purpose of making such provision as.*?necessary in order to comply with",
      "does not apply",
      "shall.*?apply",
      "shall have effect",
      "shall have no effect",
      "ceases to have effect",
      "shall remain in force until",
      "provisions of.*?apply",
      "application of this (?:Part|Chapter|[Ss]ection)",
      "apply to any work outside",
      "apply to a self-employed person",
      "Save where otherwise expressly provided, nothing in.*?shall impose a duty",
      "need not be complied with until",
      # For the Purposes
      "Section.*?apply for the purposes",
      "[Ff]or the purposes of.*?the requirements? (?:of|set out in)",
      "[Ff]or the purposes of paragraph",
      # Other
      "requirements.*?which cannot be complied with are to be disregarded",
      "(?:[Rr]egulations|provisions) referred to",
      "without prejudice to (?:regulation|the generality of the requirements?)",
      "Nothing in.*?shall prejudice the operation",
      "[Nn]othing in these (?:Regulations) prevents",
      "shall bind the Crown"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def extent() do
    [
      {"(?:Act|Regulation|section)(?: does not | do not | )extends? to", "Extent"},
      {"(?:Act|Regulations?|Section).*?extends? (?:only )?to", "Extent"},
      {"[Oo]nly.*?extend to", "Extent"},
      {"do not extend to", "Extent"},
      {"[R|r]egulations under", "Extent"},
      {"enactment amended or repealed by this Act extends", "Extent"},
      {"[Cc]orresponding provisions for Northern Ireland", "Extent"},
      {"shall not (?:extend|apply) to (Scotland|Wales|Northern Ireland)", "Extent"}
    ]
  end

  def exemption() do
    [
      {" shall not apply in any case where[, ]", "Exemption"},
      {" by a certificate in writing exempt", "Exemption"},
      {" exemption", "Exemption"}
    ]
  end

  def repeal_revocation() do
    duty_type = "Repeal, Revocation"

    [
      " . . . . . . . ",
      "(?:revoked|repealed)[ [:punct:]—]",
      "(?:[Rr]epeals|revocations)",
      "following Acts shall cease to have effect"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def transitional_arrangement() do
    transitional_arrangement = "Transitional Arrangement"

    [
      "transitional provision"
    ]
    |> Enum.map(fn x -> {x, ~s/#{transitional_arrangement}/} end)
  end

  def amendment() do
    duty_type = "Amendment"

    [
      # insert
      "shall be inserted the words— ?\n?“[\\s\\S]*”",
      "shall be inserted— ?\\n?“[\\s\\S]*”",
      "there is inserted",
      "insert the following after",
      # inserted substituted
      " (?:substituted?|inserte?d?)—? ?\\n?“[\\s\\S]*”",
      "shall be (?:inserted|substituted) the words",
      # substitute
      "for.*?substitute",
      # omit
      "omit the (?:words?|entr(?:y|ies) relat(?:ing|ed) to|entry for)",
      "omit the following",
      "[Oo]mit “?(?:section|paragraph)",
      "[Oo]mit[ ]+(?:section|paragraph)",
      "entry.*?shall be omitted",
      # amended
      "shall be amended",
      # added
      "there shall be added the following paragraph",
      "add the following after (?:subsection|paragraph)",
      # amend
      "[Aa]mendments?",
      "[Aa]mended as follows",
      "are amended in accordance with"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def charge_fee() do
    duty_type = "Charge, Fee"

    [
      " fees and charges ",
      " (fees?|charges?).*(paid|payable) ",
      " by the (fee|charge) ",
      " failed to pay a (fee|charge) ",
      " fee.*?may not exceed the sum of the costs",
      " fee may include any costs",
      " may charge.*?a fee ",
      " [Aa] fee charged",
      "invoice must include a statement of the work done"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def offence() do
    [
      {" ?[Oo]ffences?[ \\.,—:]", "Offence"},
      {"(?:[Ff]ixed|liable to a) penalty", "Offence"}
    ]
  end

  def enforcement_prosecution() do
    [
      {"proceedings", "Enforcement, Prosecution"},
      {"conviction", "Enforcement, Prosecution"}
    ]
  end

  def defence_appeal() do
    [
      {" [Aa]ppeal ", "Defence, Appeal"},
      {"[Ii]t is a defence for a ", "Defence, Appeal"},
      {"may not rely on a defence", "Defence, Appeal"},
      {"shall not be (?:guilty|liable)", "Defence, Appeal"},
      {"[Ii]t shall (?:also )?.*?be a defence", "Defence, Appeal"},
      {"[Ii]t shall be sufficient compliance", "Defence, Appeal"},
      {"rebuttable", "Defence, Appeal"}
    ]
  end

  @doc """
  Function to tag clauses providing government and agencies with powers
  """
  def power_conferred() do
    [
      {" functions.*(?:exercis(?:ed|able)|conferred) ", "Power Conferred"},
      {" exercising.*functions ", "Power Conferred"},
      {"power to make regulations", "Power Conferred"},
      {"[Tt]he power under (?:subsection)", "Power Conferred"}
    ]
  end
end
