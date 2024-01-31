defmodule Legl.Countries.Uk.Article.Taxa.TaxaDutyActor.DutyActor do
  @moduledoc """
  Functions to ETL airtable 'Article' table records and code the duty type field

  Duty type for 'sections' is a roll-up (aggregate) of the duty types for seb-sections
  """
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa
  alias ActorDefinitions

  @at_id "UK_ukpga_1990_43_EPA"

  @government ActorDefinitions.government()
  @governed ActorDefinitions.governed()

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Taxa",
    at_id: @at_id,
    fields: ["ID", "Record_Type", "Text", "Duty Type", "Duty Type Aggregate"],
    filesave?: true
  }

  @path ~s[lib/legl/countries/uk/at_article/taxa/duty_actor/duty_actor.json]
  @results_path ~s[lib/legl/countries/uk/legl_article/taxa/duty_actor/duty_actor_results.json]

  @type records :: list(%LATTaxa{})
  @type opts :: map()
  @type actor :: atom()
  @type regex :: binary()
  @type library() :: keyword({actor(), regex()})

  @process_opts %{filesave?: true, results_path: @results_path}

  def process(opts \\ %{}) do
    json = @path |> Path.absname() |> File.read!()
    %{"records" => records} = Jason.decode!(json)
    api_duty_actor(records, opts)
  end

  @spec api_duty_actor(records(), opts()) :: {:ok, records()}
  def api_duty_actor(records, opts) when is_list(records) do
    opts = Map.merge(opts, @process_opts)

    records = process_records(records, opts)

    if opts.filesave? == true, do: Legl.Utility.save_structs_as_json(records, opts.results_path)
    IO.puts("Duty Actor & Duty Actor Gvt complete")
    {:ok, records}
  end

  @spec process_records(records(), opts()) :: records()
  defp process_records(records, opts) when is_list(records) do
    records
    |> Enum.map(&blacklister(&1))
    |> Enum.map(&process_record(&1, :"Duty Actor", opts))
    |> Enum.map(&process_record(&1, :"Duty Actor Gvt", opts))
    |> Enum.reverse()
  end

  defp process_record(%LATTaxa{Text: text} = record, field, opts)
       when is_struct(record) and text not in ["", nil] do
    Map.put(
      record,
      field,
      get_duty_actors_in_text(text, field, opts)
    )
  end

  defp process_record(record, _field, _), do: record

  @spec get_duty_actors_in_text(binary(), :"Duty Actor", opts()) :: list()
  def get_duty_actors_in_text(text, :"Duty Actor", opts) do
    {text, []}
    |> run_duty_actor_regex(@governed, true, opts)
    |> elem(1)
    |> Enum.sort()
  end

  @spec get_duty_actors_in_text(binary(), :"Duty Actor Gvt", opts()) :: list()
  def get_duty_actors_in_text(text, :"Duty Actor Gvt", opts) do
    {text, []}
    |> run_duty_actor_regex(@government, true, opts)
    |> elem(1)
    |> Enum.sort()
  end

  defp blacklister(%LATTaxa{Text: text} = record) do
    text =
      Enum.reduce(ActorDefinitions.blacklist(), text, fn regex, acc ->
        Regex.replace(~r/#{regex}/m, acc, "")
      end)

    Map.put(record, :Text, text)
  end

  @spec run_duty_actor_regex({binary(), []}, library(), boolean(), opts()) :: {binary(), list()}
  defp run_duty_actor_regex(collector, library, rm?, opts) do
    # library = process_library(library)

    Enum.reduce(library, collector, fn {actor, regex}, {text, actors} = acc ->
      regex_c =
        case Regex.compile(regex, "m") do
          {:ok, regex} ->
            # IO.puts(~s/#{inspect(regex)}/)
            regex

          {:error, error} ->
            IO.puts(~s/ERROR: Duty Actor Regex doesn't compile\n#{error}\n#{regex}/)
        end

      case Regex.run(regex_c, text) do
        [match] ->
          actor = Atom.to_string(actor)

          text = if rm?, do: Regex.replace(regex_c, text, ""), else: text

          """
          IO.puts(~s/DUTY ACTOR: #{actor}/)
          IO.puts(~s/MATCH: #{inspect(match)}/)
          IO.puts(~s/REGEX: #{regex}\n/)


          case File.open(
                 ~s[lib/legl/countries/uk/at_article/taxa/duty_actor/_results/#{opts."Name"}.txt],
                 [:append]
               ) do
            {:ok, file} ->
              IO.binwrite(
                file,
                ~s/\nDUTY ACTOR: #{actor}\nMATCH: #{match}\nREGEX: #{regex}\n/
              )

              File.close(file)

            {:error, :enoent} ->
              :ok
          end
          """

          {text, [actor | actors]}

        nil ->
          acc

        match ->
          IO.puts(
            "ERROR:\nText:\n#{text}\nRegex:\n#{regex}\nMATCH:\n#{inspect(match)}\n[#{__MODULE__}.process_dutyholder/3]"
          )
      end
    end)
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
                Map.put(acc, id, {Map.get(record, :id), Map.get(fields, :Dutyholder)})
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
end
