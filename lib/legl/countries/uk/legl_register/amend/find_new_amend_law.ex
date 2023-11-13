defmodule Legl.Countries.Uk.LeglRegister.Amend.FindNewAmendingLaw do
  @moduledoc """
  Module to find the difference between these two fields:

  Revoked_by (from UK)
  Revoked_by

  And save the difference as a .json file
  """

  alias Legl.Services.Airtable.UkAirtable
  alias Legl.Countries.Uk.LeglRegister.Amend.Options

  @doc """
  Function to get AMENDING laws that are not present in the Legal Register Table
  Laws that are amending laws that are in the Base
  """
  @spec amending(map()) :: :ok
  def amending(opts) do
    opts = Options.new_amending_law_finder(opts)

    records =
      UkAirtable.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)

    records =
      Enum.map(
        records,
        fn
          %{fields: %{Amended_by: master, "Amended_by (from UK) - binary": copy}} ->
            IO.inspect(copy)
            {String.split(master, ","), String.split(copy, ", ")}

          %{fields: %{Amended_by: master}} ->
            {String.split(master, ","), []}
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

    Legl.Utility.save_json(
      records,
      ~s[lib/legl/countries/uk/legl_register/amend/api_new_laws.json]
    )

    IO.puts("#{Enum.count(records)} records saved to .json")
  end

  @doc """
  Function to get AMENDED laws that are not present in the Legal Register Table
  The Affecting laws are in the Base, but not all the laws affected are
  """
  @spec amended(map()) :: :ok
  def amended(opts \\ []) do
    opts = Options.new_amended_law_finder(opts)

    records =
      UkAirtable.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)

    records =
      Enum.map(
        records,
        fn
          %{fields: %{Amending: master, "Amending (from UK) - binary": copy}} ->
            IO.inspect(copy)
            {String.split(master, ","), String.split(copy, ", ")}

          %{fields: %{Amending: master}} ->
            {String.split(master, ","), []}

          %{fields: _} ->
            {[], []}
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
                Map.merge(%{}, %{type_code: type, Number: number, Year: nil})
            end
          end
        )
      )
      |> List.flatten()
      |> Enum.filter(&(&1.type_code not in ["eudn", "eur", "nisr"]))
      |> Enum.uniq()
      |> Enum.sort_by(& &1."Year", :desc)

    Legl.Utility.save_json(
      records,
      ~s[lib/legl/countries/uk/legl_register/amend/api_new_laws.json]
    )

    IO.puts("#{Enum.count(records)} records saved to .json")
  end
end
