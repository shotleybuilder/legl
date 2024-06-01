defmodule Legl.Services.Airtable.AtFormulas do
  @doc """

  """
  def hseplan_formula(%{sector: "on", schema: schema}) do
    ~s[FIND("#{schema}",{on_sch.md})>0]
  end
end
