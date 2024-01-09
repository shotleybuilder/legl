defmodule Legl.Countries.Uk.Article.Taxa.TaxaPopimar.Popimar do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field

  Duty type for 'sections' is a roll-up (aggregate) of the duty types for seb-sections
  """
  alias Legl.Services.Airtable.AtBasesTables
  # alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa
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
    "Aspects and Hazards",
    "Planning & Risk / Impact Assessment",
    "Risk Control",
    "Notification",
    "Maintenance, Examination and Testing",
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

  @process_opts %{filesave?: false, field: :POPIMAR, path: @results_path}

  @duty_types MapSet.new([
                "Duty",
                "Right",
                "Responsibility",
                "Discretionary",
                "Process, Rule, Constraint, Condition"
              ])

  # Paste the first line of the article of interest
  @qa_text "2 A person involved in the carriage of dangerous goods—"

  def process() do
    json = @path |> Path.absname() |> File.read!()
    %{"records" => records} = Jason.decode!(json)
    process(records)
  end

  def process(records) do
    opts = @process_opts

    records =
      Enum.map(records, &Map.put(&1, :POPIMAR, process_record(&1)))
      |> Enum.reverse()

    if opts.filesave? == true, do: Legl.Utility.save_structs_as_json(records, opts.path)
    IO.puts("POPIMAR complete")
    {:ok, records}
  end

  @spec process_record(%LATTaxa{}) :: list()
  defp process_record(%LATTaxa{Text: text, Record_Type: rt, "Duty Type": dt})
       when text not in ["", nil] do
    # IO.inspect(dt, label: "duty_types")
    case member?(dt) do
      true ->
        popimar_type?({dt, rt, text})

      false ->
        []
    end
  end

  defp process_record(_), do: []

  def member?([]), do: false

  def member?(dt) do
    Enum.map(dt, &MapSet.member?(@duty_types, &1))
    |> Enum.any?()
  end

  @doc """
  Function returns all the members of the POPIMAR taxonomy that match the
  text. POPIMAR is a multi-select field and therefore can support multiple
  entries, but this comes at the cost time to parse
  """
  def popimar_type?({dt, ["section"], text}) do
    case String.contains?(text, "\n") do
      true -> popimar_type?({dt, nil, text})
      false -> []
    end
  end

  def popimar_type?({dt, _, text}) do
    type =
      Enum.reduce(@popimar_taxa, [], fn class, acc ->
        function = duty_type_taxa_functions(class)
        regex = Lib.regex(function)

        # if String.starts_with?(text, @qa_text), do: IO.puts(~s/#{inspect(regex)}\n#{text}/)

        if regex != nil do
          case Regex.match?(regex, text) do
            true ->
              # IO.puts(~s/#{inspect(regex)}\n#{text}/)
              acc ++ [class]

            false ->
              acc
          end
        else
          acc
        end
      end)

    # Default POPIMAR
    if type == [] and
         Enum.any?(dt, fn x ->
           Enum.member?(["Duty", "Process, Rule, Constraint, Condition"], x)
         end),
       do: type ++ ["Risk Control"],
       else: type
  end

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
                Map.put(acc, id, {Map.get(record, :id), Map.get(fields, :"POPIMAR (Script)")})
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
            duty_types = (duty_types ++ Map.get(fields, :"POPIMAR (Script)")) |> Enum.uniq()
            Map.put(acc, id, {record_id, duty_types})

          _ ->
            acc
        end
      end)

    # Updates records where the aggregate for the sub-section's parent section
    # and that section is stored in the POPIMAR Aggregate field of the record

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

              fields = Map.put(fields, :"POPIMAR Aggregate (Script)", duty_types)

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

  def popimar_sorter(dt) do
    proxy = %{
      "Policy" => "1Policy",
      "Organisation" => "2Organisation",
      "Organisation - Control" => "3Organisation - Control",
      "Organisation - Communication & Consultation" =>
        "4Organisation - Communication & Consultation",
      "Organisation - Collaboration, Coordination, Cooperation" =>
        "5Organisation - Collaboration, Coordination, Cooperation",
      "Organisation - Competence" => "6Organisation - Competence",
      "Organisation - Costs" => "7Organisation - Costs",
      "Records" => "8Records",
      "Permit, Authorisation, License" => "9Permit, Authorisation, License",
      "Notification" => "10Notification",
      "Planning & Risk / Impact Assessment" => "11Planning & Risk / Impact Assessment",
      "Aspects and Hazards" => "12Aspects and Hazards",
      "Risk Control" => "13Risk Control",
      "Maintenance, Examination and Testing" => "14Maintenance, Examination and Testing",
      "Checking, Monitoring" => "15Checking, Monitoring",
      "Review" => "16Review",
      "Audit" => "17Audit"
    }

    reverse_proxy = Enum.reduce(proxy, %{}, fn {k, v}, acc -> Map.put(acc, v, k) end)

    dt
    |> Enum.map(&Map.get(proxy, &1))
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort(NaturalOrder)
    |> Enum.map(&Map.get(reverse_proxy, &1))
  end
end
