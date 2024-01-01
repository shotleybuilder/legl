defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field

  Duty type for 'sections' is a roll-up (aggregate) of the duty types for seb-sections
  """
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib

  @type duty_types :: list()
  @type dutyholders :: list()
  @type dutyholders_gvt :: list()
  @type opts :: map()

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

  def print_duty_types_to_console, do: Enum.each(@duty_type_taxa, &IO.puts(~s/"#{&1}"/))

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Duty_Type",
    fields: ["ID", "Record_Type", "Text"],
    filesave?: true
  }

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/at_duty_type_taxa/duty.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/at_duty_type_taxa/records_results.json]

  @type records :: list(%AtTaxa{})

  def api_duty_type(opts) do
    json = @path |> Path.absname() |> File.read!()
    %{"records" => records} = Jason.decode!(json)
    api_duty_type(records, opts)
  end

  @doc """
  Function to enumerate the Article Table records for Duty Type
  """
  @spec api_duty_type(records()) :: {:ok, records()}
  def api_duty_type(records, opts) do
    records =
      records
      |> Enum.map(&process_record(&1, opts))
      |> Enum.reverse()
      |> revise_dutyholder()

    if opts.filesave? == true, do: Legl.Utility.save_structs_as_json(records, @results_path)
    IO.puts("Duty Type complete")
    {:ok, records}
  end

  @spec process_record(%AtTaxa{}, opts()) :: %AtTaxa{}
  defp process_record(%AtTaxa{Record_Type: record_type} = record, _)
       when record_type in [["part"], ["chapter"], ["heading"]] and is_map(record),
       do: record

  defp process_record(%AtTaxa{Record_Type: ["section"], Text: text} = record, opts) do
    case Regex.match?(~r/\n/, text) do
      true -> classes(record, text, opts)
      false -> record
    end
  end

  defp process_record(%AtTaxa{Record_Type: record_type, Text: text} = record, opts)
       when is_binary(text) and text not in ["", nil] and
              record_type in [["sub-section"], ["article"], ["sub-article"]] do
    classes(record, text, opts)
  end

  defp process_record(record, _), do: record

  @spec classes(%AtTaxa{}, binary(), opts()) :: %AtTaxa{}
  defp classes(record, text, opts) do
    {dutyholders, duty_types_gvd} = DutyTypeLib.duty_types_for_dutyholders(record, text, opts)

    {dutyholders_gvt, duty_types_gvt} =
      DutyTypeLib.duty_types_for_dutyholders_gvt(record, text, opts)

    duty_types_generic = DutyTypeLib.duty_types_generic(text)

    # IO.inspect(text)
    # IO.puts(~s/Dutyholders: #{Enum.join(dutyholders)}/)
    # IO.puts(~s/Dutyholders gvt: #{Enum.join(dutyholders_gvt)}/)
    # IO.puts(~s/Duty types: #{Enum.join(duty_types)}/)
    # IO.puts(~s/Duty types gvt: #{Enum.join(duty_types_gvt)}/)
    # IO.puts(~s/#{duty_types_gvd} #{duty_types_gvt} #{duty_types_generic}/)
    duty_types = duty_types_gvd ++ duty_types_gvt ++ duty_types_generic

    duty_types =
      if duty_types == [],
        do: ["Process, Rule, Constraint, Condition"],
        else:
          duty_types
          |> Enum.filter(fn x -> x != nil end)
          # |> Enum.reverse()
          |> Enum.uniq()
          |> Enum.sort()

    record =
      Map.merge(
        record,
        %{
          Dutyholder: dutyholders,
          "Dutyholder Gvt": dutyholders_gvt,
          "Duty Type": duty_types
        }
      )

    #    if record."Duty Actor" not in [nil, "", []] and
    #         record."Duty Type" == ["Process, Rule, Constraint, Condition"] and
    #         record."Record_Type" in [["article"], ["sub-article"]],
    #       do: IO.puts(~s/
    #      Text: #{record."Text"}
    #      Duty Actor: #{record."Duty Actor"}
    #      Duty Actor Gvt: #{record."Duty Actor Gvt"}
    #      Dutyholder: #{record."Dutyholder"}
    #      Dutyholder Gvt: #{record."Dutyholder Gvt"}
    #      Duty Type: #{record."Duty Type"}
    #      /)

    record
  end

  @doc """
  Function that revises the dutyholder tag based on the outcome of the duty type tag.
  Eg, amendment clauses to not have dutyholders
  """
  def revise_dutyholder(records) do
    records
    |> Enum.reduce([], fn record, acc ->
      case Map.get(record, :"Duty Type") do
        x when x in [["Amendment"], ["Repeal, Revocation"], ["Interpretation, Definition"], []] ->
          Map.put(record, :Dutyholder, [])
          |> (&[&1 | acc]).()

        _ ->
          [record | acc]
      end
    end)
  end

  def workflow(opts \\ []) do
    with(
      {:ok, records} <- get(opts),
      {:ok, records} <- api_duty_type(records),
      {:ok, records} <- aggregate(records)
    ) do
      patch(records)
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def workflow_(opts \\ []) do
    with(
      {:ok, records} <- api_duty_type(opts),
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
