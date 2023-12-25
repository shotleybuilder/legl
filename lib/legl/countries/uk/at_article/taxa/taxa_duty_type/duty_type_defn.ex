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
      " [Ff]or the purposes? of (?:determining|these Regulations) ",
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
      "Section.*?apply for the purposes",
      "apply to any work outside",
      "apply to a self-employed person",
      "[Ff]or the purposes of.*?the requirements? (?:of|set out in)",
      "requirements.*?which cannot be complied with are to be disregarded",
      "[Rr]egulations referred to"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  def extent() do
    [
      {"shall have effect", "Extent"},
      {"(?:Act|Regulation|section)(?: does not | do not | )extends? to", "Extent"},
      {"(?:Act|Section).*?extends? (?:only )?to", "Extent"},
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
    [
      {" . . . . . . . ", "Repeal, Revocation"},
      {"(?:revoked|repealed)[ [:punct:]—]", "Repeal, Revocation"},
      {"(?:repeals|revocations)", "Repeal, Revocation"}
    ]
  end

  def transitional_arrangement() do
  end

  def amendment() do
    [
      {"shall be inserted the words— ?\n?“[\\s\\S]*”", "Amendment"},
      {"shall be inserted— ?\\n?“[\\s\\S]*”", "Amendment"},
      {" (?:substituted?|inserte?d?)—? ?\\n?“[\\s\\S]*”", "Amendment"},
      {"omit the words", "Amendment"},
      {"for.*?substitute", "Amendment"},
      {"shall be (?:inserted|substituted) the words", "Amendment"},
      {"there is inserted", "Amendment"},
      {"[Aa]mendments?", "Amendment"},
      {"[Aa]mended as follows", "Amendment"},
      {"omit the following", "Amendment"}
    ]
  end

  def charge_fee() do
    [
      {" fees and charges ", "Charge, Fee"},
      {" (fees?|charges?) .*(paid|payable) ", "Charge, Fee"},
      {" by the (fee|charge) ", "Charge, Fee"},
      {" failed to pay a (fee|charge) ", "Charge, Fee"}
    ]
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
