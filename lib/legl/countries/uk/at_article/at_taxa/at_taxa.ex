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

  # @derive {Jason.Encoder, only: [:id, :fields]}

  defstruct ID: "",
            Record_Type: [],
            Text: "",
            aText: nil,
            Dutyholder: [],
            "Dutyholder Aggregate": [],
            "Duty Actor": [],
            "Duty Actor Aggregate": [],
            "Duty Type": [],
            "Duty Type Aggregate": [],
            POPIMAR: [],
            "POPIMAR Aggregate": [],
            Record_ID: nil,
            type_code: nil,
            Year: nil,
            Number: nil,
            "Section||Regulation": nil

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtArticle.AtTaxa.Options
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.Dutyholder
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaPopimar.Popimar
  alias Legl.Countries.Uk.AtArticle.AtTaxa.LRTTaxa

  @type taxa :: atom()

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/taxa_source_records.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/records_results.json]

  def workflow(opts \\ []) do
    opts = Options.set_workflow_opts(opts)

    with(
      {:ok, records} <- get(opts),
      # Broad sweep to collect all possible roles across the records
      {:ok, records} <- Dutyholder.process(records, field: :"Duty Actor"),
      # IO.inspect(records),
      {:ok, records} <- DutyType.process(records, filesave?: false, field: :"Duty Type"),
      # {:ok, records} <- pre_process(records, blacklist()),
      # IO.inspect(records),
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
      IO.puts("HEADING Aggregation Complete"),
      IO.inspect(records)
    ) do
      if opts.filesave? == true do
        Enum.sort_by(records, & &1."ID")
        |> Legl.Utility.save_structs_as_json(@results_path)

        # json = Map.put(%{}, "records", records) |> Jason.encode!()
        # Legl.Utility.save_at_records_to_file(~s/#{json}/, @results_path)
      end

      LRTTaxa.workflow(records) |> IO.inspect(limit: :infinity)

      records =
        Enum.map(records, fn record ->
          Map.drop(record, [:ID, :Record_Type, :Text, :aText])
          |> Map.from_struct()
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
    with(
      params = %{
        base: opts.base_id,
        table: opts.table_id,
        options: %{
          # view: opts.view,
          fields: opts.fields,
          formula: opts.formula
        },
        atom?: true
      },
      {:ok, {_jsonset, %{records: records}}} <- Records.get_records({[], []}, params)
    ) do
      if opts.filesave? == true, do: Legl.Utility.save_json(records, @path)

      Enum.reduce(records, [], fn %{fields: record}, acc ->
        struct(%__MODULE__{}, record)
        |> (&[&1 | acc]).()
      end)
      |> (&{:ok, &1}).()
    else
      {:error, error} ->
        {:error, error}
    end
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

  source from :"Duty Actor", :Dutyholder, :"Duty Type", :POPIMAR
  """
  @spec aggregate({taxa(), taxa()}, struct(), atom()) :: {:ok, map()}
  def aggregate({source, aggregate}, records, _old_id?) do
    keys =
      records
      |> Enum.filter(fn %{Record_Type: rt} -> rt == ["section"] or rt == ["article"] end)
      |> Enum.map(fn record ->
        [_, id] = Regex.run(~r/(.*?)(?:_{2}|_\d+_)$/, record."ID")
        {id, record."Record_ID"}
      end)

    aggregates =
      keys
      |> Enum.map(fn {key, record_id} ->
        agg =
          Enum.reduce(records, [], fn record, acc ->
            case String.contains?(record."ID", key) do
              true ->
                acc ++ Map.get(record, source)

              false ->
                acc
            end
          end)
          |> Enum.uniq()

        {record_id, agg}
      end)

    result =
      records
      |> Enum.map(fn %{Record_ID: record_id} = record ->
        case Enum.find(aggregates, fn {id, _agg} -> record_id == id end) do
          nil -> record
          {_id, agg} -> Map.put(record, aggregate, agg)
        end
      end)

    {:ok, result}
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
    Enum.reduce(records, %{}, fn record, acc ->
      [recordType | _tl] = Map.get(record, :Record_Type)

      case record_type == recordType do
        true ->
          case Regex.run(
                 regex,
                 Map.get(record, :ID)
               ) do
            nil ->
              IO.puts("ERROR: #{inspect(record)}")

            [id] ->
              Map.put(acc, id, {Map.get(record, :Record_ID), [], [], [], []})
          end

        _ ->
          acc
      end
    end)
  end

  defp populate_aggregator(records, aggregator, regex) do
    Enum.reduce(records, aggregator, fn record, acc ->
      case Map.get(record, :Record_Type) do
        ["section"] ->
          case Regex.run(
                 regex,
                 Map.get(record, :ID)
               ) do
            [id] ->
              case Map.get(acc, id) do
                nil ->
                  IO.puts("No record in aggregator for #{id}")
                  acc

                result ->
                  {record_id, dutyholders, duty_actors, duty_types, popimars} = result

                  dutyholders =
                    (dutyholders ++ Map.get(record, :"Dutyholder Aggregate")) |> Enum.uniq()

                  duty_actors =
                    (duty_actors ++ Map.get(record, :"Duty Actor Aggregate")) |> Enum.uniq()

                  duty_types =
                    (duty_types ++ Map.get(record, :"Duty Type Aggregate")) |> Enum.uniq()

                  popimars = (popimars ++ Map.get(record, :"POPIMAR Aggregate")) |> Enum.uniq()
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
    Enum.reduce(records, [], fn record, acc ->
      [recordType | _tl] = Map.get(record, :Record_Type)

      case record_type == recordType do
        true ->
          case Regex.run(
                 regex,
                 Map.get(record, :ID)
               ) do
            nil ->
              IO.puts("ERROR: #{inspect(record)}")

            [id] ->
              {_, dutyholders, duty_actors, duty_types, popimars} = Map.get(aggregator, id)

              record =
                Map.merge(
                  record,
                  %{
                    "Dutyholder Aggregate": dutyholders,
                    "Duty Actor Aggregate": duty_actors,
                    "Duty Type Aggregate": duty_types,
                    "POPIMAR Aggregate": popimars
                  }
                )

              [record | acc]
          end

        _ ->
          [record | acc]
      end
    end)
  end

  def patch(results, opts) do
    opts = Options.patch(opts)

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
end
