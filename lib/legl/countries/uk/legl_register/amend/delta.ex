defmodule Legl.Countries.Uk.LeglRegister.Amend.Delta do
  @moduledoc """
  Module compares the content of the following fields against the latest data @leg.gov.uk
  stats_amendments_count
  stats_amending_laws_count
  stats_amendments_count_per_law

  Generates a amended_by_change_log field to capture the differences
  """

  # TODO stats_amendments_count_per_law needs to find the changes within the list
  @compare_amending_fields ~w[
    Amending
    🔺_stats_affects_count
    🔺_stats_self_affects_count
    🔺_stats_affected_laws_count
    ]a
  @compare_amended_by_fields ~w[
    Amended_by
    🔻_stats_affected_by_count
    🔻_stats_self_affected_by_count
    🔻_stats_affected_by_laws_count
    ]a
  @compare_revoked_by_fields ~w[
    Revoked_by
    🔻_stats_revoked_by_laws_count
  ]a

  # @field_paddings (@compare_amending_fields ++
  #                   @compare_amended_by_fields ++
  #                   @compare_revoked_by_fields ++
  #                   [:amending_change_log, :amended_by_change_log, :" Live?_change_log"])
  #                |> Enum.zip([10, 10, 10, 8, 6, 10, 10, 10, 8, 6, 10, 10, 10])
  #                |> Enum.into(%{})
  @doc """
  Receives original and latest list of legal register record structs
  """
  @spec compare({list(), list()}) :: list()
  def compare(records) do
    records
    # |> IO.inspect(label: "data for compare")
    |> Enum.reduce(
      [],
      fn {latest_record, record}, acc ->
        latest_amending_change_log =
          compare_fields(record, latest_record, @compare_amending_fields)
          |> change_log()
          |> concatenate_change_log(record.amending_change_log)
          |> String.trim_leading("\n")

        latest_amended_by_change_log =
          compare_fields(record, latest_record, @compare_amended_by_fields)
          |> change_log()
          |> concatenate_change_log(record.amended_by_change_log)
          |> String.trim_leading("\n")

        latest_revoked_by_change_log =
          compare_fields(record, latest_record, @compare_revoked_by_fields)
          |> change_log()
          |> concatenate_change_log(record."Live?_change_log")
          |> String.trim_leading("\n")

        date = ~s/#{Date.utc_today()}/

        Kernel.struct(latest_record,
          amending_change_log: latest_amending_change_log,
          amended_by_change_log: latest_amended_by_change_log,
          "Live?_change_log": latest_revoked_by_change_log,
          amendments_checked: date
        )
        |> (&[&1 | acc]).()
      end
    )

    # |> IO.inspect()
  end

  def concatenate_change_log(new, existing) do
    ~s/#{new}\n#{existing}/
  end

  @spec compare_fields(list(), list(), list()) :: list()
  def compare_fields(record, latest_record, fields) do
    Enum.reduce(fields, [], fn field, acc ->
      current = Map.get(record, field)
      latest = Map.get(latest_record, field)

      cond do
        # find the Delta between the lists
        field in [:Amended, :Amended_by, :Revoked_by] ->
          current =
            case current do
              value when value in ["", nil] ->
                []

              value when is_binary(value) ->
                value |> String.split(",")
            end

          case Legl.Utility.delta_lists(current, latest) do
            [] ->
              acc

            values ->
              IO.puts(
                "NAME: #{record."Title_EN"} #{record."Year"}\nDIFF: #{inspect(values, limit: :infinity)}"
              )

              value =
                values
                # |> Enum.sort()
                |> Enum.join("\n")

              Keyword.put(acc, field, value)
          end

        true ->
          case changed?(current, latest) do
            false ->
              acc

            value ->
              Keyword.put(acc, field, value)
          end
      end
    end)
  end

  defp changed?(current, latest) when current in [nil, "", []] and latest not in [nil, "", []] do
    case current != latest do
      false ->
        false

      true ->
        ~s/nil -> #{latest}/
    end
  end

  defp changed?(_, latest) when latest in [nil, "", []], do: false

  defp changed?(current, latest) when is_list(current) and is_list(latest) do
    case current != latest do
      false ->
        false

      true ->
        ~s/#{Enum.join(current, ", ")}\n->\n#{Enum.join(latest, ", ")}/
    end
  end

  defp changed?(current, current), do: false

  defp changed?(current, latest), do: "#{current} -> #{latest}"

  @spec change_log([]) :: binary()
  defp change_log([]), do: ""

  @spec change_log(list()) :: String.t()
  defp change_log(changes) do
    # IO.inspect(changes)
    # Returns the metadata changes as a formated multi-line string
    date = Date.utc_today()
    date = ~s(#{date.day}/#{date.month}/#{date.year})

    Enum.reduce(changes, ~s/\n#{date}\n/, fn {k, v}, acc ->
      # width = 80 - string_width(k)
      # width = Map.get(@field_paddings, k)
      k = ~s/#{k}\n/
      # k = String.pad_trailing(~s/#{k}/, width, ".")
      ~s/#{acc}#{k}#{v}\n/
    end)
    |> String.trim_trailing("\n")
  end
end
