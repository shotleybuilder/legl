defmodule Legl.Countries.Uk.Article.Taxa.LATTaxa do
  @moduledoc """
  Module to generate taxa classes for sub-sections / sub-articles High level

  Legl.Countries.Uk.Article.Taxa.LATTaxa

  workflow -
    1. Loops across all records tagging Duty Actors.  These are roles present in
       the script and this is a 'broad brush' trawl.
    2. Uses those results to seed the next process which is to tag duty types
       and the related dutyholders.
    3. The same duty type process then tags the remaining framework clauses like
       amendments and offences.
    4. The last process sets POPIMAR tags for those records tagged with duties.
  """

  @type legal_article_taxa :: %__MODULE__{
          ID: String.t(),
          Record_Type: list(),
          Text: String.t(),
          #
          Dutyholder: list(),
          Rights_Holder: list(),
          Responsibility_Holder: list(),
          Power_Holder: list(),
          "Duty Actor": list(),
          "Duty Actor Gvt": list(),
          "Duty Type": list(),
          POPIMAR: list(),
          #
          "Dutyholder Aggregate": list(),
          Rights_Holder_Aggregate: list(),
          Responsibility_Holder_Aggregate: list(),
          Power_Holder_Aggregate: list(),
          "Duty Actor Aggregate": list(),
          "Duty Actor Gvt Aggregate": list(),
          "Duty Type Aggregate": list(),
          "POPIMAR Aggregate": list(),
          #
          dutyholder_txt: String.t(),
          rights_holder_txt: String.t(),
          responsibility_holder_txt: String.t(),
          power_holder_txt: String.t(),
          #
          Record_ID: String.t(),
          type_code: String.t(),
          Year: integer(),
          Number: String.t(),
          "Section||Regulation": String.t(),
          Part: String.t(),
          Chapter: String.t(),
          Heading: String.t(),
          regexes: list()
        }

  defstruct ID: nil,
            Record_Type: [],
            Text: "",
            Record_ID: nil,
            type_code: nil,
            Year: nil,
            Number: nil,
            "Section||Regulation": nil,
            Part: nil,
            Chapter: nil,
            Heading: nil,
            #
            Dutyholder: [],
            Rights_Holder: [],
            Responsibility_Holder: [],
            Power_Holder: [],
            "Duty Actor": [],
            "Duty Actor Gvt": [],
            "Duty Type": [],
            POPIMAR: [],
            #
            "Duty Actor Aggregate": [],
            "Duty Actor Gvt Aggregate": [],
            "Dutyholder Aggregate": [],
            Rights_Holder_Aggregate: [],
            Responsibility_Holder_Aggregate: [],
            Power_Holder_Aggregate: [],
            "Duty Type Aggregate": [],
            "POPIMAR Aggregate": [],
            #
            dutyholder_txt: "",
            rights_holder_txt: "",
            responsibility_holder_txt: "",
            power_holder_txt: "",
            regexes: []

  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Countries.Uk.Article.Taxa.Options

  @type taxa :: atom()
  @type opts :: map()

  @path ~s[lib/legl/countries/uk/at_article/taxa/api_source.json]
  @results_path ~s[lib/legl/countries/uk/at_article/taxa/api_results.json]

  def api_update_multi_lat_taxa(opts \\ []) do
    opts = Options.api_update_multi_lat_taxa(opts)

    {:ok, records} = AT.get_records_from_at(opts.lrt_params)

    case Enum.map(records, fn %{"fields" => %{"Name" => name}} -> name end) do
      [name] ->
        opts = Map.put(opts, :Name, name)
        api_update_lat_taxa(opts)

      names when is_list(names) ->
        IO.inspect(names)

        Enum.each(names, fn name ->
          IO.puts(~s/\n______________\nNAME: #{name}\n/)

          api_update_lat_taxa(
            Name: name,
            base_id: opts.base_id,
            filesave?: opts.filesave?,
            base_name: opts.base_name,
            patch?: opts.patch?,
            taxa_workflow: opts.taxa_workflow
          )
        end)
    end
  end

  @doc """
  Function to process models (taxa) for Legal Article Table records

  Workflow is driven by the user options.  Main workflow is 'Update'

  Functions comprising the workflow are passed to update_lat_taxa to be run
  """

  def api_update_lat_taxa(opts \\ []) do
    opts = Options.set_workflow_opts(opts)
    records = get(opts)

    if opts.filesave? == true and opts.source == :web,
      do: Legl.Utility.save_structs_as_json(records, @path)

    update_lat_taxa(records, opts)
  end

  defp update_lat_taxa(records, opts) do
    records =
      Enum.reduce(opts.taxa_workflow, records, fn f, acc ->
        IO.puts(
          ~s/#{:erlang.fun_info(f)[:module]} #{:erlang.fun_info(f)[:name]} #{Enum.count(records)}/
        )

        {:ok, records} =
          case :erlang.fun_info(f)[:arity] do
            1 -> f.(acc)
            2 -> f.(acc, opts)
          end

        records
      end)

    if opts.filesave? == true, do: Legl.Utility.save_structs_as_json(records, @results_path)

    records =
      Enum.sort_by(records, & &1."ID")
      |> Enum.map(fn record ->
        record =
          record
          |> Map.from_struct()
          |> Map.drop([
            :ID,
            :Record_Type,
            :Text,
            :aText,
            :type_code,
            :Year,
            :Number,
            :"Section||Regulation"
          ])
          |> Map.filter(fn {_k, v} -> v != nil end)

        %{"id" => record."Record_ID", "fields" => Map.drop(record, [:Record_ID])}
      end)

    patch? = if opts.patch?, do: opts.patch?, else: ExPrompt.confirm("Patch?")

    if patch? == true, do: patch(records, opts), else: :ok
  end

  def get(%{source: :web} = opts) do
    AT.get_legal_article_taxa_records(opts)
  end

  def get(%{source: :file} = _opts) do
    json = @path |> Path.absname() |> File.read!()
    %{records: records} = Jason.decode!(json, keys: :atoms)
    IO.puts("\n#{Enum.count(records)} Records returned from FILE")
    Enum.map(records, &struct(%__MODULE__{}, &1))
  end

  @doc """
  Function to remove terms and phrases from the text (section etc) that are not
  a dutyholder or duty but could be confused as such.
  The amended text is saved back into the Taxa struct as "aText"
  """

  def pre_process(records, blacklist) do
    Enum.reduce(records, [], fn %{Text: text} = record, acc ->
      Enum.reduce(blacklist, text, fn regex, aText ->
        case Regex.run(~r/#{regex}/m, aText) do
          nil ->
            aText

          _ ->
            Regex.replace(~r/#{regex}/m, aText, "")
        end
      end)
      |> (&Map.put(record, :Text, &1)).()
      |> (&[&1 | acc]).()
    end)
    |> (&{:ok, &1}).()
  end

  defp blacklist() do
    []
  end

  def dutyholder_aggregate(records),
    do: aggregate(records, {:Dutyholder, :"Dutyholder Aggregate"})

  def rightsholder_aggregate(records),
    do: aggregate(records, {:Rights_Holder, :Rights_Holder_Aggregate})

  def responsibility_holder_aggregate(records),
    do: aggregate(records, {:Responsibility_Holder, :Responsibility_Holder_Aggregate})

  def power_holder_aggregate(records),
    do: aggregate(records, {:Power_Holder, :Power_Holder_Aggregate})

  def duty_actor_aggregate(records),
    do: aggregate(records, {:"Duty Actor", :"Duty Actor Aggregate"})

  def duty_actor_gvt_aggregate(records),
    do: aggregate(records, {:"Duty Actor Gvt", :"Duty Actor Gvt Aggregate"})

  def duty_type_aggregate(records), do: aggregate(records, {:"Duty Type", :"Duty Type Aggregate"})

  def popimar_aggregate(records), do: aggregate(records, {:POPIMAR, :"POPIMAR Aggregate"})

  @doc """
  Function aggregates sub-section and sub-article duty type tag at the level of section/article.

  source from :"Duty Actor", :Dutyholder, :"Duty Type", :POPIMAR
  """
  @spec aggregate(struct(), {taxa(), taxa()}) :: {:ok, map()}
  def aggregate(records, {source, aggregate}) do
    keys =
      records
      |> Enum.reduce([], fn
        %{Record_Type: rt} = record, acc when rt == ["section"] or rt == ["article"] ->
          case Regex.run(~r/(.*?)(?:_{2}|_A?\d+A?_|_{2}[A-Z]+|_A?\d+A?_[A-Z]+)$/, record."ID") do
            [_, id] ->
              [{id, record."Record_ID"} | acc]

            _ ->
              IO.puts(~s/ERROR: Regex failed to parse this Record ID: #{record."ID"}/)
              acc
          end

        %{Record_Type: rt} = record, acc when rt == ["part"] ->
          [_, id] = Regex.run(~r/(.*?)(?:_{5}|_{5}[A-Z]+)$/, record."ID")
          [{id, record."Record_ID"} | acc]

        %{Record_Type: rt} = record, acc when rt == ["chapter"] ->
          [_, id] = Regex.run(~r/(.*?)(?:_{4}|_{4}[A-Z]+)$/, record."ID")
          [{id, record."Record_ID"} | acc]

        %{Record_Type: rt} = record, acc when rt == ["heading"] ->
          [_, id] = Regex.run(~r/(.*?)(?:_{3}|_{3}[A-Z]+)$/, record."ID")
          [{id, record."Record_ID"} | acc]

        _record, acc ->
          acc
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

  def patch(results, opts) do
    opts = Options.patch(opts)

    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options:
        %{
          # view: opts.view
        }
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    results =
      Enum.chunk_every(results, 10)
      |> Enum.reduce([], fn set, acc ->
        %{"records" => set, "typecast" => true}
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(results, fn result_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(result_subset, headers, params)
    end)
  end
end
