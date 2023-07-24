defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa do
  @moduledoc """
  Module to generate taxa classes for sub-sections / sub-articles High level
  workflow -
    1. Loops across all records tagging Duty Actors.  These are roles present in
       the script and this is a 'broad brush' trawl.
    2. Uses those results to seed the next process which is to tag duty types
       and the related dutyholders.
    3. The same duty type process then tags the remaining framework clauses like
       amendments and offences.
    4. The last process sets POPIMAR tags for those records tagged with duties.
  """
  @derive {Jason.Encoder, only: [:id, :fields]}

  defstruct [
    :id,
    fields: %{
      ID: "",
      Record_Type: [],
      Text: "",
      aText: "",
      Dutyholder: [],
      "Dutyholder Aggregate": [],
      "Duty Actor": [],
      "Duty Actor Aggregate": [],
      "Duty Type": [],
      "Duty Type Aggregate": [],
      POPIMAR: [],
      "POPIMAR Aggregate": []
    }
  ]

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.Dutyholder
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaPopimar.Popimar

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    fields: ["ID", "Record_Type", "Text"],
    filesave?: true,
    patch?: true,
    source: :web,
    part: nil,
    workflow: [actor: true, dutyType: true, popimar: true, aggregate: true],
    # Set to :false for ID with this pattern UK_ukpga_1949_Geo6/12-13-14/74_CPA
    old_id?: false
  }

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/taxa_source_records.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/records_results.json]

  def set_workflow_opts(opts) do
    opts =
      case Keyword.has_key?(opts, :workflow) do
        true ->
          Keyword.put(
            opts,
            :workflow,
            Keyword.merge(@default_opts.workflow, Keyword.get(opts, :workflow))
          )

        _ ->
          opts
      end

    opts = Enum.into(opts, @default_opts)

    opts = Map.put(opts, :workflow, Enum.into(opts.workflow, %{}))

    Enum.reduce(opts.workflow, opts.fields, fn
      {_k, true}, acc -> acc
      {:actor, false}, acc -> ["Duty Actor" | acc]
      {:dutyType, false}, acc -> ["Duty Type" | acc]
      {:popimar, false}, acc -> ["POPIMAR" | acc]
    end)
    |> (&Map.put(opts, :fields, &1)).()
  end

  def workflow(opts \\ []) do
    opts = set_workflow_opts(opts)

    IO.inspect(opts, label: "OPTIONS")

    with(
      {:ok, records} <- get(opts),
      # Broad sweep to collect all possible roles across the records
      {:ok, records} <- Dutyholder.process(records, field: :"Duty Actor"),
      {:ok, records} <- DutyType.process(records, filesave?: false, field: :"Duty Type"),
      # {:ok, records} <- pre_process(records, blacklist()),

      IO.puts("Duty Actor complete"),
      {:ok, records} <- DutyType.revise_dutyholder(records),
      IO.puts("Duty Type complete"),
      {:ok, records} <- Popimar.process(records, filesave?: false, field: :POPIMAR),
      IO.puts("POPIMAR complete"),
      {:ok, records} <-
        aggregate({:Dutyholder, :"Dutyholder Aggregate"}, records, opts.old_id?),
      IO.puts("Dutyholder Aggregation Complete"),
      {:ok, records} <-
        aggregate({:"Duty Actor", :"Duty Actor Aggregate"}, records, opts.old_id?),
      IO.puts("Duty Actor Aggregation Complete"),
      {:ok, records} <-
        aggregate({:"Duty Type", :"Duty Type Aggregate"}, records, opts.old_id?),
      IO.puts("Duty Type Aggregation Complete"),
      {:ok, records} <- aggregate({:POPIMAR, :"POPIMAR Aggregate"}, records, opts.old_id?),
      IO.puts("POPIMAR Aggregation Complete"),
      {:ok, records} <- aggregate_part_chapter(records, "part", opts.old_id?),
      IO.puts("PART Aggregation Complete"),
      {:ok, records} <- aggregate_part_chapter(records, "chapter", opts.old_id?),
      IO.puts("CHAPTER Aggregation Complete"),
      {:ok, records} <- aggregate_part_chapter(records, "heading", opts.old_id?),
      IO.puts("HEADING Aggregation Complete")
    ) do
      if opts.filesave? == true do
        json = Map.put(%{}, "records", records) |> Jason.encode!()
        Legl.Utility.save_at_records_to_file(~s/#{json}/, @results_path)
      end

      records =
        Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
          Map.drop(fields, [:ID, :Record_Type, :Text, :aText])
          |> (&Map.put(Map.from_struct(record), :fields, &1)).()
          |> (&[&1 | acc]).()
        end)

      if opts.patch? == true, do: patch(records, opts)
      # records
      :ok
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def get(%{source: :file} = _opts) do
    json = @path |> Path.absname() |> File.read!()
    %{records: records} = Jason.decode!(json, keys: :atoms)
    # IO.inspect(records)

    Enum.reduce(records, [], fn record, acc ->
      %{fields: fields} = record = struct(%__MODULE__{}, record)
      fields = Map.put(fields, :aText, Map.get(fields, :Text))

      Map.put(record, :fields, fields)
      |> (&[&1 | acc]).()
    end)
    |> (&{:ok, &1}).()
  end

  def get(%{source: :web} = opts) do
    opts =
      Map.put(
        opts,
        :formula,
        formula(opts)
      )

    with(
      {:ok, {base_id, table_id}} <-
        AtBasesTables.get_base_table_id(opts.base_name, opts.table_name),
      params = %{
        base: base_id,
        table: table_id,
        options: %{
          # view: opts.view,
          fields: opts.fields,
          formula: opts.formula
        }
      },
      {:ok, {jsonset, _recordset}} <- Records.get_records({[], []}, params)
    ) do
      if opts.filesave? == true, do: Legl.Utility.save_at_records_to_file(~s/#{jsonset}/, @path)

      %{records: records} = Jason.decode!(jsonset, keys: :atoms)

      # IO.inspect(recordset)

      Enum.reduce(records, [], fn record, acc ->
        %{fields: fields} = record = struct(%__MODULE__{}, record)
        fields = Map.put(fields, :aText, Map.get(fields, :Text))

        Map.put(record, :fields, fields)
        |> (&[&1 | acc]).()
      end)
      |> (&{:ok, &1}).()
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp formula(opts) do
    formula = [
      ~s/{flow}="main"/,
      ~s/OR({Record_Type}="part", {Record_Type}="chapter", {Record_Type}="heading", {Record_Type}="section", {Record_Type}="sub-section")/
    ]

    formula =
      case opts.at_id do
        "" -> formula
        _ -> formula ++ [~s/{UK}="#{opts.at_id}"/]
      end

    formula =
      cond do
        Regex.match?(~r/[1234567890]/, opts.part) == true ->
          formula ++ [~s/{Part}="#{opts.part}"/]

        true ->
          formula
      end

    formula =
      cond do
        Regex.match?(~r/[1234567890]/, opts.chapter) == true ->
          formula ++ [~s/{Chapter}="#{opts.chapter}"/]

        true ->
          formula
      end

    formula =
      cond do
        Regex.match?(~r/[1234567890]/, opts.section) == true ->
          formula ++ [~s/{Section||Regulation}="#{opts.section}"/]

        true ->
          formula
      end

    ~s/AND(#{Enum.join(formula, ", ")})/
  end

  @doc """
  Function to remove terms and phrases from the text (section etc) that are not
  a dutyholder or duty but could be confused as such.
  The amended text is saved back into the Taxa struct as "aText"
  """

  def pre_process(records, blacklist) do
    Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
      text = Map.get(fields, :Text)

      Enum.reduce(blacklist, text, fn regex, aText ->
        case Regex.run(~r/#{regex}/m, aText) do
          nil ->
            aText

          _ ->
            Regex.replace(~r/#{regex}/m, aText, "")
        end
      end)
      |> (&Map.put(fields, :aText, &1)).()
      |> (&Map.put(record, :fields, &1)).()
      |> (&[&1 | acc]).()
    end)
    |> (&{:ok, &1}).()
  end

  defp blacklist() do
    []
  end

  @doc """
  Function aggregates sub-section and sub-article duty type tag at the level of section.
  """
  def aggregate({source, aggregate}, records, old_id?) do
    regex =
      case old_id? do
        false ->
          ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]*_\d*[A-Z]*_\d*[A-Z]*_\d+[A-Z]*/

        true ->
          # UK_ukpga_1949_Geo6/12-13-14/74_CPA
          # UK_ukpga_1959_Eliz2/7-8/54_WA
          ~r/UK_[a-z]*_\d{4}_.*?_[A-Z]+_\d*[A-Z]*_\d*[A-Z]*_\d*[A-Z]*_\d+[A-Z]*/
      end

    sections =
      Enum.reduce(records, %{}, fn %{fields: fields} = record, acc ->
        case Map.get(fields, :Record_Type) do
          ["section"] ->
            case Regex.run(
                   regex,
                   Map.get(fields, :ID)
                 ) do
              nil ->
                IO.puts("ERROR aggregate/2 sections I: #{inspect(record)}")

              [id] ->
                Map.put(acc, id, {Map.get(record, :id), Map.get(fields, source)})
            end

          _ ->
            acc
        end
      end)

    # Builds a map with this pattern
    # %{Section ID number => {record_id, [duty types]}, ...}

    sections =
      Enum.reduce(records, sections, fn %{fields: fields} = record, acc ->
        case Map.get(fields, :Record_Type) do
          ["sub-section"] ->
            case Regex.run(
                   regex,
                   Map.get(fields, :ID)
                 ) do
              [id] ->
                case Map.get(acc, id) do
                  nil ->
                    IO.puts("ERROR aggregate/2 section IIa:\nID: #{id}")
                    Enum.each(acc, &IO.inspect(&1))

                  _ ->
                    {record_id, duty_types} = Map.get(acc, id)
                    duty_types = (duty_types ++ Map.get(fields, source)) |> Enum.uniq()
                    Map.put(acc, id, {record_id, duty_types})
                end

              nil ->
                IO.puts("ERROR aggregate/2 sections IIb: #{inspect(record)}")
            end

          _ ->
            acc
        end
      end)

    # Updates records where the aggregate for the sub-section's parent section
    # and that section is stored in the POPIMAR Aggregate field of the record

    Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
      case Map.get(fields, :Record_Type) do
        ["section"] ->
          # x when x in [["section"], ["sub-section"]] ->
          case Regex.run(
                 regex,
                 Map.get(fields, :ID)
               ) do
            nil ->
              IO.puts("ERROR aggregate/2 collector: #{inspect(record)}")

            [id] ->
              {_, duty_types} = Map.get(sections, id)

              fields = Map.put(fields, aggregate, duty_types)

              [Map.put(record, :fields, fields) | acc]
          end

        ["sub-section"] ->
          fields = Map.put(fields, aggregate, [])

          [Map.put(record, :fields, fields) | acc]

        _ ->
          [record | acc]
      end
    end)
    |> (&{:ok, &1}).()
  end

  def aggregate_part_chapter(records, record_type, old_id?)
      when record_type in ["part", "chapter", "heading"] do
    regex =
      case old_id? do
        false ->
          ~s/UK_[a-z]*_\\d{4}_\\d+_[A-Z]+/

        true ->
          # UK_ukpga_1949_Geo6/12-13-14/74_CPA
          ~s/UK_[a-z]*_\\d{4}_.*?_[A-Z]+/
      end

    regex =
      cond do
        record_type == "part" ->
          ~r/#{regex}_\d*[A-Z]?/

        record_type == "chapter" ->
          ~r/#{regex}_\d*[A-Z]?_\d*[A-Z]?/

        record_type == "heading" ->
          ~r/#{regex}_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]?/
      end

    aggregator = aggregator(records, record_type, regex)

    case Enum.count(aggregator) do
      0 ->
        {:ok, records}

      _ ->
        aggregator = populate_aggregator(records, aggregator, regex)

        # IO.inspect(aggregator)

        record_aggregate_collector(records, record_type, aggregator, regex)
        |> (&{:ok, &1}).()
    end
  end

  defp aggregator(records, record_type, regex) do
    Enum.reduce(records, %{}, fn %{fields: fields} = record, acc ->
      [recordType | _tl] = Map.get(fields, :Record_Type)

      case record_type == recordType do
        true ->
          case Regex.run(
                 regex,
                 Map.get(fields, :ID)
               ) do
            nil ->
              IO.puts("ERROR: #{inspect(record)}")

            [id] ->
              Map.put(acc, id, {Map.get(record, :id), [], [], [], []})
          end

        _ ->
          acc
      end
    end)
  end

  defp populate_aggregator(records, aggregator, regex) do
    Enum.reduce(records, aggregator, fn %{fields: fields} = record, acc ->
      case Map.get(fields, :Record_Type) do
        ["section"] ->
          case Regex.run(
                 regex,
                 Map.get(fields, :ID)
               ) do
            [id] ->
              case Map.get(acc, id) do
                nil ->
                  IO.puts("No record in aggregator for #{id}")
                  acc

                result ->
                  {record_id, dutyholders, duty_actors, duty_types, popimars} = result

                  dutyholders =
                    (dutyholders ++ Map.get(fields, :"Dutyholder Aggregate")) |> Enum.uniq()

                  duty_actors =
                    (duty_actors ++ Map.get(fields, :"Duty Actor Aggregate")) |> Enum.uniq()

                  duty_types =
                    (duty_types ++ Map.get(fields, :"Duty Type Aggregate")) |> Enum.uniq()

                  popimars = (popimars ++ Map.get(fields, :"POPIMAR Aggregate")) |> Enum.uniq()
                  Map.put(acc, id, {record_id, dutyholders, duty_actors, duty_types, popimars})
              end

            nil ->
              IO.puts("ERROR: #{inspect(record)}")
          end

        _ ->
          acc
      end
    end)
  end

  defp record_aggregate_collector(records, record_type, aggregator, regex) do
    Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
      [recordType | _tl] = Map.get(fields, :Record_Type)

      case record_type == recordType do
        true ->
          case Regex.run(
                 regex,
                 Map.get(fields, :ID)
               ) do
            nil ->
              IO.puts("ERROR: #{inspect(record)}")

            [id] ->
              {_, dutyholders, duty_actors, duty_types, popimars} = Map.get(aggregator, id)

              fields =
                Map.merge(
                  fields,
                  %{
                    "Dutyholder Aggregate": dutyholders,
                    "Duty Actor Aggregate": duty_actors,
                    "Duty Type Aggregate": duty_types,
                    "POPIMAR Aggregate": popimars
                  }
                )

              [Map.put(record, :fields, fields) | acc]
          end

        _ ->
          [record | acc]
      end
    end)
  end

  def patch(results, opts \\ []) do
    opts = Enum.into(opts, @default_opts)
    headers = [{:"Content-Type", "application/json"}]
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name, opts.table_name)

    params = %{
      base: base_id,
      table: table_id,
      options:
        %{
          # view: opts.view
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

  def clear_multi_select() do
    record = [
      %Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa{
        id: "reca0w8xHBLJnH30a",
        fields: %{
          Dutyholder: [""]
        }
      }
    ]

    patch(record)
  end
end
