defmodule Legl.Countries.Uk.LeglFitness.GetFitness do
  @moduledoc """
  Functions to GET records from the Legal Fitness Table (LFT)
  """
  require Logger
  alias Legl.Services.Airtable.Get
  alias Legl.Countries.Uk.LeglFitness.Fitness

  # @base_id "appq5OQW9bTHC1zO5"
  # @table_id "tblXSfC7uvQz5p4r4"

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tbltS1YVqdHGecRvp"

  @default_opts %{
    base_id: @base_id,
    table_id: @table_id,
    query_name: :formula,
    fields: Fitness.lft_fields(),
    # ~w[lrt fit_id rule heading category scope person person_verb person_ii person_ii_verb process place plant property],
    view: ""
  }
  @doc """

    Retrieves fitness data based on the given Fitness struct and options.

    Returns a list of Fitness structs.

    ## Examples

        iex> fitness = %Fitness{...}
        iex> get_fitness(fitness)
        ...


  """
  @spec get_fitness(Fitness.t(), list) :: [Fitness.t()] | Fitness.t() | []
  @spec get_fitness(String.t(), list) :: [Fitness.t()] | Fitness.t() | []
  def get_fitness(fitness, opts \\ [])

  def get_fitness(%Fitness{fit_id: fit_id} = fitness, opts) when is_struct(fitness, Fitness),
    do: get_fitness(fit_id, opts)

  def get_fitness(fit_id, opts) when is_binary(fit_id) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Map.put(:formula, ~s/{fit_id}="#{fit_id}"/)

    case Get.get(opts.base_id, opts.table_id, opts) do
      {:ok, [record]} when is_map(record) ->
        record
        |> extract_fields()
        |> Fitness.new()

      {:ok, []} ->
        []

      {:ok, records} when is_list(records) ->
        Logger.warning(
          "Multiple records found for Fitness: #{inspect(fit_id)}\n#{inspect(records)}\n"
        )

        records
        |> Enum.map(&extract_fields/1)
        |> Enum.map(&Fitness.new/1)

      {:error, error} ->
        Logger.error("Error getting rule: #{inspect(error)}")
        []
    end
  end

  defp extract_fields(%{"id" => id} = record) do
    Map.put(record["fields"], "record_id", id)
  end
end
