defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.Delta do
  @moduledoc """
  Module compares the current and latest "Live?_description" field contents

  Generates a Live?_change_log field to capture the changes
  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  @field_paddings %{:Live? => 15, :"Live?_description" => 5, :Revoked_by => 10}
  # Live?_description is not a good field to compare ...
  @compare_fields ~w[Live? Revoked_by]a

  alias Legl.Countries.Uk.LeglRegister.LegalRegister

  @spec compare(%LegalRegister{}, %LegalRegister{}) :: %LegalRegister{}
  def compare(record, latest_record) do
    change_log =
      compare(record, latest_record, @compare_fields)
      |> change_log()
      |> concatenate_change_log(record."Live?_change_log")
      |> String.trim_leading("📌")

    date = ~s/#{Date.utc_today()}/

    Kernel.struct(record,
      "Live?_change_log": change_log,
      "Live?_checked": date
    )
  end

  defp concatenate_change_log(new, existing) do
    ~s/#{new}📌#{existing}/
  end

  @spec compare(%LegalRegister{}, %LegalRegister{}, list()) :: list() | []
  defp compare(current_record, latest_record, fields) do
    # IO.inspect(current_record, label: "CURRENT RECORD: ")
    # IO.inspect(latest_record, label: "LATEST RECORD: ")

    Enum.reduce(fields, [], fn field, acc ->
      current = Map.get(current_record, field)
      latest = Map.get(latest_record, field)

      cond do
        # find the Delta between the lists
        field == :Revoked_by ->
          case Legl.Utility.delta_lists(current, latest) do
            [] ->
              acc

            values ->
              value =
                values
                |> Enum.sort()
                |> Enum.join("📌")

              IO.puts(
                "NAME: #{current_record."Title_EN"} #{current_record."Year"}\nDIFF: #{inspect(value, limit: :infinity)}"
              )

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
        ~s/New value/
    end
  end

  defp changed?(_, latest) when latest in [nil, "", []], do: false

  defp changed?(current, latest) when is_list(current) and is_list(latest) do
    case current != latest do
      false ->
        false

      true ->
        ~s/#{Enum.join(current, ", ")} -> #{Enum.join(latest, ", ")}/
    end
  end

  defp changed?(current, current), do: false

  defp changed?(current, latest), do: "#{current} -> #{latest}"

  defp change_log([]), do: ""

  defp change_log(changes) do
    # IO.inspect(changes)
    # Returns the metadata changes as a formated multi-line string
    date = Date.utc_today()
    date = ~s(#{date.day}/#{date.month}/#{date.year})

    Enum.reduce(changes, ~s/📌#{date}📌/, fn {k, v}, acc ->
      # width = 80 - string_width(k)
      width = Map.get(@field_paddings, k)
      k = ~s/#{k}#{Enum.map(1..width, fn _ -> "." end) |> Enum.join()}/
      # k = String.pad_trailing(~s/#{k}/, width, ".")
      ~s/#{acc}#{k}#{v}📌/
    end)
    |> String.trim_trailing("📌")
  end
end
