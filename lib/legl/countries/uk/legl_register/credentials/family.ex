defmodule Legl.Countries.Uk.LeglRegister.Credentials.Family do
  @moduledoc """
  Module for functions that control the `Family` field in a Legal Register
  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR
  alias Legl.Countries.Uk.LeglRegister.Models

  # Sets the family and family_ii fields of a given LR record.
  #
  # ## Examples
  #
  #     iex> record = %LR{Family: "Smith", family_ii: "Johnson"}
  #     iex> set_family(record)
  #     %LR{Family: "Smith", family_ii: "Johnson"}
  #
  # ## Parameters
  #
  #   - `record`: An LR record containing the `Family` and `family_ii` fields.
  #
  # ## Returns
  #
  #   The updated LR record with the `Family` and `family_ii` fields set.
  def set_family(record, %{update_workflow: _}), do: {:ok, record}

  def set_family(%LR{Family: family, family_ii: family_ii} = record, _) do
    record =
      case ExPrompt.confirm(~s/\nFamily has been auto-set to #{family}.  Change?/) do
        true ->
          Map.put(record, :Family, family_chooser())

        false ->
          record
      end

    record =
      case ExPrompt.confirm(~s/Family ii has been auto-set to #{family_ii}.  Change?/) do
        true ->
          Map.put(record, :Family_ii, family_chooser())

        false ->
          record
      end

    {:ok, record}
  end

  defp family_chooser() do
    case ExPrompt.choose("Choose Family", Models.ehs_family()) do
      index when index in 0..20 -> Enum.at(Models.ehs_family(), index)
      -1 -> ""
      _ -> ""
    end
  end
end
