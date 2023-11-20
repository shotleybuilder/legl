defmodule Legl.Countries.Uk.LeglRegister.Amend.FindNewLaw do
  @moduledoc """
  Module to find the difference between these two fields:

  Revoked_by (from UK)
  Revoked_by

  And save the difference as a .json file
  """

  alias Legl.Countries.Uk.Metadata
  alias Legl.Services.Airtable.UkAirtable
  alias Legl.Countries.Uk.LeglRegister.Amend.Options

  @doc """
  Function to get AMENDING laws that are not present in the Legal Register Table
  Laws that are affecting laws that are in the Base
  """
  @spec amending(map()) :: :ok
  def amending(opts \\ []) do
    opts = Options.new_amended_by_law_finder(opts)

    records =
      UkAirtable.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)

    records =
      Enum.reduce(
        records,
        [],
        fn
          %{
            fields: %{
              Amended_by: a_master,
              "Amended_by (from UK) - binary": a_copy,
              Revoked_by: r_master,
              "Revoked_by (from UK) - binary": r_copy
            }
          },
          acc ->
            acc = [{String.split(a_master, ","), String.split(a_copy, ", ")} | acc]
            [{String.split(r_master, ","), String.split(r_copy, ", ")} | acc]

          %{
            fields: %{
              Amended_by: a_master,
              "Amended_by (from UK) - binary": a_copy
            }
          },
          acc ->
            [{String.split(a_master, ","), String.split(a_copy, ", ")} | acc]

          %{
            fields: %{
              Revoked_by: r_master,
              "Revoked_by (from UK) - binary": r_copy
            }
          },
          acc ->
            [{String.split(r_master, ","), String.split(r_copy, ", ")} | acc]

          %{fields: %{Amended_by: a_master}}, acc ->
            [{String.split(a_master, ","), []} | acc]

          %{fields: %{Revoked_by: r_master}}, acc ->
            [{String.split(r_master, ","), []} | acc]

          %{fields: map}, acc when is_map(map) and map_size(map) == 0 ->
            acc

          error, acc ->
            IO.puts("ERROR: No match for #{inspect(error)}\n #{__MODULE__}.amending")
            acc
        end
      )
      |> Enum.map(fn {master, copy} -> Legl.Utility.delta_lists(copy, master) end)
      |> Enum.map(
        &Enum.map(
          &1,
          fn name ->
            case Legl.Utility.split_name(name) do
              {type, year, number} ->
                Map.merge(%{}, %{type_code: type, Number: number, Year: year})

              {type, number} ->
                Map.merge(%{}, %{type_code: type, Number: number})
            end
          end
        )
      )
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort_by(& &1."Year", :desc)
      |> Enum.map(&Metadata.get_latest_metadata(&1))

    records =
      records
      |> Enum.reduce(
        [],
        fn
          {:ok, record}, acc -> [record | acc]
          _, acc -> acc
        end
      )
      |> Enum.reverse()

    Legl.Utility.save_json(
      records,
      ~s[lib/legl/countries/uk/legl_register/new/api_new_laws.json]
    )

    IO.puts("\n#{Enum.count(records)} records saved to .json")
  end

  @doc """
  Function to get AMENDED laws that are not present in the Legal Register Table

  The Affecting laws are in the Base, but not all the laws affected are nor should be
  Calc of the DIFF between Affecting set and Revoking set fields
  """
  @spec amended(map()) :: :ok
  def amended(opts \\ []) do
    opts = Options.new_amending_law_finder(opts)

    records =
      UkAirtable.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)

    records =
      Enum.reduce(
        records,
        [],
        fn
          %{
            fields: %{
              Amending: a_master,
              "Amending (from UK) - binary": a_copy,
              Revoking: r_master,
              "Revoking (from UK) - binary": r_copy
            }
          },
          acc ->
            acc = [{String.split(a_master, ","), String.split(a_copy, ", ")} | acc]
            [{String.split(r_master, ","), String.split(r_copy, ", ")} | acc]

          %{
            fields: %{
              Amending: a_master,
              "Amending (from UK) - binary": a_copy
            }
          },
          acc ->
            [{String.split(a_master, ","), String.split(a_copy, ", ")} | acc]

          %{
            fields: %{
              Revoking: r_master,
              "Revoking (from UK) - binary": r_copy
            }
          },
          acc ->
            [{String.split(r_master, ","), String.split(r_copy, ", ")} | acc]

          %{fields: %{Amending: a_master}}, acc ->
            [{String.split(a_master, ","), []} | acc]

          %{fields: %{Revoking: r_master}}, acc ->
            [{String.split(r_master, ","), []} | acc]

          %{fields: map}, acc when is_map(map) and map_size(map) == 0 ->
            acc

          error, acc ->
            IO.puts("ERROR: No match for #{inspect(error)}\n #{__MODULE__}.amending")
            acc
        end
      )
      |> Enum.map(fn {master, copy} -> Legl.Utility.delta_lists(copy, master) end)
      # |> IO.inspect()
      |> Enum.map(
        &Enum.map(
          &1,
          fn name ->
            case Legl.Utility.split_name(name) do
              {type, year, number} ->
                Map.merge(%{}, %{type_code: type, Number: number, Year: year})

              {type, number} ->
                Map.merge(%{}, %{type_code: type, Number: number, Year: nil})
            end
          end
        )
      )
      |> List.flatten()
      |> Enum.filter(&(&1.type_code not in ["eudn", "eur", "nisr"]))
      |> Enum.uniq()
      |> Enum.sort_by(& &1."Year", :desc)
      |> Enum.map(&Metadata.get_latest_metadata(&1))

    records =
      records
      |> Enum.reduce(
        [],
        fn
          {:ok, record}, acc -> [record | acc]
          _, acc -> acc
        end
      )
      |> Enum.reverse()

    Legl.Utility.save_json(
      records,
      ~s[lib/legl/countries/uk/legl_register/new/api_new_laws.json]
    )

    IO.puts(" #{Enum.count(records)} records saved to .json")
  end
end
