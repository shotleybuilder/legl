defmodule Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess do
  @moduledoc """

  """
  alias Legl.Countries.Uk.AirtableArticle.UkRegionConversion
  alias Legl.Countries.Uk.AirtableAmendment.Amendments
  alias Legl.Countries.Uk.AirtableArticle.UkArticlePrint

  @field_keys ~s[
    id name flow type part chapter heading section sub_section para dupe amendment text region changes
  ]
              |> String.trim()
              |> String.split()
              |> Enum.map(fn k -> String.to_atom(k) end)

  @doc """
  Function allows process to be run w/o triggering full reparsing of the annotated.txt file
  iex: Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess.process_from_file()
  """
  def process_from_file(opts \\ %{type: :act}) do
    with {:ok, records} <- load_source_records("lib/legl/data_files/csv/airtable_act.csv") do
      # UK.Act.fields()
      fields = @field_keys

      opts = Keyword.merge(Map.to_list(opts), fields: fields, country: :uk)
      process(records, opts)
    end
  end

  def process(records, opts) do
    opts = Enum.into(opts ++ change_stats(records), %{})

    with records <- UkRegionConversion.region_conversion(records, opts),
         records <- Amendments.separate_ef_codes_from_numerics(records, opts),
         records <- Amendments.separate_ef_codes_from_non_numerics(records, opts),
         {:ok, records} <- Amendments.find_changes(records, opts),
         Amendments.amendments(records, opts),
         records <- rm_amendments(records) do
      # A proxy of the Airtable table useful for debugging 'at_tabulated.txt'
      UkArticlePrint.make_tabular_txtfile(records, opts)
      |> IO.puts()

      Enum.reverse(records)
      |> to_csv(opts)
    end
  end

  def rm_amendments(records) do
    Enum.reduce(records, [], fn
      %{type: ~s/"amendment,heading"/} = _record, acc -> acc
      %{type: ~s/"amendment,textual"/} = _record, acc -> acc
      record, acc -> [record | acc]
    end)
  end

  def to_csv(records, opts) do
    opts = Map.put(opts, :type, :act_)
    Legl.Legl.LeglPrint.to_csv(records, opts)
  end

  def change_stats(records) do
    r = List.last(records)

    change_stats =
      case Map.has_key?(r, :max_amendments) do
        true ->
          [
            amendments: {r.max_amendments, "F"},
            modifications: {r.max_modifications, "C"},
            commencements: {r.max_commencements, "I"},
            extents: {r.max_extents, "E"}
          ]

        false ->
          build_change_stats(records)
      end

    # Print change stats to the console
    Enum.each(change_stats, fn {k, {total, code}} -> IO.puts("#{k} #{total} code: #{code}") end)
    change_stats
  end

  def build_change_stats(records) when is_list(records) do
    {f, c, i, e} =
      Enum.reduce(records, {0, 0, 0, 0}, fn
        %{amendment: ""} = _record, acc ->
          acc

        %{amendment: a, type: type} = _record, acc ->
          String.split(a, ",")
          |> Enum.reduce(acc, fn
            "", accu ->
              accu

            nil, accu ->
              accu

            v, {f, c, i, e} = accu ->
              # IO.puts("#{v}, #{type}")
              v = String.to_integer(v)

              cond do
                type == ~s/amendment,textual/ ->
                  if v > f, do: {v, c, i, e}, else: accu

                type == ~s/commencement,content/ ->
                  if v > c, do: {f, v, i, e}, else: accu

                type == ~s/modification,content/ ->
                  if v > i, do: {f, c, v, e}, else: accu

                type == ~s/editorial,content/ ->
                  if v > e, do: {f, c, i, v}, else: accu
              end

            _, accu ->
              accu
          end)
      end)

    [
      amendments: {f, "F"},
      modifications: {c, "C"},
      commencements: {i, "I"},
      extents: {e, "E"}
    ]
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
end
