defmodule Legl.Countries.Uk.AirtableAmendment.Amendments do
  defstruct [:ef, :text, ids: []]

  alias __MODULE__

  def find_changes(records) do
    # 'Changes' field holds list of changes (amendments, mods) applying to that record
    r = List.last(records)

    change_stats = [
      amendments: {r.max_amendments, "F"},
      modifications: {r.max_modifications, "C"},
      commencements: {r.max_commencements, "I"},
      extents: {r.max_extents, "E"}
    ]

    # Print change stats to the console
    Enum.each(change_stats, fn {k, {total, code}} -> IO.puts("#{k} #{total} code: #{code}") end)

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

  def find_change_in_record(_code, _rng, record), do: record

  def find_change_in_record({code, rng, record}) do
    Enum.reduce(1..rng, record, fn n, acc ->
      case String.contains?(record.text, ~s/#{code}#{n} /) do
        true ->
          changes = [~s/#{code}#{n}/ | acc.changes]
          %{acc | changes: changes}

        false ->
          acc
      end
    end)
  end

  @amendments_csv "lib/legl/countries/uk/airtable_amendment/amendments.csv"
  @airtable_amendment_table_fields [
                                     "Ef Code",
                                     "Articles",
                                     "Text"
                                   ]
                                   |> Enum.join(",")

  @field_keys ~s[
    id name flow record_type part chapter heading section sub_section para dupe amendment text region changes
  ]
              |> String.trim()
              |> String.split()
              |> Enum.map(fn k -> String.to_atom(k) end)

  @doc """
  Function
  Run in iex
  Legl.Countries.Uk.AirtableAmendment.Amendments.amendments_table_workflow()
  """
  def amendments_table_workflow() do
    file = open_file()

    with {:ok, records} <- load_source_records("lib/airtable_act.csv"),
         {:ok, amendments} <- amendments(records),
         {:ok, amendments} <- amendment_relationships(records, amendments) do
      Enum.sort_by(amendments, &Atom.to_string(elem(&1, 0)), {:asc, NaturalOrder})
      |> Enum.each(fn amendment ->
        save_to_csv(file, amendment)
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
  Function to load the records into memory from the
  'airtable_act.csv' or 'airtable_regulation.csv' files
  """
  def load_source_records(path) do
    Path.absname(path)
    |> File.stream!()
    |> CSV.decode(headers: false)
    |> Enum.reduce(
      [],
      fn
        {:ok, record}, acc ->
          record
          |> (&Enum.zip(@field_keys, &1)).()
          |> Enum.into(%{})
          |> (&[&1 | acc]).()

        {:error, error}, acc ->
          IO.puts("ERROR #{error}")
          acc
      end
    )
    |> Enum.reverse()
    # Rem header row
    |> List.delete_at(0)
    |> (&{:ok, &1}).()
  end

  @doc """
  Function populates a map with the %Amendments{} struct
  """
  def amendments(records) do
    Enum.reduce(records, %{}, fn
      %{amendment: ""} = _record, acc ->
        acc

      %{record_type: ~s/amendment,textual/, amendment: id} = record, acc ->
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

    String.split(record.changes, ",")
    |> Enum.reduce(amendments, fn change, acc ->
      key = :"#{change}"

      if key == :F59 do
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

  def save_to_csv(file, {_, %{ef: ef, text: text, ids: ids}} = _amendment) do
    ids =
      ids
      |> Enum.reverse()
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()

    [ef, ids, text]
    |> Enum.join(",")
    |> (&IO.puts(file, &1)).()
  end
end
