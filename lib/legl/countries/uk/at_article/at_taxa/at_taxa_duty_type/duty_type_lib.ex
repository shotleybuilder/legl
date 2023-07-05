defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib do
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib

  def workflow(text, actors) do
    {text, {[], duty_types}} =
      {text, {[], []}}
      # has to process first to ensure the amending text for other law doesn't get tagged
      |> process(amendment())

    {text, {dutyholders, duty_types}} =
      if actors != [] do
        {regex, lib} = _governed = DutyholderLib.custom_dutyholders(actors, :governed)
        {gvt_regex, gvt_lib} = _government = DutyholderLib.custom_dutyholders(actors, :government)

        {text, {[], duty_types}}
        |> pre_process(blacklist(regex))
        |> process_dutyholder(responsibility(gvt_regex), gvt_lib)
        |> process(power_conferred(gvt_regex))
        |> process_dutyholder(discretionary(gvt_regex), gvt_lib)
        |> process_dutyholder(right(regex), lib)
        |> process_dutyholder(duty(regex, gvt_regex), lib)
      else
        {text, {[], duty_types}}
      end

    {_text, {dutyholders, duty_types}} =
      {text, {dutyholders, duty_types}}
      # |> process("Process , Rule, Constraint, Condition", process_rule_constraint_condition())
      |> process(extent())
      |> process(enaction_citation_commencement())
      |> process(interpretation_definition())
      |> process(application_scope())
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

  defp blacklist(governed) do
    [
      "area of the authority",
      "#{governed}may (?:be|not)"
    ]
  end

  defp process_dutyholder(collector, _regexes, []), do: collector

  defp process_dutyholder(collector, regexes, library) do
    Enum.reduce(regexes, collector, fn {regex, duty_type},
                                       {text, {dutyholders, duty_types}} = acc ->
      case Regex.run(~r/#{regex}/m, text) do
        [match] ->
          dutyholder = DutyholderLib.workflow(match, library)

          duty_type = if is_binary(duty_type), do: [duty_type], else: duty_type

          {Regex.replace(~r/#{regex}/m, text, ""),
           {dutyholders ++ dutyholder, duty_types ++ duty_type}}

        nil ->
          acc

        match ->
          IO.puts("ERROR process_dutyholder/3: #{text} #{inspect(match)}")
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
  def duty(governed, government) do
    [
      {"#{governed}.*?(?:shall be|is) liable", "Liability"},
      {"#{governed}shall not be (?:guilty|liable)", "Defence, Appeal"},
      {"#{governed}[\\s\\S]*?it shall (?:also )?.*?be a defence", "Defence, Appeal"},
      {"[Nn]o#{governed}shall", "Duty"},
      {"(?:[Aa]n?|[Tt]he)#{governed}.*?must", "Duty"},
      {"(?:[Aa]n?|[Tt]he)#{governed}.*?shall", "Duty"},
      {"#{governed}(?:shall notify|shall furnish the authority)", "Duty"},
      {"shall be the duty of any#{governed}", "Duty"},
      {"requiring a#{governed}.*?to", "Duty"},
      {"[Aa]pplication.*?shall be made to ?(?:the )?#{government}", "Duty"}
    ]
  end

  def right(governed) do
    [
      {"#{governed}may.*?, but may not", ["Duty", "Right"]},
      {"#{governed}.*?may appeal", ["Right", "Defence, Appeal"]},
      {"[Nn]o#{governed}may", "Duty"},
      {"requested by a#{governed}", "Right"},
      {"shall consult.*?#{governed}", "Right"},
      {"#{governed}may[, ]", "Right"},
      {"#{governed}.*?shall be entitled", "Right"},
      {"permission of that#{governed}", "Right"},
      {"[Ii]t is a defence for a #{governed}", "Defence, Appeal"}
    ]
  end

  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def responsibility(government) do
    [
      {"#{government}[^—\\.]*?(?:must|shall)", "Responsibility"},
      {"#{government}[^—\\.]*?has determined", "Responsibility"},
      {"[Ii]t shall be the duty of a?n?[^—\\.]*?#{government}", "Responsibility"},
      {"#{government}[^—\\.]*?(?:must|shall)", "Responsibility"},
      {"#{government} owes a duty to", "Responsibility"},
      {"is to be.*?by a#{government}", "Responsibility"},
      {"#{government}is to have regard", "Responsibility"}
    ]
  end

  @doc """
  Powers vested in government and agencies that they can exercise with discretion
  """
  def discretionary(government) do
    [
      {"#{government}[^—\\.]*?may", "Discretionary"}
    ]
  end

  def process_rule_constraint_condition() do
  end

  @doc """
  Function to tag clauses providing government and agencies with powers
  Uses the 'Dutyholder' field to pre-filter records for processing
  """
  def power_conferred(government) do
    [
      {"#{government}.*?may.*?by regulation.*?(specify|substitute|prescribe|make)",
       "Power Conferred"},
      {"#{government} may.*?direct ", "Power Conferred"},
      {"#{government} may.*make.*(scheme|plans?|regulations?) ", "Power Conferred"},
      {"#{government}[^—\\.]*?may[, ]", "Power Conferred"},
      {"#{government} considers necessary", "Power Conferred"},
      {" in the opinion of the #{government} ", "Power Conferred"},
      #   " [Rr]egulations.*?under (this )?(section|subsection)", "Power Conferred"},
      {" functions.*(exercis(ed|able)|conferred) ", "Power Conferred"},
      {" exercising.*functions ", "Power Conferred"},
      {"#{government} shall be entitled", "Power Conferred"},
      {"#{government} may by regulations?", "Power Conferred"},
      {"power to make regulations", "Power Conferred"},
      {"[Tt]he power under (?:subsection)", "Power Conferred"}
    ]
  end

  def enaction_citation_commencement() do
    [
      {"(?:Act|Regulation) may be cited as", "Enactment, Citation, Commencement"},
      {"(?:Act|Regulation).*?shall have effect", "Enactment, Citation, Commencement"},
      {"(?:Act|Regulation) shall come into force", "Enactment, Citation, Commencement"},
      {"comes? into force", "Enactment, Citation, Commencement"},
      {"has effect.*?on or after", "Enactment, Citation, Commencement"}
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
      {"[A-Za-z\\d ]”.*?(?:#{defn})[ —,]", "Interpretation, Definition"},
      {"“.*?” is.*?[ —,]", "Interpretation, Definition"},
      {" has?v?e? the (?:same )?meanings? ", "Interpretation, Definition"},
      {" [Ff]or the purpose of determining ", "Interpretation, Definition"},
      {" any reference in this .*?to ", "Interpretation, Definition"},
      {"[Ii]nterpretation", "Interpretation, Definition"},
      {"for the meaning of “", "Interpretation, Definition"}
    ]
  end

  def application_scope() do
    [
      {"(?:Part|Chapter|[Ss]ection|[Ss]ubsection).*?applies", "Application, Scope"},
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
      {"(?:Act|Regulation|section)(?: does not | )extends? to", "Extent"},
      {"(?:Act|Section).*?extends? (?:only )?to", "Extent"},
      {"[R|r]egulations under", "Extent"}
    ]
  end

  def exemption() do
    [
      {" shall not apply to (Scotland|Wales|Northern Ireland)", "Exemption"},
      {" shall not apply in any case where[, ]", "Exemption"}
    ]
  end

  def repeal_revocation() do
    [
      {" . . . . . . . ", "Repeal, Revocation"},
      {"(?:revoked|repealed)[ —]", "Repeal, Revocation"},
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
