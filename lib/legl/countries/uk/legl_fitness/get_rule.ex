defmodule Legl.Countries.Uk.LeglFitness.GetRule do
  @moduledoc """
  Functions to GET records from the Legal Fitness Table (LFT)
  """
  require Logger
  alias Legl.Countries.Uk.LeglFitness.Rule
  alias Legl.Services.Airtable.Get

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tblDZvM7B6kEoJ8i6"

  @default_opts %{
    base_id: @base_id,
    table_id: @table_id,
    query_name: :formula,
    fields: Rule.lfrt_fields(),
    # Rule.new() |> Map.from_struct() |> Enum.map(fn {k, _v} -> Atom.to_string(k) end),
    view: ""
  }
  @doc """
  Get a rule from the Legal Fitness RULE Table (LFRT) by rule name

  ## Examples

      iex> get_rule(%{rule: "rule_name"})
      ...

  """
  @spec get_rule(String.t(), list) :: [Rule.t()] | Rule.t() | []
  @spec get_rule(Rule.t(), list) :: [Rule.t()] | Rule.t() | []
  def get_rule(rule, opts \\ [])

  def get_rule(%{rule: text} = rule, opts) when is_struct(rule, Rule),
    do: get_rule(text, opts)

  def get_rule(rule, opts) when is_binary(rule) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Map.put(:formula, ~s/{rule}="#{rule}"/)

    case Get.get(opts.base_id, opts.table_id, opts) do
      {:ok, [record]} when is_map(record) ->
        record
        |> extract_fields()
        |> Rule.new()

      {:ok, []} ->
        []

      {:ok, records} when is_list(records) ->
        Logger.warning("Multiple records found for rule: #{inspect(rule)}\n#{inspect(records)}\n")

        records
        |> Enum.map(&extract_fields/1)
        |> Enum.map(&Rule.new/1)

      {:error, error} ->
        Logger.error("Error getting rule: #{inspect(error)}")
        []
    end
  end

  defp extract_fields(%{"id" => id} = record) do
    Map.put(record["fields"], "record_id", id)
  end
end
