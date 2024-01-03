defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGovernment do
  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def responsibility(government) do
    [
      "#{government}(?:must|shall)",
      "#{government}[^—\\.]*?(?:must|shall)",
      "must be (?:carried out|reviewed|sent|prepared).*?#{government}",
      "#{government}[^—\\.]*?has determined",
      "[Ii]t shall be the duty of a?n?[^—\\.]*?#{government}",
      "#{government} owes a duty to",
      "is to be.*?by a#{government}",
      "#{government}is to (?:perform|have regard)",
      "#{government}may not"
    ]
  end

  @doc """
  Function to tag clauses providing government and agencies with powers
  """
  def power_conferred(government) do
    [
      "#{government}.*?may.*?by regulations?.*?(?:specify|substitute|prescribe|make)",
      "#{government} may.*?direct ",
      "#{government} may vary the terms",
      "#{government} may.*make.*(scheme|plans?|regulations?) ",
      "#{government} considers necessary",
      " in the opinion of the #{government} ",
      "#{government} shall be entitled",
      "#{government} may by regulations?",
      "#{government}[^—\\.]*?may(?![ ]not)",
      "#{government}is not required"
    ]
  end
end
