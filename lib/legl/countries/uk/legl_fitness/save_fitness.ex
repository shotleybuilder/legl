defmodule Legl.Countries.Uk.LeglFitness.SaveFitness do
  @moduledoc """
  Functions to SAVE records to the Legal Fitness Table (LFT)
  """

  require Logger

  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Countries.Uk.LeglFitness.GetFitness
  alias Legl.Services.Airtable.Patch
  alias Legl.Services.Airtable.Post

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tbltS1YVqdHGecRvp"

  def save_fitness_record(lrt_record_id, %Fitness{} = fitness) do
    # code to find existing fitness_record
    lft_records = GetFitness.get_fitness(fitness)

    case match_fitness_record(fitness, lft_records) do
      {nil, 0} ->
        post_fitness_record(lrt_record_id, fitness)

      {lft_record, best_match_value} when best_match_value > 0.9 ->
        lft_record
        |> fill_empty_values(fitness)
        |> patch_fitness_record(lrt_record_id)

      _ ->
        post_fitness_record(lrt_record_id, fitness)
    end
  end

  def save_fitness_record(_, _) do
    IO.puts("Invalid Fitness Record")
    :error
  end

  # Private functions

  defp match_fitness_record(_, []), do: {nil, 0}

  defp match_fitness_record(%Fitness{} = fitness, lft_records) do
    Enum.reduce_while(lft_records, {nil, 0}, fn
      %Fitness{fit_id: fit_id} = lft_record, {best_matching_lft_record, match_value} ->
        match = String.jaro_distance(fit_id, Map.get(fitness, :fit_id))

        cond do
          match == 1.0 -> {:halt, {lft_record, match}}
          match > match_value -> {:cont, {lft_record, match}}
          true -> {:cont, {best_matching_lft_record, match_value}}
        end

      %Fitness{fit_id: nil}, acc ->
        {:cont, acc}
    end)
  end

  defp fill_empty_values(%Fitness{} = lft, %Fitness{} = fitness) do
    # Empty values are not returned from AT
    fitness
    |> Map.from_struct()
    |> Enum.reduce(lft, fn {key, value}, lft ->
      case Map.get(lft, key) do
        nil ->
          Map.put(lft, key, value)

        result when is_list(result) and is_list(value) ->
          Map.put(lft, key, (result ++ value) |> Enum.uniq())

        result when is_list(result) ->
          Map.put(lft, key, [value | result])

        _ ->
          lft
      end
    end)
  end

  defp patch_fitness_record(%Fitness{lrt: lrt} = lft_record, lrt_record_id) do
    # code to patch fitness record
    [lrt_record_id | lrt]
    |> Enum.uniq()
    |> (&Map.put(lft_record, :lrt, &1)).()
    |> Map.from_struct()
    |> (&Patch.patch(@base_id, @table_id, &1)).()
  end

  defp post_fitness_record(lrt_record_id, %Fitness{} = fitness) do
    # code to post fitness record
    [lrt_record_id | fitness.lrt]
    |> (&Map.put(fitness, :lrt, &1)).()
    |> Map.from_struct()
    |> Map.drop([:record_id])
    |> (&Post.post(@base_id, @table_id, &1)).()
  end
end
