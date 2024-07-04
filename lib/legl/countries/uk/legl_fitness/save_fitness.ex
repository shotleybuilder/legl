defmodule Legl.Countries.Uk.LeglFitness.SaveFitness do
  @moduledoc """
  Functions to SAVE records to the Legal Fitness Table (LFT)
  """

  require Logger

  alias Legl.Countries.Uk.LeglFitness
  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Countries.Uk.LeglFitness.GetFitness
  alias Legl.Services.Airtable.Patch
  alias Legl.Services.Airtable.Post

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tbltS1YVqdHGecRvp"

  @doc """
  Save a fitness record to the Legal Fitness Table (LFT)

  The Fitness struct includes a field for the Rule struct.

  #Process

  ##Create or Update the Rule Record

  1. Find existing rule records
  2. Match the rule record to the existing records
  3. If a match is found, update the existing record
  4. If no match is found, create a new record

  ##Create or Update the Fitness Record
  The process:

  1. Find existing fitness records
  2. Match the fitness record to the existing records
  3. If a match is found, update the existing record
  4. If no match is found, create a new record


  ## Examples

      iex> save_fitness_record("rec123", %Fitness{})
      ...
  """

  def save_fitness_record(lrt_record_id, %Fitness{rule: %LeglFitness.Rule{} = rule} = fitness) do
    # Save the Rule to the LFRT
    with {:ok, lfrt_record_id} <- save_rule(lrt_record_id, rule),
         {:ok, lft_record_id} <- save_fitness(lrt_record_id, lfrt_record_id, fitness) do
      {:ok, lrt_record_id, lft_record_id, lfrt_record_id}
    else
      {:error, error} -> {:error, error}
    end
  end

  def save_fitness_record(_, _), do: {:error, "Invalid Fitness Record"}

  # Private functions

  defp save_rule(lrt_record_id, %LeglFitness.Rule{} = rule) do
    LeglFitness.SaveRule.save_rule(lrt_record_id, rule)
  end

  defp save_fitness(lrt_record_id, lfrt_record_id, %Fitness{} = fitness) do
    case GetFitness.get_fitness(fitness) do
      [] ->
        # Update the Fitness with the Rule record_id (:lfrt) & the Law record_id (:lrt)
        fitness_as_map =
          Map.merge(fitness, %{lrt: [lrt_record_id], lfrt: [lfrt_record_id]})
          |> remove_empty_values()
          |> Map.drop([:record_id, :rule])

        case Post.post(@base_id, @table_id, fitness_as_map) do
          :ok -> save_fitness(lrt_record_id, lfrt_record_id, fitness)
          :error -> {:error, "FITNESS post failed"}
        end

      %Fitness{} = lft_record ->
        fitness =
          fitness
          # Update multiple links to the LRT
          |> Map.replace!(:lrt, [lrt_record_id | lft_record.lrt] |> Enum.uniq())
          # Update multiple links to the LFRT
          |> (&Map.replace!(&1, :lfrt, [lfrt_record_id | lft_record.lfrt] |> Enum.uniq())).()
          # Update the record_id
          |> (&Map.replace!(&1, :record_id, lft_record.record_id)).()

        lft_record_as_map = Map.from_struct(lft_record) |> Map.drop([:rule])

        case lft_record_as_map == Map.from_struct(fitness) |> Map.drop([:rule]) do
          true ->
            Logger.notice("No changes to Fitness\n", ansi_color: :blue)
            {:ok, lft_record.record_id}

          false ->
            fitness =
              lft_record
              |> fill_empty_values(fitness)
              |> remove_empty_values()
              |> Map.drop([:rule])

            case Patch.patch(@base_id, @table_id, fitness) do
              :ok -> {:ok, lft_record.record_id}
              :error -> :error
            end
        end

      # Multiple Rules returned
      fitnesses when is_list(fitnesses) ->
        Logger.warning("Multiple Fitnesses Returned from LFT #{inspect(fitnesses)}")
        {:error, "Multiple Rules Returned from LFT"}
    end
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

  @spec remove_empty_values(Fitness.t()) :: map()
  defp remove_empty_values(%Fitness{} = fitness) do
    # Empty values are not returned from AT
    # Function removes empty values from the rule record
    fitness
    |> Map.from_struct()
    |> Enum.filter(fn {_k, v} -> Enum.member?([nil, "", []], v) == false end)
    |> Enum.into(%{})
  end
end
