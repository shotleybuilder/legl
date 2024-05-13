defmodule Legl.Countries.Uk.LeglFitness.GetFitness do
  @moduledoc """
  Functions to GET records from the Legal Fitness Table (LFT)
  """

  alias Legl.Services.Airtable.Get
  alias Legl.Countries.Uk.LeglFitness.Fitness

  @base_id "appq5OQW9bTHC1zO5"
  @table_id "tblXSfC7uvQz5p4r4"

  @default_opts %{
    base_id: @base_id,
    table_id: @table_id,
    query_name: :formula,
    fields:
      ~w[lrt rule heading category scope person person_verb person_ii person_ii_verb process place plant property],
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
  def get_fitness(%Fitness{} = fitness, opts \\ []) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Map.put(:formula, formula(fitness))

    Get.get(opts.base_id, opts.table_id, opts)
    |> elem(1)
    |> Enum.map(&extract_fields/1)
    |> Enum.map(&Fitness.make_fitness_struct/1)

    # |> Enum.map(fn x -> struct(%Fitness{}, x) end)
    # |> dbg()
  end

  defp extract_fields(%{"id" => id} = record) do
    Map.put(record["fields"], "record_id", id)
  end

  defp formula(fitness) do
    formula =
      Enum.reduce(Map.from_struct(fitness), [], fn
        # Single select strings
        {k, v}, acc
        when k in [
               :category,
               :scope,
               :person_verb,
               :person_ii,
               :person_ii_verb,
               :property,
               :plant
             ] and
               v not in ["", nil] ->
          term = Atom.to_string(k)
          [~s/{#{term}}="#{v}"/ | acc]

        # Multi-select arrays
        {k, v}, acc
        when k in [
               :person,
               :process,
               :place
             ] and
               is_list(v) and v != [] ->
          term = Atom.to_string(k)
          Enum.map(v, fn x -> ~s/FIND("#{x}", {#{term}})/ end) ++ acc

        _, acc ->
          acc
      end)

    ~s/AND(#{Enum.join(formula, ",")})/
    |> IO.inspect(label: "FORMULA")
  end
end
