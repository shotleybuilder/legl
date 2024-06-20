defmodule Legl.Countries.Uk.LeglFitness.GetRule do
  @moduledoc """
  Functions to GET records from the Legal Fitness Table (LFT)
  """
  require Logger
  alias Legl.Countries.Uk.LeglFitness
  alias Legl.Services.Airtable.Get

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tblDZvM7B6kEoJ8i6"

  @default_opts %{
    base_id: @base_id,
    table_id: @table_id,
    query_name: :formula,
    fields:
      LeglFitness.Rule.new() |> Map.from_struct() |> Enum.map(fn {k, _v} -> Atom.to_string(k) end),
    view: ""
  }
  @doc """
  Get a rule from the Legal Fitness RULE Table (LFRT) by rule name

  ## Examples

      iex> get_rule(%{rule: "rule_name"})
      ...

  """
  @spec get_rule(map, list) :: [LeglFitness.Rule.t()]
  def get_rule(%{rule: rule} = _fitness, opts \\ []) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Map.put(:formula, ~s/{rule}="#{rule}"/)

    Get.get(opts.base_id, opts.table_id, opts)
    |> elem(1)
    |> Enum.map(&extract_fields/1)
    |> Enum.map(&LeglFitness.Rule.new/1)
  end

  defp extract_fields(%{"id" => id} = record) do
    Map.put(record["fields"], "record_id", id)
  end
end
