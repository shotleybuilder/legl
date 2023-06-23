defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaPopimar.Popimar do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field

  Duty type for 'sections' is a roll-up (aggregate) of the duty types for seb-sections
  """
  alias Legl.Services.Airtable.AtBasesTables
  # alias Legl.Countries.Uk.UkAirtable, as: AT
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaPopimar.PopimarLib, as: Lib

  @popimar_taxa [
    "Policy",
    "Organisation",
    "Organisation - Control",
    "Organisation - Communication & Consultation",
    "Organisation - Collaboration, Coordination, Cooperation",
    "Organisation - Competence",
    "Organisation - Costs",
    "Records",
    "Permit, Authorisation, License",
    "Aspects & Hazards",
    "Planning & Risk / Impact Assessment",
    "Risk Control",
    "Notification",
    "Maintenance, Examination & Testing",
    "Checking, Monitoring",
    "Review"
  ]

  def popimar_functions(), do: Enum.map(@popimar_taxa, &duty_type_taxa_functions(&1))

  @at_id "UK_ukpga_1990_43_EPA"

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Taxa",
    at_id: @at_id,
    fields: ["ID", "Record_Type", "Text", "Duty Type", "Duty Type Aggregate"],
    filesave?: true
  }

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/at_taxa_popimar/popimar.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/at_taxa_popimar/records_results.json]

  def workflow(opts \\ []) do
    with(
      {:ok, records} <- get(opts),
      {:ok, records_results, _results} <- process(records),
      {:ok, records} <- aggregate(records_results)
    ) do
      patch(records)
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def workflow_() do
    with(
      {:ok, records_results, _results} <- process(),
      {:ok, records} <- aggregate(records_results)
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
        ~s/OR(\
AND({UK}="#{opts.at_id}",{Record_Type}="section",\
OR(FIND("Duty",{Duty Type Aggregate})>0,FIND("Right",{Duty Type Aggregate})>0,\
FIND("Responsibility",{Duty Type Aggregate})>0,FIND("Discretionary",{Duty Type Aggregate})>0)),\
AND({UK}="#{opts.at_id}",{Record_Type}="sub-section",\
OR(FIND("Duty",{Duty Type})>0,FIND("Right",{Duty Type})>0,\
FIND("Responsibility",{Duty Type})>0,FIND("Discretionary",{Duty Type})>0))\
)/
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

  @process_opts %{filesave?: true, field: "POPIMAR (Script)", path: @results_path}

  def process() do
    json = @path |> Path.absname() |> File.read!()
    %{"records" => records} = Jason.decode!(json)
    process(records)
  end

  def process(records, opts \\ []) do
    opts = Enum.into(opts, @process_opts)
    # IO.inspect(records)

    results =
      Enum.reduce(records, [], fn %{"id" => id, "fields" => fields} = _record, acc ->
        classes = popimar_type?({fields["Record_Type"], fields["Text"]})
        [%{"id" => id, "fields" => %{"#{opts.field}" => classes}} | acc]
      end)
      |> Enum.reverse()

    records = combine(records, results)

    if opts.filesave? == true, do: save_results_as_json(records, opts.path)

    {:ok, records, results}
  end

  def combine(records, results) do
    Enum.zip(records, results)
    |> Enum.reduce([], fn {m1, m2}, acc ->
      Map.merge(m1, m2, fn
        _k, v1, v1 -> v1
        _k, v1, v2 -> Map.merge(v1, v2)
      end)
      |> (&[&1 | acc]).()
    end)
  end

  def save_results_as_json(records_results, path) do
    results_json = Jason.encode!(records_results)

    Legl.Utility.save_at_records_to_file(~s/#{results_json}/, path)
  end

  @doc """
  Function returns all the members of the duty types taxonomy that match the
  text. Duty Types is a multi-select field and therefore can support multiple
  entries, but this comes at the cost time to parse
  """
  def popimar_type?({["section"], text}) do
    case String.contains?(text, "\n") do
      true -> popimar_type?({nil, text})
      false -> []
    end
  end

  def popimar_type?({_, text}) do
    Enum.reduce(@popimar_taxa, [], fn class, acc ->
      function = duty_type_taxa_functions(class)
      regex = Lib.regex(function)

      if regex != nil do
        case Regex.match?(regex, text) do
          true -> acc ++ [class]
          false -> acc
        end
      else
        acc
      end
    end)
  end

  @doc """
  Function aggregates seb-section and sub-article duty type tag at the level of section.
  """
  def aggregate(records) do
    sections =
      Enum.reduce(records, %{}, fn %{"fields" => fields} = record, acc ->
        case fields["Record_Type"] do
          ["section"] ->
            case Regex.run(
                   ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                   fields["ID"]
                 ) do
              nil ->
                IO.puts("ERROR: #{inspect(record)}")

              [id] ->
                Map.put(acc, id, {record["id"], fields["POPIMAR (Script)"]})
            end

          _ ->
            acc
        end
      end)

    # Builds a map with this pattern
    # %{Section ID number => {record_id, [duty types]}, ...}

    sections =
      Enum.reduce(records, sections, fn %{"fields" => fields} = _record, acc ->
        case fields["Record_Type"] do
          ["sub-section"] ->
            [id] =
              Regex.run(
                ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                fields["ID"]
              )

            {record_id, duty_types} = Map.get(acc, id)
            duty_types = (duty_types ++ fields["POPIMAR (Script)"]) |> Enum.uniq()
            Map.put(acc, id, {record_id, duty_types})

          _ ->
            acc
        end
      end)

    # Updates records where the aggregate for the sub-section's parent section
    # and that section is stored in the POPIMAR Aggregate field of the record

    Enum.reduce(records, [], fn %{"fields" => fields} = record, acc ->
      case fields["Record_Type"] do
        x when x in [["section"], ["sub-section"]] ->
          case Regex.run(
                 ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                 fields["ID"]
               ) do
            nil ->
              IO.puts("ERROR: #{inspect(record)}")

            [id] ->
              {_, duty_types} = Map.get(sections, id)

              fields = Map.put(record["fields"], "POPIMAR Aggregate (Script)", duty_types)

              [Map.put(record, "fields", fields) | acc]
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
