defmodule Legl.Countries.Uk.LeglInterpretation.Interpretation do
  @moduledoc """
  Functions to parse interpretation / definitions in law

  Enumerates a list of %UK.Act{} or %UK.Regulation{} structs

  File input saved as at_schema.json
  """

  @type legal_article_interpretation :: %__MODULE__{
          Term: String.t(),
          Definition: String.t(),
          Linked_LRT_Records: list()
        }

  defstruct Term: "",
            Definition: "",
            Linked_LRT_Records: []

  def api_interpretation(records, opts) do
  end

  @doc """
  Function to parse definitions when they are contained within an
  'Interpretation' section

  """
  def parse_interpretation_section(record) do
  end
end
