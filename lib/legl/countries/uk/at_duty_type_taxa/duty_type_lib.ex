defmodule Legl.Countries.Uk.AtDutyTypeTaxa.DutyTypeLib do
  @default_opts %{
    dutyholder: "person"
  }

  @dutyholders [
                 "[Pp]erson",
                 "[Hh]older"
               ]
               |> Enum.join("|")

  @agencies [
              "authority",
              "Environment Agency",
              "local authorit(y|ies)",
              "enforcing authority",
              "local enforcing authority",
              "SEPA",
              "Scottish Environment Proection Agency"
            ]
            |> Enum.join("|")

  def regex(function, opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    case Kernel.apply(__MODULE__, function, [opts]) do
      nil ->
        nil

      term ->
        term = Enum.join(term, "|")
        ~r/(#{term})/
    end
  end

  def purpose(_opts) do
  end

  @doc """
  Function to tag sub-sections that impose a duty on persons other than government, regulators and agencies
  The function is a repository of phrases used to assign these duties.
  The phrases are joined together to form a valid regular expression.

  params.  Dutyholder should accommodate intial capitalisation eg [Pp]erson, [Ee]mployer
  """
  def duty(_opts) do
    [
      " ?[Nn]o (#{@dutyholders}) shall",
      " ?[Tt]he (#{@dutyholders}).*?must use",
      " ?[Tt]he (#{@dutyholders}).*?shall",
      " (#{@dutyholders}) (shall notify|shall furnish the authority)",
      " ?[Aa] (#{@dutyholders}) shall not",
      " shall be the duty of any (#{@dutyholders})",
      " ?[Aa]pplication.*?shall be made to (the )?(#{@agencies}) "
    ]
  end

  def right(_opts) do
    [
      " [Pp]erson.*?may at any time"
    ]
  end

  def responsibility(_opts) do
    [
      " Secretary of State.*?shall.*?[—\.]",
      " ?[Ii]t shall be the duty of.*?(#{@agencies}).*\.",
      " (#{@agencies}) shall"
    ]
  end

  @doc """
  Powers vested in government and agencies that they can exercise with discretion
  """
  def discretionary(_opts) do
    [
      " (#{@agencies}) may"
    ]
  end

  def process_rule_constraint_condition(_opts) do
  end

  @doc """
  Function to tag clauses providing government and agencies with powers
  Uses the 'Dutyholder' field to pre-filter records for processing
  """
  def power_conferred(_opts) do
    [
      " Secretary of State may, by regulations?, (substitute|prescribe) ",
      " Secretary of State may.*?direct ",
      " Secretary of State may.*make.*(scheme|plans?|regulations?) ",
      " Secretary of State considers necessary",
      " in the opinion of the Secretary of State ",
      " [Rr]egulations.*?under (this )?(section|subsection)",
      " functions.*(exercis(ed|able)|conferred) ",
      " exercising.*functions "
    ]
  end

  def enaction_citation_commencement(_opts) do
  end

  @doc """
  Function to tag interpretation and definintion clauses
  The most common pattern is
    “term” means...
  """
  def interpretation_definition(_opts) do
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
      "[a-z]” (#{defn})[ —,]",
      " has?v?e? the (?:same )?meanings? ",
      " [Ff]or the purpose of determining ",
      " any reference in this .*?to ",
      " interpretation ",
      " [Ff]or the purposes of.*?(Part|Chapter|[sS]ection|subsection)"
    ]
  end

  def application_scope(_opts) do
    [
      " ?This (Part|Chapter|[Ss]ection) applies",
      " ?This (Part|Chapter|[Ss]ection) does not apply",
      " ?does not apply"
    ]
  end

  def extension(_opts) do
    [
      " shall have effect "
    ]
  end

  def exemption(_opts) do
    [
      " shall not apply to (Scotland|Wales|Northern Ireland)",
      " shall not apply in any case where[, ]"
    ]
  end

  def repeal_revocation(_opts) do
    [
      " . . . . . . . "
    ]
  end

  def transitional_arrangement(_opts) do
  end

  def amendment(_opts) do
  end

  def charges_fees(_opts) do
    [
      " fees and charges ",
      " (fees|charges) payable ",
      " by the (fee|charge) ",
      " failed to pay a (fee|charge) "
    ]
  end

  def offence(_opts) do
    [
      " ?[Oo]ffences? ",
      " ?[Ff]ixed penalty "
    ]
  end

  def enforcement_prosecution(_opts) do
  end

  def defence_appeal(_opts) do
    [
      " [Aa]ppeal "
    ]
  end
end
