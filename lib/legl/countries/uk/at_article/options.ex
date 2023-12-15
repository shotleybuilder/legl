defmodule Legl.Countries.Uk.AtArticle.Options do
  @moduledoc """
  Module has common option choices for running Legal Register Articles Table operations
  """
  alias Legl.Services.Airtable.AtBasesTables

  @type formula :: list()
  @type opts :: map()

  @spec base_name(map()) :: map()
  def base_name(%{base_name: bn} = opts) when bn not in ["", nil], do: opts

  def base_name(opts) do
    {base_name, base_id} =
      case ExPrompt.choose(
             "Choose Base (default EXITS)",
             Enum.map(Legl.Services.Airtable.AtBases.bases(), fn {_, {k, _}} -> k end)
           ) do
        -1 ->
          :ok

        n ->
          Map.get(Legl.Services.Airtable.AtBases.bases(), n)
      end

    Map.merge(
      opts,
      %{base_name: base_name, base_id: base_id}
    )
  end

  @spec table_id(opts()) :: opts()
  def table_id(opts) do
    Map.put(
      opts,
      :table_id,
      Legl.Services.Airtable.AtTables.get_table_id(opts.base_id, opts.table_name) |> elem(1)
    )
  end

  @spec base_table_id(map()) :: map()
  def base_table_id(opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    Map.merge(opts, %{base_id: base_id, table_id: table_id})
  end

  @spec name(opts()) :: opts()
  def name(%{name: n} = opts) when n in ["", nil] do
    Map.put(
      opts,
      :name,
      ExPrompt.string(~s/Name ("")/)
    )
  end

  def name(%{name: n} = opts) when is_binary(n), do: opts

  def name(opts), do: name(%{opts | name: ""})
end
