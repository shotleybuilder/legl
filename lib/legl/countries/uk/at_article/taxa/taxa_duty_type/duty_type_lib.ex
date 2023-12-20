defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib do
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib

  @type duty_types :: list()
  @type dutyholders :: list()
  @type article_text :: binary()

  def workflow_gvt(text, actors) do
    # has to process first to ensure the amending text for other law doesn't get tagged
    {text, {[], duty_types}} = process_amendment(text)

    {text, {dutyholders, duty_types}} =
      if actors != [] do
        government = DutyholderLib.custom_dutyholders(actors, :government)

        text = blacklist(government, text)

        responsibility = build_lib(government, &responsibility/1)
        discretionary = build_lib(government, &discretionary/1)
        power_conferred = build_lib(government, &power_conferred/1)

        {text, {[], duty_types}}
        |> process_dutyholder(responsibility)
        |> process_dutyholder(power_conferred)
        |> process_dutyholder(discretionary)
      else
        {text, {[], duty_types}}
      end

    process_duty_types({text, {dutyholders, duty_types}})
  end

  def workflow(text, actors) do
    {text, {[], duty_types}} = process_amendment(text)

    {text, {dutyholders, duty_types}} =
      if actors != [] do
        # governed == [actor: {regex, regex++}]
        governed = DutyholderLib.custom_dutyholders(actors, :governed)

        text = blacklist(governed, text)

        right = build_lib(governed, &right/1)
        duty = build_lib(governed, &duty/1)

        {text, {[], duty_types}}
        |> process_dutyholder(right)
        |> process_dutyholder(duty)
      else
        {text, {[], duty_types}}
      end

    process_duty_types({text, {dutyholders, duty_types}})
  end

  @spec process_amendment(binary()) :: {binary(), {dutyholders(), duty_types()}}
  def process_amendment(text), do: process({text, {[], []}}, amendment())

  @spec blacklist(list(), binary()) :: binary()
  def blacklist(govern, text) when is_list(govern) do
    Enum.reduce(govern, text, fn
      {_k, {_, regex}}, acc -> blacklist(acc, regex)
    end)
  end

  @spec blacklist(binary(), binary()) :: binary()
  def blacklist(text, gvn_regex) do
    blacklist_regex = blacklist_regex(gvn_regex)

    Enum.reduce(blacklist_regex, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/, acc, "")
    end)
  end

  @spec blacklist_regex(binary()) :: list(binary())
  defp blacklist_regex(regex) do
    [
      "area of the authority",
      "#{regex}may (?:be|not)"
    ]
  end

  def build_lib(governed, f) do
    Enum.map(governed, fn
      {k, {_, regex}} -> {k, f.(regex)}
    end)
    |> List.flatten()
  end

  def process_dutyholder(collector, library) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn {regex, duty_type}, {text, {dutyholders, duty_types}} = acc2 ->
        case Regex.run(~r/#{regex}/m, text) do
          [_match] ->
            actor = Atom.to_string(actor)

            {Regex.replace(~r/#{regex}/m, text, ""),
             {[actor | dutyholders], [duty_type | duty_types]}}

          nil ->
            # IO.puts(~s/"#{regex}" did not match "#{text}"/)
            acc2

          match ->
            IO.puts("ERROR process_dutyholder/3: #{text} #{inspect(match)}")
        end
      end)
    end)
  end

  @spec process_duty_types({article_text(), {dutyholders(), duty_types()}}) ::
          {dutyholders(), duty_types()}
  def process_duty_types(collector) do
    collector
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
    |> elem(1)
    |> dedupe()
  end

  defp dedupe({dutyholders, duty_types}) do
    {Enum.uniq(dutyholders), Enum.uniq(duty_types)}
  end

  def process(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, duty_type},
                                       {text, {dutyholders, duty_types}} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          # IO.puts(~s/#{text} #{duty_type}/)
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
  Function to tag sub-sections that impose a duty on persons other than
  government, regulators and agencies The function is a repository of phrases
  used to assign these duties. The phrases are joined together to form a valid
  regular expression.

  params.  Dutyholder should accommodate intial capitalisation eg [Pp]erson,
  [Ee]mployer
  """
  @spec duty(binary()) :: list(binary())
  def duty(governed) do
    [
      {"#{governed}.*?(?:shall be|is) liable", "Liability"},
      {"#{governed}shall not be (?:guilty|liable)", "Defence, Appeal"},
      {"#{governed}[\\s\\S]*?it shall (?:also )?.*?be a defence", "Defence, Appeal"},
      {"[Nn]o#{governed}shall", "Duty"},
      {"(?:[Aa]n?|[Tt]he|Each)#{governed}.*?must", "Duty"},
      {"(?:[Aa]n?|[Tt]he|Each)#{governed}.*?shall", "Duty"},
      {"#{governed}(?:shall notify|shall furnish the authority)", "Duty"},
      {"shall be the duty of any#{governed}", "Duty"},
      {"shall be reviewed by the#{governed}", "Duty"},
      {"shall also be imposed on a#{governed}", "Duty"},
      {"requiring a#{governed}.*?to", "Duty"},
      {"[Aa]pplication.*?shall be made to ?(?:the )?", "Duty"}
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

    duty_type = "Interpretation, Definition"

    [
      {"[A-Za-z\\d ]”.*?(?:#{defn})[ —,]", "Interpretation, Definition"},
      {"“.*?” is.*?[ —,]", "Interpretation, Definition"},
      {~s/In these Regulations.*?—/, ~s/#{duty_type}/},
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
      {" shall not apply in any case where[, ]", "Exemption"},
      {" by a certificate in writing exempt", "Exemption"}
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
