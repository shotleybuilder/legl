defmodule Legl.Countries.Uk.SiCode do
  @moduledoc """
  Module automates read of the SI Code for a piece of law and posts the result into Airtable.

  Required parameter is the name of the base with the SI Code field.

  Currently this is -
    UK 🇬🇧️ E 💚️.  The module accepts 'UK E' w/o the emojis.
  """
  alias Legl.Services.Airtable.AtBases
  alias Legl.Services.Airtable.AtTables
  alias Legl.Services.Airtable.Records

  def get_at_records_with_empty_si_code(base_name) do
    with(
      {:ok, {base_id, table_id}} <- get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
          fields: ["Name", "SI Code", "leg.gov.uk intro text"],
          formula: ~s/{SI Code}="Empty"/}
        },
      {:ok, {jsonset, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      {:ok, {jsonset, recordset}}
    else
      {:error, error} -> {:error, error}
    end
  end

  def get_si_code_from_legl_gov_uk(records) do

  end

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
