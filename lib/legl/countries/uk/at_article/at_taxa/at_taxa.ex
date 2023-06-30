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

  @at_id "UK_ukpga_1990_43_EPA"

  @dutyholders [
    "[Aa]uthorised person",
    "[Pp]erson",
    "[Hh]older",
    "[Pp]roducer"
  ]

  @dh_regex @dutyholders |> Enum.join("|") |> (fn x -> ~s/(#{x})/ end).()

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Taxa",
    at_id: @at_id,
    fields: ["ID", "Record_Type", "Text"],
    filesave?: true,
    patch?: true,
    source: :file,
    part: nil
  }

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/taxa_source_records.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/records_results.json]

  def workflow(opts \\ []) do
    opts = Enum.into(opts, @default_opts) |> Map.put(:dutyholders, @dutyholders)

    with(
      {:ok, records} <- get(opts.source, opts),
      # Broad sweep to collect all possible roles across the records
      {:ok, records} <- Dutyholder.process(records, filesave?: false, field: :"Duty Actor"),
      {:ok, records} <- DutyType.process(records, filesave?: false, field: :"Duty Type"),
      # {:ok, records} <- pre_process(records, blacklist()),

      IO.puts("Duty Actor complete"),
      {:ok, records} <- DutyType.revise_dutyholder(records),
      IO.puts("Duty Type complete"),
      {:ok, records} <- Popimar.process(records, filesave?: false, field: :POPIMAR),
      IO.puts("POPIMAR complete"),
      {:ok, records} <- aggregate({:Dutyholder, :"Dutyholder Aggregate"}, records),
      {:ok, records} <- aggregate({:"Duty Actor", :"Duty Actor Aggregate"}, records),
      {:ok, records} <-
        aggregate({:"Duty Type", :"Duty Type Aggregate"}, records),
      {:ok, records} <- aggregate({:POPIMAR, :"POPIMAR Aggregate"}, records),
      IO.puts("Aggregation Complete")
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

  def get(:file, _opts) do
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

  def get(:web, opts) do
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
      ~s/{UK}="#{opts.at_id}"/,
      ~s/{flow}="main"/,
      ~s/OR({Record_Type}="section", {Record_Type}="sub-section")/
    ]

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
    [
      # offence
      "(shall be|person) guilty",
      "person shall not be guilty",
      "person is ordered",
      "person shall not be liable",
      "person.*?(shall be|is) liable",
      "person.*?who commits an?",
      "commission by any person",
      "person who fails",
      "person may not be convicted",
      # notices
      "person to be served",
      "person is given a notice",
      "notice served on the holder",
      "notice shall state",
      # assignment
      "person may be charged with",
      "person may be required",
      "person shall be treated",
      "person shall not be qualified",
      "gives?.*?to (the|an?) #{@dh_regex}",
      "authority shall be deemed",
      "(given|to) the Secretary of State",
      # action verbs
      "the person (has|who had)",
      "a person appeals",
      "any other person",
      "different provision in relation to different persons"
      # shall
    ]
  end

  @doc """
  Function aggregates seb-section and sub-article duty type tag at the level of section.
  """
  def aggregate({source, aggregate}, records) do
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
                   ~r/UK_[a-z]*_\d{4}_\d+_[A-Z]+_\d*[A-Z]?_\d*[A-Z]?_\d*[A-Z]*_\d+[A-Z]*/,
                   Map.get(fields, :ID)
                 ) do
              [id] ->
                {record_id, duty_types} = Map.get(acc, id)
                duty_types = (duty_types ++ Map.get(fields, source)) |> Enum.uniq()
                Map.put(acc, id, {record_id, duty_types})

              nil ->
                IO.puts("ERROR: #{inspect(record)}")
            end

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

              fields = Map.put(fields, aggregate, duty_types)

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
