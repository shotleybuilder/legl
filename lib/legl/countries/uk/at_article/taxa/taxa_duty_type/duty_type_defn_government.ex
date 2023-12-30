defmodule Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGovernment do
  @doc """
  Powers vested in government and agencies that they must exercise
  """
  def responsibility(government) do
    duty_type = "Responsibility"

    [
      "#{government}(?:must|shall)",
      "#{government}.*?(?:must|shall)(?:co-operate)",
      "#{government}[^—\\.]*?(?:must|shall)",
      "must be (?:carried out|reviewed|sent|prepared).*?#{government}",
      "#{government}[^—\\.]*?has determined",
      "[Ii]t shall be the duty of a?n?[^—\\.]*?#{government}",
      "#{government}[^—\\.]*?(?:must|shall)",
      "#{government} owes a duty to",
      "is to be.*?by a#{government}",
      "#{government}is to (?:perform|have regard)",
      "#{government}may not bring to an end"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
  end

  @doc """
  Powers vested in government and agencies that they can exercise with discretion
  """
  def discretionary(government) do
    duty_type = "Discretionary"

    [
      "#{government}may",
      "#{government}[^—\\.]*?may",
      "#{government}is not required"
    ]
    |> Enum.map(fn x -> {x, ~s/#{duty_type}/} end)
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
      {"#{government} may vary the terms", "Power Conferred"},
      {"#{government} may.*make.*(scheme|plans?|regulations?) ", "Power Conferred"},
      {"#{government}[^—\\.]*?may[, ]", "Power Conferred"},
      {"#{government} considers necessary", "Power Conferred"},
      {" in the opinion of the #{government} ", "Power Conferred"},
      #   " [Rr]egulations.*?under (this )?(section|subsection)", "Power Conferred"},
      {" functions.*(?:exercis(?:ed|able)|conferred) ", "Power Conferred"},
      {" exercising.*functions ", "Power Conferred"},
      {"#{government} shall be entitled", "Power Conferred"},
      {"#{government} may by regulations?", "Power Conferred"},
      {"power to make regulations", "Power Conferred"},
      {"[Tt]he power under (?:subsection)", "Power Conferred"}
    ]
  end
end
