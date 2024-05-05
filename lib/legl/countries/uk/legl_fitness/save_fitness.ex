defmodule Legl.Countries.Uk.LeglFitness.SaveFitness do
  @moduledoc """
  Functions to SAVE records to the Legal Fitness Table (LFT)
  """

  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Countries.Uk.LeglFitness.GetFitness
  alias Legl.Services.Airtable.Patch
  alias Legl.Services.Airtable.Post

  @base_id "appq5OQW9bTHC1zO5"
  @table_id "tblXSfC7uvQz5p4r4"

  def save_fitness_record(lrt_record_id, %Fitness{} = fitness) do
    # code to find existing fitness_record
    lft_records = GetFitness.get_fitness(fitness)

    {lft_record, best_match_value} = match_fitness_record(fitness, lft_records)

    case best_match_value > 0.9 do
      true -> patch_fitness_record(lrt_record_id, lft_record)
      false -> post_fitness_record(fitness)
    end
  end

  defp match_fitness_record(%Fitness{} = fitness, fitness_records) do
    Enum.reduce_while(fitness_records, {nil, 0}, fn
      %{"rule" => value} = fitness_record, {best_matching_lft_record, match_value} ->
        match = String.jaro_distance(value, Map.get(fitness, :rule))

        cond do
          match == 1.0 -> {:halt, {fitness_record, match}}
          match > match_value -> {:cont, {fitness_record, match}}
          true -> {:cont, {best_matching_lft_record, match_value}}
        end
    end)
  end

  defp patch_fitness_record(lrt_record_id, lft_record) do
    # code to patch fitness record
    case Enum.find(lft_record["lrt"], &(&1 == lrt_record_id)) do
      nil ->
        [lrt_record_id | lft_record["lrt"]]
        |> (&Map.put(lft_record, "lrt", &1)).()
        |> (&Patch.patch(@base_id, @table_id, &1)).()

      _ ->
        IO.puts("Record #{lrt_record_id} already exists in LFT")
        :ok
    end
  end

  defp post_fitness_record(%Fitness{} = fitness) do
    # code to post fitness record
    Post.post(@base_id, @table_id, fitness)
  end
end
