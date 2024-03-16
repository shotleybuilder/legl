defmodule Legl.Countries.Uk.LeglInterpretation.Interpretation do
  @moduledoc """
  Functions to parse interpretation / definitions in law

  Enumerates a list of %UK.Act{} or %UK.Regulation{} structs

  File input saved as at_schema.json
  """

  alias Legl.Countries.Uk.LeglRegister.Crud.Read, as: LRRead
  alias Legl.Countries.Uk.LeglArticle.Article
  alias Legl.Countries.Uk.LeglInterpretation.Read, as: LIRead

  @type legal_article_interpretation :: %__MODULE__{
          Term: String.t(),
          Definition: String.t(),
          Linked_LRT_Records: list()
        }

  defstruct Term: "",
            Definition: "",
            Linked_LRT_Records: []

  @doc """
  Function is called for stand-alone processing of terms & definitions

  The function reads records from the LRT before processing
  """
  def api_interpretation(opts) do
    # Read records from LRT
    LRRead.api_read(opts)
    |> process(opts)
  end

  # INTERNAL but TESTED FUNCTIONS

  def process([], _), do: IO.puts("No records returned")

  def process(records, opts) do
    # todo get and parse the content of the law
    opts =
      opts
      |> Map.put(:article_workflow_name, :"Original -> Clean -> Parse -> Airtable")
      |> Map.put(:html?, true)
      |> Map.put(:pbs?, false)
      |> Map.put(:country, :uk)

    records =
      Enum.reduce(records, [], fn record, acc ->
        opts =
          opts
          |> Map.put(:Name, Map.get(record, :Name))
          |> Map.put(:type, set_type(Map.get(record, :type_class)))

        Article.api_article(opts)
        |> elem(1)
        |> parse_interpretation_section()
        |> build_interpretation_struct()
        |> Enum.map(&Map.put(&1, :Linked_LRT_Records, [Map.get(record, :record_id)]))
        |> IO.inspect()
        |> Enum.concat(acc)
        |> tag_for_create_or_update()
      end)

    Enum.each(records, &build(&1, opts))
  end

  @doc """
  Function to parse definitions when they are contained within an
  'Interpretation' section

  """
  def parse_interpretation_section(records) do
    filter_interpretation_sections(records)
    |> Enum.reduce([], fn %{text: text}, acc ->
      interpretation_patterns()
      |> Enum.reduce(acc, fn regex, acc2 ->
        case Regex.scan(regex, String.trim(text)) do
          [] ->
            acc2

          result ->
            acc2 ++ process_regex_scan_result(result)
        end
      end)
    end)
  end

  @doc """
  Function to compare results with records in the LIT

  Term is missing -> Create new record
  Term is present w/ law listed and matching defn -> No action - Record unchanged
  Term is present w/ law listed but w/o matching defn
    If the law is the only definer -> Update definition
    If the law is one of many definers -> Delete linked law in original record & Create new record
  Term is present w/ matching defn but law not listed as a definer -> Update linked record field
  Term is present w/o matching defn -> Create new record

  Term Present? -n-> CREATE RECORD
  -y->

  Term defined by this law?
  -y-> Definition changed?
  -n-> NO ACTION
  -y-> Multiple defining laws?
  -y-> CREATE RECORD
  -n-> UPDATE 'Definition' field

  Term defined by this law?
  -n-> Definition present?
  -y-> UPDATE 'Defined_By' field
  -n-> CREATE RECORD
  """

  def tag_for_create_or_update(records, at_records \\ nil) do
    Enum.reduce(records, [], fn
      %__MODULE__{Term: term, Linked_LRT_Records: [record_id]} = record, acc ->
        # Allows the function to be tested w/o calling the Base
        at_records =
          case at_records do
            nil -> LIRead.api_lit_read(term: term)
            _ -> at_records
          end

        case at_records do
          # Term not present
          [] ->
            record
            |> Map.from_struct()
            |> Map.put(:action, :post)
            |> (&[&1 | acc]).()

          # Term present
          _ ->
            case term_defined_by_this_law?(at_records, record) do
              false ->
                case definition_present?(at_records, record) do
                  false ->
                    record
                    |> Map.from_struct()
                    |> Map.put(:action, :post)
                    |> (&[&1 | acc]).()

                  [result] ->
                    linked_lrt_records = [record_id | result."Linked_LRT_Records"]

                    result =
                      Map.merge(result, %{Linked_LRT_Records: linked_lrt_records, action: :patch})

                    [result | acc]

                  result ->
                    IO.puts(
                      ~s/ERROR: #{inspect(result)}\n #{__MODULE__}.tag_for_create_or_update definition_present/
                    )
                end

              [at_record] ->
                case definition_changed?(at_record, record) do
                  false ->
                    acc

                  true ->
                    case multiple_defining_laws?(at_record) do
                      true ->
                        record = record |> Map.from_struct() |> Map.put(:action, :post)

                        linked_lrt_records =
                          at_record."Linked_LRT_Records" -- record."Linked_LRT_Records"

                        at_record =
                          at_record
                          |> Map.put(:Linked_LRT_Records, linked_lrt_records)
                          |> Map.put(:action, :patch)

                        [record, at_record | acc]

                      false ->
                        at_record =
                          at_record
                          |> Map.drop([:Linked_LRT_Records])
                          |> Map.put(:Definition, record."Definition")
                          |> Map.put(:action, :patch)

                        [at_record | acc]
                    end
                end

              at_record ->
                IO.puts(
                  ~s/ERROR: #{inspect(at_record)}\n #{__MODULE__}.tag_for_create_or_update definition_changed?/
                )
            end
        end
    end)
  end

  def build(%{action: :post} = record, opts) when is_map(record) do
    record =
      Map.drop(record, :action)
      |> Legl.Utility.map_filter_out_empty_members()
      |> (&Map.merge(%{}, %{fields: &1})).()
      |> List.wrap()
      |> post(opts)
  end

  def post(record, opts) do
    headers = [{:"Content-Type", "application/json"}]
    params = %{base: opts.base_id, table: opts.table_id, options: %{}}
    json = Map.merge(%{}, %{"records" => record, "typecast" => true}) |> Jason.encode!()
    # IO.inspect(json, label: "__MODULE__", limit: :infinity)
    Legl.Services.Airtable.AtPost.post_records([json], headers, params)
  end

  def build(%{record_id: record_id, action: :patch} = record, opts) when is_map(record) do
    %{id: record_id, fields: Map.drop(record, [:record_id, :action])}
    |> patch(opts)
  end

  defp patch(record, %{patch?: true} = opts) when is_map(record) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    record = Map.merge(%{}, %{"records" => List.wrap(record), "typecast" => true})

    with({:ok, json} <- Jason.encode(record)) do
      Legl.Services.Airtable.AtPatch.patch_records(json, headers, params)
    else
      {:error, %Jason.EncodeError{message: error}} ->
        IO.puts(~s/#{error}/)
        :ok
    end
  end

  defp patch(_, %{patch?: false}), do: :ok

  defp patch(record, %{patch?: patch} = opts) when patch in [nil, ""] do
    patch? = ExPrompt.confirm("\nPatch #{record."Title_EN"}?")
    patch(record, Map.put(opts, :patch?, patch?))
  end

  defp patch(record, opts), do: patch(record, Map.put(opts, :patch?, ""))

  defp patch([], _), do: :ok

  defp term_defined_by_this_law?(results, %{Linked_LRT_Records: [record_id]} = _record) do
    Enum.filter(results, fn %{Linked_LRT_Records: record_ids} ->
      Enum.member?(record_ids, record_id)
    end)
    |> case do
      [] -> false
      result -> result
    end
  end

  defp definition_present?(results, %{Definition: definition} = _record) do
    Enum.filter(results, fn %{Definition: at_definition} ->
      case String.bag_distance(at_definition, definition) do
        x when x > 0.9 -> true
        _ -> false
      end
    end)
    |> case do
      [] -> false
      result -> result
    end
  end

  defp definition_changed?(
         %{Definition: at_definition} = _result,
         %{Definition: definition} = _record
       ) do
    case String.bag_distance(at_definition, definition) do
      x when x > 0.9 -> false
      _ -> true
    end
  end

  defp multiple_defining_laws?(%{Linked_LRT_Records: record_ids}) when is_list(record_ids) do
    case Enum.count(record_ids) do
      1 -> false
      _ -> true
    end
  end

  @spec process_regex_scan_result(list()) :: list()
  def process_regex_scan_result(result) do
    Enum.map(result, fn [_, term, defn] ->
      {term, String.trim(defn)}
    end)
  end

  @spec filter_interpretation_sections(list()) :: list()
  def filter_interpretation_sections(records) do
    Enum.reduce(records, {[], false}, fn
      %{type: "heading", text: text}, {acc, _} ->
        case Regex.match?(~r/[Ii]nterpretation/, text) do
          true -> {acc, true}
          false -> {acc, false}
        end

      %{type: type, text: text} = record, {acc, true} when type in ["article", "sub-article"] ->
        {[Map.put(record, :text, Regex.replace(~r/📌/m, text, "\n")) | acc], true}

      _, acc ->
        acc
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @spec interpretation_patterns() :: list()
  def interpretation_patterns() do
    [
      ~s/“([a-z -]*)”([\\s\\S]*?)(?=(?:\\.$|;\n“|\\]$))/
    ]
    |> Enum.map(&(Regex.compile(&1, "m") |> elem(1)))
  end

  # PRIVATE FUNCTIONS
  @spec build_interpretation_struct(list({term :: binary(), defn :: binary()})) ::
          list(%__MODULE__{})
  defp build_interpretation_struct(records) do
    Enum.map(records, fn {term, defn} -> %__MODULE__{Term: term, Definition: defn} end)
  end

  defp set_type("Act"), do: :act
  defp set_type(_), do: :regulation
end
