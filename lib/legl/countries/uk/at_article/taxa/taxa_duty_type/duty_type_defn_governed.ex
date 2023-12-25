defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGoverned do
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
      {"[Nn]o#{governed}(?:shall|is to)", "Duty"},
      {"(?:[Aa]n?y?|[Tt]he|Each|[Ee]very|that)#{governed}.*?must", "Duty"},
      {"(?:[Aa]n?y?|[Tt]he|Each)#{governed}.*?shall", "Duty"},
      {"#{governed}(?:shall notify|shall furnish the authority)", "Duty"},
      {"shall be the duty of any#{governed}", "Duty"},
      {"shall be reviewed by the#{governed}", "Duty"},
      {"shall also be imposed on a#{governed}", "Duty"},
      {"requiring a#{governed}.*?to", "Duty"},
      {"[Aa]pplication.*?shall be made to ?(?:the )?", "Duty"},
      {"#{governed}is.*?under a like duty", "Duty"},
      {"#{governed}has taken all.*?steps", "Duty"}
    ]
  end

  def right(governed) do
    [
      {"#{governed}may.*?, but may not", ["Duty", "Right"]},
      {"#{governed}.*?may appeal", ["Right", "Defence, Appeal"]},
      {"[Nn]o#{governed}may", "Duty"},
      {"requested by a#{governed}", "Right"},
      {"shall consult.*?#{governed}", "Right"},
      {"#{governed}.*?may[, ]", "Right"},
      {"#{governed}.*?shall be entitled", "Right"},
      {"permission of that#{governed}", "Right"},
      {"[Ii]t is a defence for a #{governed}", "Defence, Appeal"}
    ]
  end
end
