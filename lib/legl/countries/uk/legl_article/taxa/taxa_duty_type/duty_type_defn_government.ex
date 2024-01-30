defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGovernment do
  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def responsibility(government) do
    [
      "#{government}(?:must|shall)(?! have the power)",
      "#{government}[^—\\.]*?(?:must|shall)(?! have the power)",
      # a ... within the middle of the sentence
      "#{government}[^—\\.]*?[\\.\\.\\.].*?(?:must|shall)",
      "must be (?:carried out|reviewed|sent|prepared|specified by).*?#{government}",
      "#{government}[^—\\.]*?has determined",
      "[Ii]t shall be the duty of a?n?[^—\\.]*?#{government}",
      "#{government} owes a duty to",
      "is to be.*?by a#{government}",
      "#{government}is to (?:perform|have regard)",
      "#{government}may not",
      "#{government}is (?:liable|responsible for)",
      "[Ii]t is the duty of the#{government}",
      # Pattern when there are dutyholder options and MODALS start on a new line
      # s modifier: single line. Dot matches newline characters
      "#{government}.*?#{emdash()}(?s:.)*?^.*?(?:must|shall)"
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
      "#{government}.*?shall (?:have the power|be entitled)",
      "#{government} may by regulations?",
      "#{government}[^—\\.]*?may(?![ ]not|[ ]be)",
      # a ... within the middle of the sentence
      "#{government}[^—\\.]*?[\\.\\.\\.].*?may(?![ ]not)",
      "#{government}is not required",
      "may be (?:varied|terminated) by the#{government}",
      "may be excluded.*?by directions of the #{government}",
      " in the opinion of the #{government} ",
      # Pattern when there are dutyholder options and MODALS start on a new line
      # s modifier: single line. Dot matches newline characters
      "#{government}.*?#{emdash()}(?s:.)*?^.*?may(?![ ]not|[ ]be)"
    ]
  end

  defp emdash, do: <<226, 128, 148>>
end
