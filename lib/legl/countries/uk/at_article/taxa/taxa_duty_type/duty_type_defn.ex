defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefn do
  def purpose(_opts) do
    []
  end

  def process_rule_constraint_condition() do
  end

  def enaction_citation_commencement() do
    duty_type = "Enactment, Citation, Commencement"

    [
      "(?:Act|Regulations?) may be cited as",
      "(?:Act|Regulations?).*?shall have effect",
      "(?:Act|Regulations?) shall come into force",
      "comes? into force",
      "has effect.*?on or after"
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
      ~s/In these Regulations.*?—/,
      "has?v?e? the (?:same )?meanings?",
      # ?<! Negative Lookbehind
      "(?<!prepared) [Ff]or the purposes? of (?:determining|these Regulations) ",
      "(?:any reference|references?).*?to",
      "[Ii]nterpretation",
      "interpreting these Regulation",
      "for the meaning of “",
      "provisions.*?are reproduced",
      "an?y? reference.*?in these Regulations?",
      "[Ww]here an expression is defined.*?and is not defined.*?it has the same meaning",
      "are to be read"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def application_scope() do
    duty_type = "Application, Scope"

    [
      "Application",
      "(?:Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?).*?apply?i?e?s?",
      "(?:Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?).*?doe?s? not apply",
      "does not apply",
      "shall.*?apply",
      "application of this (?:Part|Chapter|[Ss]ection)",
      "apply to any work outside",
      "apply to a self-employed person",
      # For the Purposes
      "Section.*?apply for the purposes",
      "[Ff]or the purposes of.*?the requirements? (?:of|set out in)",
      "[Ff]or the purposes of paragraph",
      # Other
      "requirements.*?which cannot be complied with are to be disregarded",
      "[Rr]egulations referred to"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def extent() do
    [
      {"shall have effect", "Extent"},
      {"(?:Act|Regulation|section)(?: does not | do not | )extends? to", "Extent"},
      {"(?:Act|Regulations?|Section).*?extends? (?:only )?to", "Extent"},
      {"[Oo]nly.*?extend to", "Extent"},
      {"do not extend to", "Extent"},
      {"[R|r]egulations under", "Extent"},
      {"enactment amended or repealed by this Act extends", "Extent"}
    ]
  end

  def exemption() do
    [
      {" shall not apply to (Scotland|Wales|Northern Ireland)", "Exemption"},
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
      "(?:repeals|revocations)"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def transitional_arrangement() do
  end

  def amendment() do
    duty_type = "Amendment"

    [
      "shall be inserted the words— ?\n?“[\\s\\S]*”",
      "shall be inserted— ?\\n?“[\\s\\S]*”",
      " (?:substituted?|inserte?d?)—? ?\\n?“[\\s\\S]*”",
      "omit the words",
      "for.*?substitute",
      "shall be (?:inserted|substituted) the words",
      "there is inserted",
      "[Aa]mendments?",
      "[Aa]mended as follows",
      "omit the following"
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
      "may charge.*?a fee ",
      "invoice must include a statement of the work done"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def offence() do
    [
      {" ?[Oo]ffences?[ \\.,—]", "Offence"},
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
      {" [Aa]ppeal ", "Defence, Appeal"}
    ]
  end
end
