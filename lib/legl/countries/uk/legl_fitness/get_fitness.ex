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
    fields: ~w[lrt rule heading category subject scope person process place],
    view: ""
  }

  def get_fitness(%Fitness{} = lft, opts \\ []) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Map.put(:formula, formula(lft))

    Get.get(opts.base_id, opts.table_id, opts)
    |> elem(1)
    |> Enum.map(&extract_fields/1)
  end

  defp extract_fields(%{"id" => id} = record) do
    Map.put(record["fields"], "record_id", id)
  end

  defp formula(lft) do
    formula =
      Enum.reduce(Map.from_struct(lft), [], fn
        {k, v}, acc
        when k in [:category, :scope, :person, :people, :place] and
               v not in ["", nil] ->
          term = Atom.to_string(k)
          [~s/{#{term}}="#{v}"/ | acc]

        _, acc ->
          acc
      end)

    ~s/AND(#{Enum.join(formula, ",")})/
  end
end
