defmodule Legl.Countries.Uk.LeglFitness.SaveRule do
  @moduledoc """
  Functions to SAVE records to RULE Table of the Legal Fitness Base
  """

  require Logger

  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Countries.Uk.LeglFitness.Rule
  alias Legl.Countries.Uk.LeglFitness.GetRule
  alias Legl.Services.Airtable.Patch
  alias Legl.Services.Airtable.Post

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tblDZvM7B6kEoJ8i6"

  @doc """
  Save a rule record to the Legal Fitness Rule Table (LFRT)

  Rules are in a 1 to many relationship with the Legal Fitness Table (LFT) and
  the Legal Register Table (LRT).

  The Rule is the single end of the relationship.

  A Fitness (a particular signature) can be associated with many Rules.

  A Law can be associated with many Rules.

  The unique key is the text of the Rule.  Getting a Rule by its text should
  return either zero or 1 Rule record.

  """
  @spec save_rule(String.t(), fitness :: Fitness.t()) :: {:ok, String.t()} | {:error, String.t()}
  @spec save_rule(String.t(), rule :: Rule.t()) :: {:ok, String.t()} | {:error, String.t()}
  def save_rule(lrt_record_id, fitness) when is_struct(fitness, Fitness),
    do: save_rule(lrt_record_id, fitness.rule)

  def save_rule(lrt_record_id, rule) when is_struct(rule, Rule) do
    case GetRule.get_rule(rule.rule) do
      # No Rule returned
      [] ->
        rule_as_map =
          Map.from_struct(rule)
          |> Map.drop([:record_id])
          |> Map.replace!(:lrt, [lrt_record_id | rule.lrt] |> Enum.uniq())
          |> remove_empty_values()

        case Post.post(@base_id, @table_id, rule_as_map) do
          :ok -> save_rule(lrt_record_id, rule)
          :error -> {:error, "RULE post failed"}
        end

      # Single Rule returned
      lfrt when is_struct(lfrt, Rule) ->
        rule =
          rule
          |> Map.replace!(:record_id, lfrt.record_id)
          |> Map.replace!(:lrt, [lrt_record_id])

        case lfrt == rule do
          true ->
            Logger.notice("No changes to Rule\n", ansi_color: :blue)
            {:ok, lfrt.record_id}

          false ->
            # Update the existing record
            rule_as_map =
              rule
              |> fill_empty_values(lfrt)
              |> remove_empty_values()

            case Patch.patch(@base_id, @table_id, rule_as_map) do
              :ok -> {:ok, lfrt.record_id}
              :error -> {:error, "RULE patch failed"}
            end
        end

      # Multiple Rules returned
      rule when is_list(rule) ->
        Logger.warning("Multiple Rules Returned from LFRT #{inspect(rule)}")
        {:error, "Multiple Rules Returned from LFRT"}
    end
  end

  @spec fill_empty_values(Rule.t(), Rule.t()) :: Rule.t()
  defp fill_empty_values(%Rule{} = rule, %Rule{} = lfrt) do
    # Empty values are not returned from AT
    # Function updates the lfrt record with values from the current rule
    rule
    |> Map.from_struct()
    |> Enum.reduce(lfrt, fn {key, value}, lfrt ->
      case Map.get(lfrt, key) do
        # Empty value in current record
        nil ->
          Map.put(lfrt, key, value)

        # Append to existing list
        result when is_list(result) and is_list(value) ->
          Map.put(lfrt, key, (result ++ value) |> Enum.uniq())

        result when is_list(result) ->
          Map.put(lfrt, key, [value | result])

        _ ->
          lfrt
      end
    end)
  end

  @spec remove_empty_values(Rule.t()) :: map()
  defp remove_empty_values(%Rule{} = rule) do
    # Empty values are not returned from AT
    # Function removes empty values from the rule record
    rule
    |> Map.from_struct()
    |> Enum.filter(fn {_k, v} -> Enum.member?([nil, "", []], v) == false end)
    |> Enum.into(%{})
  end
end
