defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib do
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib

  @default_opts %{
    dutyholder: "person"
  }

  @person DutyholderLib.dutyholders_list(:person)

  @government DutyholderLib.dutyholders_list(:government)

  def workflow(text) do
    {_, {dutyholders, duty_types}} =
      {text, {[], []}}
      |> pre_process(blacklist())
      # has to process first to ensure the amending text for other law doesn't get tagged
      |> process(amendment())
      |> process_dutyholder(responsibility())
      |> process_dutyholder(discretionary())
      |> process_dutyholder(right())
      |> process_dutyholder(duty())
      # |> process("Process , Rule, Constraint, Condition", process_rule_constraint_condition())
      |> process(power_conferred())
      |> process(enaction_citation_commencement())
      |> process(interpretation_definition())
      |> process(application_scope())
      |> process(extent())
      |> process(exemption())
      |> process(repeal_revocation())
      # |> process("Transitional Arrangement", transitional_arrangement())

      |> process(charge_fee())
      |> process(offence())
      |> process(enforcement_prosecution())
      |> process(defence_appeal())

    if duty_types == [],
      do: {dutyholders, ["Process, Rule, Constraint, Condition"]},
      else:
        duty_types
        |> Enum.filter(fn x -> x != nil end)
        # |> Enum.reverse()
        |> Enum.uniq()
        |> (&{dutyholders, &1}).()
  end

  def pre_process({text, collector}, blacklist) do
    Enum.reduce(blacklist, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/, acc, "")
    end)
    |> (&{&1, collector}).()
  end

  defp blacklist() do
    ["area of the authority"]
  end

  defp process_dutyholder(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, duty_type, library},
                                       {text, {dutyholders, duty_types}} = acc ->
      case Regex.run(~r/#{regex}/m, text) do
        [match] ->
          dutyholder = DutyholderLib.workflow(match, library)

          # if library == :person,
          # do: IO.puts("#{regex}\n#{inspect(dutyholder)}\n#{inspect(match)}")

          duty_type = if is_binary(duty_type), do: [duty_type], else: duty_type

          {Regex.replace(~r/#{regex}/m, text, ""),
           {dutyholders ++ dutyholder, duty_types ++ duty_type}}

        nil ->
          # if library == :person and duty_type == "Duty",
          #  do: IO.puts("#{regex}\n#{text}\nNIL!!")

          acc

        match ->
          IO.puts("ERROR: #{text} #{inspect(match)}")
      end
    end)
  end

  defp process(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, duty_type},
                                       {text, {dutyholders, duty_types}} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          duty_type = if is_binary(duty_type), do: [duty_type], else: duty_type

          # A specific term (approved person) should be removed from the text to avoid matching on 'person'
          {Regex.replace(~r/#{regex}/m, text, ""), {dutyholders, duty_types ++ duty_type}}

        false ->
          acc
      end
    end)
  end

  def purpose(_opts) do
    []
  end

  @doc """
  Function to tag sub-sections that impose a duty on persons other than government, regulators and agencies
  The function is a repository of phrases used to assign these duties.
  The phrases are joined together to form a valid regular expression.

  params.  Dutyholder should accommodate intial capitalisation eg [Pp]erson, [Ee]mployer
  """
  def duty() do
    [
      {"[Nn]o#{@person}shall", "Duty", :person},
      {"(?:[Aa]n?|[Tt]he)#{@person}.*?must", "Duty", :person},
      {"(?:[Aa]n?|[Tt]he)#{@person}.*?shall", "Duty", :person},
      {"#{@person}(?:shall notify|shall furnish the authority)", "Duty", :person},
      {"shall be the duty of any#{@person}", "Duty", :person},
      {"requiring a#{@person}.*?to", "Duty", :person},
      {"[Aa]pplication.*?shall be made to ?(the )?#{@government}", "Duty", :person}
    ]
  end

  def right() do
    [
      {"[Nn]o#{@person}may", "Duty", :person},
      {"#{@person}may (?:be|not)", nil, :person},
      {"requested by a#{@person}", "Right", :person},
      {"shall consult.*?#{@person}", "Right", :person},
      {"#{@person}may[, ]", "Right", :person},
      {"#{@person}.*?shall be entitled", "Right", :person},
      {"permission of that#{@person}", "Right", :person}
    ]
  end

  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def responsibility() do
    [
      {"#{@government}[^—\\.]*?(?:must|shall)", "Responsibility", :government},
      {"#{@government}[^—\\.]*?has determined", "Responsibility", :government},
      {" ?[Ii]t shall be the duty of[^—\\.]*?#{@government}", "Responsibility", :government},
      {"#{@government}[^—\\.]*?(?:must|shall)", "Responsibility", :government},
      {"it shall be the duty of a?n? ?#{@government}", "Responsibility", :government},
      {"#{@government} owes a duty to", "Responsibility", :government},
      {"is to be.*?by a#{@government}", "Responsibility", :government},
      {"#{@government}is to have regard", "Responsibility", :government}
    ]
  end

  @doc """
  Powers vested in government and agencies that they can exercise with discretion
  """
  def discretionary() do
    [
      {"#{@person}may.*?, but may not", ["Duty", "Right"], :person},
      {"#{@government}[^—\\.]*?may", "Discretionary", :government}
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
      {"#{@government}.*?may.*?by regulation.*?(specify|substitute|prescribe)",
       "Power Conferred"},
      {"#{@government} may.*?direct ", "Power Conferred"},
      {"#{@government} may.*make.*(scheme|plans?|regulations?) ", "Power Conferred"},
      {"#{@government}[^—\\.]*?may[, ]", "Power Conferred"},
      {"#{@government} considers necessary", "Power Conferred"},
      {" in the opinion of the #{@government} ", "Power Conferred"},
      #   " [Rr]egulations.*?under (this )?(section|subsection)", "Power Conferred"},
      {" functions.*(exercis(ed|able)|conferred) ", "Power Conferred"},
      {" exercising.*functions ", "Power Conferred"},
      {"#{@government} shall be entitled", "Power Conferred"},
      {"#{@government} may by regulations?", "Power Conferred"},
      {"power to make regulations", "Power Conferred"},
      {"[Tt]he power under (?:subsection)", "Power Conferred"}
    ]
  end

  def enaction_citation_commencement() do
    [
      {"(Act|Regulation) may be cited as", "Enactment, Citation, Commencement"},
      {"(Act|Regulation) shall come into force", "Enactment, Citation, Commencement"},
      {"comes? into force", "Enactment, Citation, Commencement"}
    ]
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

    [
      {"[a-z ]”.*?(?:#{defn})[ —,]", "Interpretation, Definition"},
      {" has?v?e? the (?:same )?meanings? ", "Interpretation, Definition"},
      {" [Ff]or the purpose of determining ", "Interpretation, Definition"},
      {" any reference in this .*?to ", "Interpretation, Definition"},
      {" interpretation ", "Interpretation, Definition"},
      {"for the meaning of “", "Interpretation, Definition"}
    ]
  end

  def application_scope() do
    [
      {"This (?:Part|Chapter|[Ss]ection) applies", "Application, Scope"},
      {"This (?:Part|Chapter|[Ss]ection) does not apply", "Application, Scope"},
      {"does not apply", "Application, Scope"},
      {"shall.*?apply", "Application, Scope"},
      {"application of this (?:Part|Chapter|[Ss]ection)", "Application, Scope"},
      {"Section.*?apply for the purposes", "Application, Scope"}
    ]
  end

  def extent() do
    [
      {" shall have effect ", "Extent"},
      {"(?:Act|Regulation)(?: does not | )extends? to", "Extent"},
      {"Section.*?extends? only to", "Extent"},
      {"[R|r]egulations under", "Extent"}
    ]
  end

  def exemption() do
    [
      {" shall not apply to (Scotland|Wales|Northern Ireland)", "Exemption"},
      {" shall not apply in any case where[, ]", "Exemption"},
      {" #{@person} shall not be liable", "Exemption"}
    ]
  end

  def repeal_revocation() do
    [
      {" . . . . . . . ", "Repeal, Revocation"},
      {"(?:revoked|repealed)[ —]", "Repeal, Revocation"}
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
      {"there is inserted", "Amendment"},
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
      {" [Aa]ppeal ", "Defence, Appeal"},
      {"[Ii]t is a defence for a#{@person}", "Defence, Appeal"}
    ]
  end
end
