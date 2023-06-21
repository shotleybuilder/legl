defmodule Legl.Countries.Uk.AtDutyTypeTaxa.DutyType do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field
  """
  alias Legl.Services.Airtable.AtBasesTables
  # alias Legl.Countries.Uk.UkAirtable, as: AT
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtDutyTypeTaxa.DutyTypeLib, as: Lib

  @duty_type_taxa [
    # Why of the law
    "Purpose",
    # Duty placed on those within scope of the law
    "Duty",
    "Right",
    # What, where and when of the law
    "Enaction, Citation, Commencement",
    "Interpretation, Definition",
    "Application, Scope",
    "Extension",
    "Exemption",
    "Transitional Arrangement",
    "Amendment",
    # Duty placed on government, regulators, etc.
    "Responsibility",
    "Discretionary",
    "Power Conferred",
    "Process, Rule, Constraint, Condition",

    # How of the law
    "Charges, Fees",
    "Offence",
    "Enforcement, Prosecution",
    "Defence, Appeal",
    # What, where and when of the law
    "Repeal, Revocation"
  ]

  @default_duty_type "Process, Rule, Constraint, Condition"

  @at_id "UK_ukpga_1990_43_EPA"

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Duty_Type",
    at_id: @at_id,
    fields: ["Text"],
    filesave?: true
  }

  @path ~s[lib/legl/countries/uk/at_duty_type_taxa/duty.json]

  def get_duty_types(opts \\ []) do
    opts = Enum.into(opts, @default_opts)
    opts = Map.put(opts, :formula, ~s/AND({UK}="#{opts.at_id}", {Record_Type}="sub-section")/)

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
      {:ok, {jsonset, recordset}} <- Records.get_records({[], []}, params)
    ) do
      if opts.filesave? == true do
        Legl.Utility.save_at_records_to_file(~s/#{jsonset}/, @path)
      else
        {:ok, recordset}
      end
    else
      {:error, error} ->
        IO.inspect(error)
    end
  end

  def process_records() do
    json = @path |> Path.absname() |> File.read!()
    %{"records" => records} = Jason.decode!(json)
    # IO.inspect(records)
    Enum.reduce(records, [], fn %{"id" => id, "fields" => fields} = _record, acc ->
      case duty_type?(fields["Text"]) do
        %{tag: nil} ->
          [%{"id" => id, "fields" => %{"Duty Type (Script)" => [""]}} | acc]

        %{tag: class} ->
          [%{"id" => id, "fields" => %{"Duty Type (Script)" => ["#{class}"]}} | acc]
      end
    end)

    # Default duty_type
    |> Enum.reduce([], fn %{"id" => id, "fields" => fields} = record, acc ->
      case fields["Duty Type (Script)"] do
        [""] ->
          [%{"id" => id, "fields" => %{"Duty Type (Script)" => ["#{@default_duty_type}"]}} | acc]

        _ ->
          [record | acc]
      end
    end)

    # Airtable only accepts sets of 10x records in a single PATCH request
    |> Enum.chunk_every(10)
    |> Enum.reduce([], fn set, acc ->
      Map.put(%{}, "records", set)
      |> Jason.encode!()
      |> (&[&1 | acc]).()
    end)
  end

  def duty_type?(text) do
    Enum.reduce_while(@duty_type_taxa, %{tag: nil}, fn class, acc ->
      function = duty_type_taxa_functions(class)
      regex = Lib.regex(function)

      if regex != nil do
        case Regex.match?(regex, text) do
          true -> {:halt, Map.put(acc, :tag, class)}
          false -> {:cont, acc}
        end
      else
        {:cont, acc}
      end
    end)
  end

  def patch_at(results, opts \\ []) do
    opts = Enum.into(opts, @default_opts)
    headers = [{:"Content-Type", "application/json"}]
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name, opts.table_name)

    params = %{
      base: base_id,
      table: table_id,
      options: %{
        view: opts.view
      }
    }

    Enum.each(results, fn result_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(result_subset, headers, params)
    end)
  end

  def duty_type_taxa_functions(class),
    do:
      String.downcase(class)
      |> (&String.replace(&1, ", ", "_")).()
      |> (&String.replace(&1, " ", "_")).()
      |> (&String.to_atom/1).()
end
