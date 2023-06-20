defmodule Legl.Countries.Uk.AtDutyTypeTaxa.DutyType do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field
  """
  alias Legl.Services.Airtable.AtBasesTables
  # alias Legl.Countries.Uk.UkAirtable, as: AT
  alias Legl.Services.Airtable.Records

  @at_id "UK_ukpga_1990_43_EPA"

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Duty_Type",
    at_id: @at_id,
    fields: ["ID", "Record_Type", "Text"],
    filesave?: true
  }

  @path ~s[lib/legl/uk/at_duty_type_taxa/duty.json]

  def get_duty_types(opts \\ []) do
    opts = Enum.into(opts, @default_opts)
    opts = Map.put(opts, :formula, ~s/{ID}="#{opts.at_id}"/)

    with(
      {:ok, {base_id, table_id}} <-
        AtBasesTables.get_base_table_id(opts.base_name, opts.table_name),
      params = %{
        base: base_id,
        table: table_id,
        options: %{
          view: opts.view,
          fields: opts.fields,
          formula: opts.formula
        }
      },
      {:ok, {_, recordset}} <- Records.get_records({[], []}, params)
    ) do
      if opts.filesave? == true do
        Legl.Utility.save_at_records_to_file(recordset, @path)
      else
        {:ok, recordset}
      end
    else
      {:error, error} ->
        IO.inspect(error)
    end
  end

  def duty_type(record) do
    record
    |> (&Regex.match?(
          ~r/#{duty("[Pp]erson")}/,
          &1
        )).()
  end

  @doc """
  Function to tag sub-sections that impose a duty on persons other than government, regulators and agencies
  The function is a repository of phrases used to assign these duties.
  The phrases are joined together to form a valid regular expression.

  params.  Dutyholder should accommodate intial capitalisation eg [Pp]erson, [Ee]mployer
  """
  def duty(dutyholder) do
    [
      " [No] #{dutyholder} shall",
      " [Tt] #{dutyholder}.*?must use",
      " [Tt]he #{dutyholder}.*?shall",
      " #{dutyholder} (?:shall notify|shall furnish the authority)",
      " [Aa] #{dutyholder} shall not",
      " shall be the duty of any #{dutyholder}"
    ]
    |> Enum.map(fn x -> String.replace(x, " ", "[ ]") end)
    |> Enum.join("|")
  end

  def right() do
    [
      " [Pp]erson.*?may at any time"
    ]
  end
end
