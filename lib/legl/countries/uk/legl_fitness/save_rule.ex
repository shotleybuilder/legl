defmodule Legl.Countries.Uk.LeglFitness.SaveRule do
  @moduledoc """
  Functions to SAVE records to RULE Table of the Legal Fitness Base
  """

  require Logger

  alias Legl.Countries.Uk.LeglFitness
  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Services.Airtable.Patch
  alias Legl.Services.Airtable.Post

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tblDZvM7B6kEoJ8i6"

  @spec save_rule(fitness :: Fitness.t()) :: :ok | :error
  def save_rule(%{rule: rule} = _fitness) do
    rule_records = LeglFitness.GetRule.get_rule(rule)

    case rule_records do
      [] ->
        Post.post(@base_id, @table_id, rule)

      [rule] ->
        Patch.patch(@base_id, @table_id, rule)

      rule ->
        IO.puts("Invalid Rule Record #{inspect(rule)}")
        :error
    end
  end
end
