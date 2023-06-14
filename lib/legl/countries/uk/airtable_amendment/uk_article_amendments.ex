defmodule Legl.Countries.Uk.AirtableAmendment.Amendments do
  defstruct [:id, :ef, :text, ids: []]

  alias __MODULE__

  def find_changes(records, opts) do
    IO.puts("Creating Data for the Airtable Amendments Table")
    # 'Changes' field holds list of changes (amendments, mods) applying to that record

    change_stats = [
      amendments: opts.amendments,
      modifications: opts.modifications,
      commencements: opts.commencements,
      extents: opts.extents
    ]

    IO.puts("\nStarting Search for Change Stats")
    # rng = List.last(records).max_amendments |> IO.inspect(label: "Amendments (Fs)")

    Enum.map(records, fn record ->
      Enum.reduce(change_stats, record, fn {_k, {total, code}}, acc ->
        case total == 0 do
          true ->
            acc

          _ ->
            find_change_in_record(code, total, acc)
        end
      end)
    end)
    |> (&{:ok, &1}).()
  end

  @doc """
  Search for the change markers in the provision texts only
  """
  def find_change_in_record(code, rng, %{type: "part"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "chapter]"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "heading"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "section"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "sub-section"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "article"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "sub-article"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "paragraph"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "sub-paragraph"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "annex"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(_code, _rng, record), do: record

  def find_change_in_record({code, rng, record}) do
    Enum.reduce(rng..1, record, fn n, acc ->
      case Regex.match?(~r/#{code}#{n}[ ]/m, record.text) do
        true ->
          changes = [~s/#{code}#{n}/ | acc.changes]
          %{acc | changes: changes}

        false ->
          acc
      end
    end)
  end

  @doc """
  Function creates a space between Ef code and following numeric text.
  eg F1232023 becomes F123 2023
  """
  def separate_ef_codes_from_numerics(records, opts) do
    {max, _} = opts.amendments
    ef_codes = Enum.map(max..1, &Kernel.<>("F", Integer.to_string(&1)))
    ef_size = String.length(List.first(ef_codes))
    regex = ~r/F\d{#{ef_size},}/m

    {acc, io} =
      Enum.reduce(records, {[], []}, fn record, {acc, io} ->
        case Regex.scan(regex, record.text) do
          nil ->
            {[record | acc], io}

          [] ->
            {[record | acc], io}

          codes ->
            {r_acc, io_acc} =
              Enum.reduce(codes, {record, []}, fn
                [], accum ->
                  accum

                [code], {r_acc, io_acc} = accum ->
                  case iterate_ef_code(code, ef_codes) do
                    nil ->
                      accum

                    {ef, value} ->
                      r_acc =
                        Regex.replace(~r/#{ef}#{value}/m, r_acc.text, "#{ef} #{value}")
                        # |> IO.inspect()
                        |> (&Map.put(r_acc, :text, &1)).()

                      io_acc = [{ef, value, r_acc.text} | io_acc]
                      {r_acc, io_acc}
                  end
              end)

            {[r_acc | acc], [io_acc | io]}
        end
      end)

    IO.puts("Separation of F codes from numerics found #{Enum.count(io)} changes\n")

    # Optional print to console for debug / QA
    if opts.separate_ef_codes_from_numerics == true do
      Enum.each(io, fn x ->
        Enum.each(x, fn {ef, value, text} ->
          IO.puts("EF: #{ef};\tValue: #{value};\nText: #{text}\n\n")
        end)
      end)
    end

    acc
  end

  def iterate_ef_code(ef_code, ef_codes) do
    # Build list of tuples where each separate code at different point
    # [{F1234, 5}, {F123, 45}, {F12, 345}, {F1, 2345}]

    max = String.length(ef_code)

    splits =
      Enum.reduce(1..max, [], fn x, acc ->
        [String.split_at(ef_code, x) | acc]
      end)

    # Find member of set of ef_codes
    Enum.reduce_while(splits, nil, fn {ef, _} = split, acc ->
      case Enum.member?(ef_codes, ef) do
        true ->
          {:halt, split}

        false ->
          {:cont, acc}
      end
    end)
  end

  def separate_ef_codes_from_non_numerics(records, opts) do
    regex = ~r/(F\d+)([\."“,£\[\(])/m

    # Optional print to console for debugging / QA
    if opts.separate_ef_codes_from_non_numerics == true do
      Enum.reduce(records, [], fn record, acc ->
        case Regex.scan(~r/(F\d+)([\."“,£\[\(])/m, record.text) do
          [] ->
            acc

          matches ->
            Enum.reduce(matches, acc, fn
              [_, f, <<226>>], accum -> [{f, <<226, 128, 156>>} | accum]
              [_, f, <<194>>], accum -> [{f, <<194, 163>>} | accum]
              [_, f, v], accum -> [{f, v} | accum]
            end)
        end
      end)
      |> List.flatten()
      |> Enum.map(fn {f, v} -> "#{f} #{v}" end)
      |> Enum.join(" | ")
      |> IO.inspect(limit: :infinity, label: "Separated Non-Numerics")
    end

    Enum.reduce(records, [], fn record, acc ->
      Regex.replace(
        regex,
        record.text,
        "\\g{1} \\g{2}"
      )
      |> (&Map.put(record, :text, &1)).()
      |> (&[&1 | acc]).()
    end)
  end

  @amendments_csv "lib/legl/countries/uk/airtable_amendment/amendments.csv"
  @airtable_amendment_table_fields [
                                     "ID",
                                     "Ef Code",
                                     "Articles",
                                     "Text"
                                   ]
                                   |> Enum.join(",")

  @doc """
  Function
  Loads from .csv if no records are provided
  Run in iex
  Legl.Countries.Uk.AirtableAmendment.Amendments.amendments()
  """
  def amendments(%{country: :uk} = opts) do
    with {:ok, records} <-
           Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess.load_source_records(
             "lib/legl/data_files/csv/airtable_act.csv"
           ) do
      amendments_table_workflow(records, opts)
    end
  end

  def amendments(_opts), do: nil

  @doc """
  Function
  Loads from .csv if no records are provided
  """
  def amendments(records, %{country: :uk} = opts) do
    amendments_table_workflow(records, opts)
  end

  def amendments(_records, _opts), do: nil

  defp amendments_table_workflow(records, opts) do
    file = open_file()
    IO.puts("\nStart Processing Amendments\n")

    with {:ok, amendments} <- get_amendments(records),
         {:ok, amendments} <- amendment_relationships(records, amendments) do
      Enum.sort_by(amendments, &Atom.to_string(elem(&1, 0)), {:asc, NaturalOrder})
      |> Enum.each(fn {_k, v} ->
        Map.put(v, :id, opts.name <> "_" <> v.ef)
        |> (&save_to_csv(file, &1)).()
      end)
    else
      :error -> :error
      {:error, reason} -> IO.puts("ERROR #{reason}")
    end

    File.close(file)
  end

  defp open_file() do
    {:ok, csv} = @amendments_csv |> File.open([:utf8, :write])

    IO.puts(
      csv,
      @airtable_amendment_table_fields
    )

    csv
  end

  @doc """
  Function populates a map with the %Amendments{} struct
  """
  def get_amendments(records) do
    Enum.reduce(records, %{}, fn
      %{type: ~s/"amendment,textual"/, amendment: id} = record, acc ->
        Map.put_new(acc, :"F#{id}", %Amendments{ef: "F#{id}", text: record.text})

      _record, acc ->
        acc
    end)
    |> (&{:ok, &1}).()
  end

  @doc """
  Function maps the record ID numbers to the amendments
  """
  def amendment_relationships(records, amendments) do
    Enum.reduce(records, amendments, fn
      %{changes: ""} = _record, acc ->
        acc

      %{changes: changes} = record, acc ->
        record =
          case is_binary(changes) do
            true ->
              changes = String.split(changes, ",")
              %{record | changes: changes}

            _ ->
              record
          end

        update_amendment(record, acc)

      record, acc ->
        update_amendment(record, acc)
    end)
    |> (&{:ok, &1}).()
  end

  @doc """
  Function enumerates all the F codes held against the record in the changes field
  Add stores the corresponding record ID in the amendment struct with the F code as key
  Returns the updated amendments struct
  """
  def update_amendment(record, amendments) do
    # IO.inspect(record.changes)

    record.changes
    |> Enum.reduce(amendments, fn change, acc ->
      key = :"#{change}"

      if key == :F107 do
        IO.inspect(Map.get(acc, key), label: "#{key}")
      end

      case Map.get(acc, key) do
        nil ->
          acc

        amd ->
          value = %{amd | ids: [record.id | amd.ids]}
          Map.put(acc, key, value)
      end
    end)
  end

  def save_to_csv(file, %{id: id, ef: ef, text: text, ids: ids} = _amendment) do
    ids =
      ids
      |> Enum.reverse()
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()

    [id, ef, ids, text]
    |> Enum.join(",")
    |> (&IO.puts(file, &1)).()
  end
end
