defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib do
  @default_opts %{
    dutyholder: "person"
  }

  @dutyholders [
                 "[Pp]erson",
                 "[Hh]older",
                 "[Pp]roducer"
               ]
               |> Enum.join("|")
               |> (fn x -> ~s/(#{x})/ end).()

  @agencies [
              "[Aa]gency",
              "authority",
              "Environment Agency",
              "local authorit(y|ies)",
              "enforcing authority",
              "local enforcing authority",
              "SEPA",
              "Scottish Environment Proection Agency",
              "(Office for Environmental Protection|OEP)",
              "court",
              "[Aa]ppropriate person"
            ]
            |> Enum.join("|")
            # enclose in parentheses to create a regex 'OR'
            |> (fn x -> ~s/(#{x})/ end).()

  def workflow(text) do
    {_, classes} =
      {text, []}
      # |> pre_process(blacklist())
      # has to process first to ensure the amending text for other law doesn't get tagged
      |> process(amendment())
      |> process(responsibility())
      |> process(discretionary())
      |> process(right())
      |> process(duty())
      # |> process("Process , Rule, Constraint, Condition", process_rule_constraint_condition())
      |> process(power_conferred())
      # |> process("Enaction, Citation, Commencement", enaction_citation_commencement())
      |> process(interpretation_definition())
      |> process(application_scope())
      |> process(extension())
      |> process(exemption())
      |> process(repeal_revocation())
      # |> process("Transitional Arrangement", transitional_arrangement())

      |> process(charge_fee())
      |> process(offence())
      |> process(enforcement_prosecution())
      |> process(defence_appeal())

    if classes == [],
      do: ["Process, Rule, Constraint, Condition"],
      else:
        classes
        |> Enum.filter(fn x -> x != nil end)
        # |> Enum.reverse()
        |> Enum.uniq()
  end

  def pre_process({text, collector}, blacklist) do
    Enum.reduce(blacklist, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/, acc, "")
    end)
    |> (&{&1, collector}).()
  end

  defp blacklist() do
    [
      "[ “][Aa] person guilty of an offence",
      "person is ordered",
      "person shall not be liable",
      "person.?shall be liable",
      "person is given a notice",
      "person who commits an offence",
      "person who fails"
    ]
  end

  defp process(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, class}, {text, classes} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          # A specific term (approved person) should be removed from the text to avoid matching on 'person'
          {Regex.replace(~r/#{regex}/m, text, ""), [class | classes]}

        false ->
          acc
      end
    end)
  end

  def purpose(_opts) do
  end

  @doc """
  Function to tag sub-sections that impose a duty on persons other than government, regulators and agencies
  The function is a repository of phrases used to assign these duties.
  The phrases are joined together to form a valid regular expression.

  params.  Dutyholder should accommodate intial capitalisation eg [Pp]erson, [Ee]mployer
  """
  def duty() do
    [
      {" ?[Nn]o #{@dutyholders} shall", "Duty"},
      {" ?([Aa]n?|[Tt]he) #{@dutyholders}.*?must use", "Duty"},
      {" ?([Aa]n?|[Tt]he) #{@dutyholders}.*?shall", "Duty"},
      {" #{@dutyholders} (shall notify|shall furnish the authority)", "Duty"},
      {" shall be the duty of any #{@dutyholders}", "Duty"},
      {" ?[Aa]pplication.*?shall be made to (the )?#{@agencies} ", "Duty"}
    ]
  end

  def right() do
    [
      {" #{@dutyholders} may (be|not)", nil},
      {"requested by a #{@dutyholders}", "Right"},
      {"shall consult.*?#{@dutyholders}", "Right"},
      {" #{@dutyholders} may[, ]", "Right"},
      {" #{@dutyholders}.*?shall be entitled", "Right"},
      {" permission of that #{@dutyholders}", "Right"}
    ]
  end

  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def responsibility() do
    [
      {" ?Secretary of State[^—\\.]*?shall", "Responsibility"},
      {" ?Secretary of State[^—\\.]*?has determined", "Responsibility"},
      {"Secretary of State must", "Responsibility"},
      {" ?[Ii]t shall be the duty of[^—\\.]*?#{@agencies}", "Responsibility"},
      {" ?#{@agencies}[^—\\.]*?shall", "Responsibility"}
    ]
  end

  @doc """
  Powers vested in government and agencies that they can exercise with discretion
  """
  def discretionary() do
    [
      {" #{@agencies}[^—\\.]*?may", "Discretionary"}
    ]
  end

  def process_rule_constraint_condition() do
  end

  @doc """
  Function to tag clauses providing government and agencies with powers
  Uses the 'Dutyholder' field to pre-filter records for processing
  """
  def power_conferred() do
    [
      {" Secretary of State may, by regulations?, (substitute|prescribe) ", "Power Conferred"},
      {" Secretary of State may.*?direct ", "Power Conferred"},
      {" Secretary of State may.*make.*(scheme|plans?|regulations?) ", "Power Conferred"},
      {" Secretary of State[^—\\.]*?may[, ]", "Power Conferred"},
      {" Secretary of State considers necessary", "Power Conferred"},
      {" in the opinion of the Secretary of State ", "Power Conferred"},
      #   " [Rr]egulations.*?under (this )?(section|subsection)", "Power Conferred"},
      {" functions.*(exercis(ed|able)|conferred) ", "Power Conferred"},
      {" exercising.*functions ", "Power Conferred"}
    ]
  end

  def enaction_citation_commencement() do
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
        "is the",
        "are",
        "to be read as",
        "are references to",
        "consists"
      ]
      |> Enum.join("|")

    [
      {"[a-z]” (#{defn})[ —,]", "Interpretation, Definition"},
      {" has?v?e? the (?:same )?meanings? ", "Interpretation, Definition"},
      {" [Ff]or the purpose of determining ", "Interpretation, Definition"},
      {" any reference in this .*?to ", "Interpretation, Definition"},
      {" interpretation ", "Interpretation, Definition"}
    ]
  end

  def application_scope() do
    [
      {" ?This (Part|Chapter|[Ss]ection) applies", "Application, Scope"},
      {" ?This (Part|Chapter|[Ss]ection) does not apply", "Application, Scope"},
      {" ?does not apply", "Application, Scope"}
    ]
  end

  def extension() do
    [
      {" shall have effect ", "Extension"}
    ]
  end

  def exemption() do
    [
      {" shall not apply to (Scotland|Wales|Northern Ireland)", "Exemption"},
      {" shall not apply in any case where[, ]", "Exemption"},
      {" #{@dutyholders} shall not be liable", "Exemption"}
    ]
  end

  def repeal_revocation() do
    [
      {" . . . . . . . ", "Repeal, Revocation"},
      {"repealed—", "Repeal, Revocation"}
    ]
  end

  def transitional_arrangement() do
  end

  def amendment() do
    [
      {"shall be inserted the words— ?\n?“[\\s\\S]*”", "Amendment"},
      {"shall be inserted— ?\\n?“[\\s\\S]*”", "Amendment"},
      {" (substitute|insert)— ?\\n?“[\\s\\S]*”", "Amendment"},
      {"omit the words", "Amendment"},
      {"for.*?substitute", "Amendment"},
      {"shall be (inserted|substituted) the words", "Amendment"},
      {"[Aa]mendments?", "Amendment"},
      {"[Aa]mended as follows", "Amendment"}
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
      {" ?[Oo]ffences?[ \\.,]", "Offence"},
      {" ?[Ff]ixed penalty ", "Offence"}
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
