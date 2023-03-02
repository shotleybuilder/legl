defmodule Legl.Services.Airtable.AtBasesTables do

  alias Legl.Services.Airtable.AtBases
  alias Legl.Services.Airtable.AtTables

  def get_base_table_id(base_name) do
    with(
      {:ok, base_id} <- AtBases.get_base_id(base_name),
      {:ok, table_id} <- AtTables.get_table_id(base_id, "uk")
    ) do
      {:ok, {base_id, table_id}}
    else
      {:error, error} -> {:error, error}
    end
  end

end
