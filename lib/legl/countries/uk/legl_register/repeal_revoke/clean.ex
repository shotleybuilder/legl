defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.Clean do
  @moduledoc """
  Module to clean the records before POST / PATCH to Airtable
  Calling from the workflow means we can process and store to .json for QA
  """
  def clean_records(record) when is_map(record) do
    clean_records([record]) |> List.first()
  end

  def clean_records(records) when is_list(records) do
    Enum.map(records, fn %{fields: fields} = record ->
      Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
      |> clean()
      |> (&Map.put(record, :fields, &1)).()
    end)
  end

  defp clean(%{Revoked_by: []} = fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :Revoked_by,
      :path,
      :amending_title
    ])
  end

  defp clean(%{Revoked_by: _revoked_by} = fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :path,
      :amending_title
    ])

    # |> Map.put(:Revoked_by, Enum.join(revoked_by, ", "))
  end

  defp clean(fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :Revoked_by,
      :path,
      :amending_title
    ])
  end

  def clean_records_for_post(records, opts) do
    Enum.map(records, fn %{fields: fields} = _record ->
      Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
      |> Map.drop([:Name])
      |> (&Map.put(%{}, :fields, &1)).()
    end)
    |> add_family(opts)
  end

  defp add_family(records, opts) do
    # Add Family to records
    # Manually filter those laws to add or not to the BASE

    Enum.reduce(records, [], fn record, acc ->
      case ExPrompt.confirm(
             "Save this law to the Base? #{record.fields[Title_EN]}\n#{inspect(record)}"
           ) do
        false ->
          acc

        true ->
          case opts.family do
            "" ->
              [record | acc]

            _ ->
              case ExPrompt.confirm("Assign this Family? #{opts.family}") do
                false ->
                  [record | acc]

                true ->
                  Map.put(record.fields, :Family, opts.family)
                  |> (&Map.put(record, :fields, &1)).()
                  |> (&[&1 | acc]).()
              end
          end
      end
    end)
  end
end
