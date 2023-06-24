defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.Dutyholder do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field

  Duty type for 'sections' is a roll-up (aggregate) of the duty types for seb-sections
  """
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib, as: Lib

  @default_dutyholder ""

  @at_id "UK_ukpga_1990_43_EPA"

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Taxa",
    at_id: @at_id,
    fields: ["ID", "Record_Type", "Text", "Duty Type", "Duty Type Aggregate"],
    filesave?: true
  }

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/at_taxa_dutyholder/dutyholder.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/at_taxa_dutyholder/records_results.json]

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

  @process_opts %{filesave?: true, field: :Dutyholder, path: @results_path}

  def process() do
    json = @path |> Path.absname() |> File.read!()
    %{"records" => records} = Jason.decode!(json)
    process(records)
  end

  def process(records, opts \\ []) do
    opts = Enum.into(opts, @process_opts)

    records =
      Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
        classes = Lib.workflow(Map.get(fields, :Text))

        fields = Map.put(fields, opts.field, classes)

        [Map.put(record, :fields, fields) | acc]
      end)
      |> Enum.reverse()

    if opts.filesave? == true, do: save_results_as_json(records, opts.path)

    {:ok, records}
  end

  def save_results_as_json(records_results, path) do
    results_json = Jason.encode!(records_results)

    Legl.Utility.save_at_records_to_file(~s/#{results_json}/, path)
  end

  @doc """
  Function aggregates seb-section and sub-article duty type tag at the level of section.
  """
  def aggregate(records) do
    sections =
      Enum.reduce(records, %{}, fn %{fields: fields} = record, acc ->
        case Map.get(fields, :Record_Type) do
          ["section"] ->
            case Regex.run(
                   ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                   Map.get(fields, :ID)
                 ) do
              nil ->
                IO.puts("ERROR: #{inspect(record)}")

              [id] ->
                Map.put(acc, id, {record.id, Map.get(fields, :Dutyholder)})
            end

          _ ->
            acc
        end
      end)

    # Builds a map with this pattern
    # %{Section ID number => {record_id, [duty types]}, ...}

    sections =
      Enum.reduce(records, sections, fn %{fields: fields} = _record, acc ->
        case Map.get(fields, :Record_Type) do
          ["sub-section"] ->
            [id] =
              Regex.run(
                ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                Map.get(fields, :ID)
              )

            {record_id, duty_types} = Map.get(acc, id)
            duty_types = (duty_types ++ Map.get(fields, :Dutyholder)) |> Enum.uniq()
            Map.put(acc, id, {record_id, duty_types})

          _ ->
            acc
        end
      end)

    # Builds a list of maps where the aggregate for the sub-section's parent section
    # is stored against the sub-section

    Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
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

              fields = Map.put(fields, :"Dutyholder Aggregate", duty_types)

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

  def duty_type_taxa_functions(class),
    do:
      String.downcase(class)
      |> (&String.replace(&1, "-", "")).()
      |> (&String.replace(&1, "&", "")).()
      |> (&String.replace(&1, "/", "")).()
      |> (&Regex.replace(~r/[ ]{2,}/, &1, " ")).()
      |> (&String.replace(&1, ", ", "_")).()
      |> (&String.replace(&1, " ", "_")).()
      |> (&String.to_atom/1).()
end
