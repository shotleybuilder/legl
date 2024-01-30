defmodule Legl.Countries.Uk.AtArticle.Options do
  @moduledoc """
  Module has common option choices for running Legal Register Articles Table operations
  """
  alias Legl.Services.Airtable.AtBasesTables

  @type formula :: list()
  @type opts :: map()

  @spec base_name(map()) :: map()
  def base_name(%{base_name: bn, base_id: id} = opts)
      when bn not in ["", nil] and id not in ["", nil],
      do: opts

  def base_name(opts) do
    {base_name, base_id} =
      case ExPrompt.choose(
             "Choose Base (default EXITS)",
             Enum.map(Legl.Services.Airtable.AtBases.bases(), fn {_, {k, _}} -> k end)
           ) do
        -1 ->
          :ok

        n ->
          Keyword.get(
            Legl.Services.Airtable.AtBases.bases(),
            n |> Integer.to_string() |> String.to_atom()
          )
      end

    Map.merge(
      opts,
      %{base_name: base_name, base_id: base_id}
    )
  end

  @spec table_id(opts()) :: opts()
  def table_id(opts) do
    case Legl.Services.Airtable.AtTables.get_table_id(opts.base_id, opts.table_name) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table_id} ->
        {:ok,
         Map.put(
           opts,
           :table_id,
           table_id
         )}
    end
  end

  @spec base_table_id(map()) :: map()
  def base_table_id(opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    Map.merge(opts, %{base_id: base_id, table_id: table_id})
  end

  @spec name(opts()) :: opts()
  def name(%{Name: n} = opts) when n in ["", nil, []] do
    Map.put(
      opts,
      :Name,
      ExPrompt.string(~s/Name ("")/)
    )
  end

  def name(%{Name: n} = opts) when is_binary(n), do: opts
  def name(%{Name: false} = opts), do: opts
  def name(opts), do: name(%{opts | Name: ""})
end
