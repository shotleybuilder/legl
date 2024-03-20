defmodule Legl.Countries.Uk.LeglInterpretation.Options do
  @moduledoc """
  Functions to set options for GET request to Legal Interpretation Table (LIT)
  """

  alias Legl.Services.Airtable.AtBasesTables

  def base_table_id(%{base_name: base_name, table_name: table_name} = opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(base_name, table_name)
    Map.merge(opts, %{base_id: base_id, table_id: table_id})
  end

  @doc """
  Functions to set a value for the Term in the opts map

  3 Function heads:
    1. term: is empty or nil, prompts user for the Term
    2. :term is set, passes back the opts w/o change
    3. :term not in opts.  Put :term in opts and call term/1
  """
  @spec term(%{term: <<>> | nil}) :: %{term: <<>> | binary()}
  def term(%{term: term} = opts) when term in [nil] do
    Map.put(opts, :term, ExPrompt.string(~s/Term/))
  end

  @spec term(%{term: binary()}) :: %{term: binary()}
  def term(%{term: term} = opts) when is_binary(term), do: opts

  @spec term(%{}) :: %{term: <<>>}
  def term(opts), do: term(Map.put(opts, :term, nil))

  def formula_term(f, %{term: ""} = _opts) do
    [~s/{term}=BLANK()/ | f]
  end

  def formula_term(f, %{term: term} = _opts) when term not in ["", nil] do
    [~s/{term}="#{term}"/ | f]
  end

  def formula_term(f, _), do: f
end
