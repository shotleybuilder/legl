defmodule Legl.Countries.Uk.AirtableArticle.UkArticlePrint do
  @moduledoc """
  Creates a tab delimited text file where every column is the width of the
  longest item in that column
  """
  def make_tabular_txtfile(records, opts) do
    field_lengths(records, opts)
    # |> IO.inspect(label: "field lengths")
    |> txt(records, opts)
    # |> Enum.reverse()
    |> Enum.join("\n")
    |> (&File.write("lib/legl/data_files/txt/at_tabulated.txt", &1)).()
  end

  defp field_lengths(records, opts) do
    # Enumerate the records and find the length of the longest record for each
    # field

    # |> IO.inspect(label: "options")
    fields = opts.fields

    # create the collectable for the maximum string length of each field in the records
    max_field_lengths =
      case opts.type do
        :act ->
          Enum.into(fields, %{}, fn k -> {k, 0} end)

        :regulation ->
          Enum.into(fields, %{}, fn k -> {k, 0} end)
      end

    # |> IO.inspect(label: "max field lengths")

    Enum.reduce(records, max_field_lengths, fn record, acc ->
      Enum.reduce(fields, acc, fn field, lengths ->
        case Map.get(record, field) do
          nil ->
            lengths

          value when is_list(value) ->
            lengths

          value when is_integer(value) ->
            lengths

          value when is_boolean(value) ->
            lengths

          value ->
            case field do
              :text ->
                lengths

              _ ->
                current_length = Map.get(lengths, field)

                if String.length(value) > current_length,
                  do: Map.put(lengths, :"#{field}", String.length(value)),
                  else: lengths
            end
        end
      end)
    end)
  end

  defp txt(max_field_lengths, records, opts) do
    fields = opts.fields

    Enum.reduce(records, [], fn record, acc ->
      Enum.reduce(fields, [], fn field, acc ->
        case Map.get(record, field) do
          nil ->
            acc

          value when is_binary(value) ->
            case field do
              :text ->
                {value, _} = String.split_at(value, 100)

                String.pad_trailing(value, 100)
                |> (&[&1 | acc]).()

              _ ->
                String.pad_trailing(value, Map.get(max_field_lengths, field))
                |> (&[&1 | acc]).()
            end

          value when is_list(value) ->
            case field do
              :changes ->
                Enum.join(value, ",")
                |> (&[&1 | acc]).()
            end

          _value ->
            acc
        end
      end)
      |> Enum.reverse()
      |> Enum.join("\t")
      |> (&[&1 | acc]).()
    end)
  end

  @doc """
  Reads the contents of 'at_tabulated.txt' and saves the ID (key, name) field in 'legl/at_ids.txt'
  """
  def id_field() do
    binary = File.read!("lib/at_tabulated.txt")
    records = String.split(binary, "\n")

    Enum.reduce(records, [], fn record, acc ->
      String.split(record, "\t") |> List.first() |> String.trim_trailing() |> (&[&1 | acc]).()
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> (&File.write("lib/at_ids.txt", &1)).()
  end
end
