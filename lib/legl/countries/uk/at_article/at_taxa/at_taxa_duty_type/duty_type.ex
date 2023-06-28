defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field

  Duty type for 'sections' is a roll-up (aggregate) of the duty types for seb-sections
  """
  alias Legl.Services.Airtable.AtBasesTables
  # alias Legl.Countries.Uk.UkAirtable, as: AT
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib, as: Lib

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
    "Charge, Fee",
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
    fields: ["ID", "Record_Type", "Text"],
    filesave?: true
  }

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/at_duty_type_taxa/duty.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/at_duty_type_taxa/records_results.json]

  def workflow(opts \\ []) do
    with(
      {:ok, records} <- get(opts),
      {:ok, records} <- process(records),
      {:ok, records} <- aggregate(records)
    ) do
      patch(records)
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def workflow_() do
    with(
      {:ok, records} <- process(),
      {:ok, records} <- aggregate(records)
    ) do
      patch(records)
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def get(opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    opts =
      Map.put(
        opts,
        :formula,
        ~s/AND({UK}="#{opts.at_id}", OR({Record_Type}="section", {Record_Type}="sub-section"))/
      )

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
      if opts.filesave? == true, do: Legl.Utility.save_at_records_to_file(~s/#{jsonset}/, @path)

      {:ok, recordset}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  @process_opts %{filesave?: true, field: :"Duty Type"}

  def process() do
    json = @path |> Path.absname() |> File.read!()
    %{"records" => records} = Jason.decode!(json)
    process(records)
  end

  def process(records, opts \\ []) do
    opts = Enum.into(opts, @process_opts)
    # IO.inspect(records)

    records =
      Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
        classes = classes(fields)
        fields = Map.put(fields, opts.field, classes)

        [Map.put(record, :fields, fields) | acc]
      end)
      |> Enum.reverse()

    if opts.filesave? == true, do: save_results_as_json(records)

    {:ok, records}
  end

  defp classes(%{Record_Type: ["section"], aText: aText} = fields) when is_map(fields) do
    case Regex.match?(~r/\n/, aText) do
      true -> classes(aText)
      false -> []
    end
  end

  defp classes(%{aText: aText} = fields) when is_map(fields) do
    classes(aText)
  end

  defp classes(aText) when is_binary(aText) do
    Lib.workflow(aText)
  end

  def save_results_as_json(records) do
    Legl.Utility.save_at_records_to_file(~s/#{Jason.encode!(records)}/, @results_path)
  end

  @doc """
  Function aggregates seb-section and sub-article duty type tag at the level of section.
  """
  def aggregate(records_results) do
    sections =
      Enum.reduce(records_results, %{}, fn %{fields: fields} = record, acc ->
        case Map.get(fields, :Record_Type) do
          ["section"] ->
            case Regex.run(
                   ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                   Map.get(fields, :ID)
                 ) do
              nil ->
                IO.puts("ERROR: #{inspect(record)}")

              [id] ->
                Map.put(acc, id, {Map.get(record, :id), Map.get(fields, :"Duty Type (Script)")})
            end

          _ ->
            acc
        end
      end)

    # Builds a map with this pattern
    # %{Section ID number => {record_id, [duty types]}, ...}

    sections =
      Enum.reduce(records_results, sections, fn %{fields: fields} = _record, acc ->
        case Map.get(fields, :Record_Type) do
          ["sub-section"] ->
            [id] =
              Regex.run(
                ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                Map.get(fields, :ID)
              )

            {record_id, duty_types} = Map.get(acc, id)
            duty_types = (duty_types ++ Map.get(fields, :"Duty Type (Script)")) |> Enum.uniq()
            Map.put(acc, id, {record_id, duty_types})

          _ ->
            acc
        end
      end)

    # Builds a list of maps where the aggregate for the sub-section's parent section
    # is stored against the sub-section

    Enum.reduce(records_results, [], fn %{fields: fields} = record, acc ->
      case Map.get(fields, :Record_Type) do
        x when x in [["section"], ["sub-section"]] ->
          case Regex.run(
                 ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                 Map.get(fields, :ID)
               ) do
            nil ->
              IO.puts("ERROR: #{inspect(record)}")

            [id] ->
              {_, duty_types} = Map.get(sections, id)

              fields = Map.put(fields, :"Duty Type Aggregate (Script)", duty_types)

              [Map.put(record, :fields, fields) | acc]
          end

        _ ->
          [record | acc]
      end
    end)
    |> (&{:ok, &1}).()
  end

  @doc """
  Function that revises the dutyholder tag based on the outcome of the duty type tag.
  Eg, amendment clauses to not have dutyholders
  """
  def revise_dutyholder(records) do
    records
    |> Enum.reduce([], fn %{fields: fields} = record, acc ->
      case Map.get(fields, :"Duty Type") do
        x when x in [["Amendment"], ["Repeal, Revocation"], ["Interpretation, Definition"], []] ->
          Map.put(fields, :Dutyholder, [])
          |> (&Map.put(record, :fields, &1)).()
          |> (&[&1 | acc]).()

        _ ->
          [record | acc]
      end
    end)
    |> (&{:ok, &1}).()
  end

  def patch(results, opts \\ []) do
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

    # Airtable only accepts sets of 10x records in a single PATCH request
    results =
      Enum.chunk_every(results, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.put(%{}, "records", set)
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(results, fn result_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(result_subset, headers, params)
    end)
  end
end
