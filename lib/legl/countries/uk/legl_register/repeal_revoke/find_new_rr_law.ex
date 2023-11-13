defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.FindNewRrLaw do
  @moduledoc """
  Module to find the difference between these two fields:

  Revoked_by (from UK)
  Revoked_by

  And save the difference as a .json file
  """

  alias Legl.Services.Airtable.UkAirtable
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.Options

  def run(opts) do
    opts = Options.new_law_finder(opts)

    records =
      UkAirtable.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)

    records =
      Enum.map(
        records,
        fn
          %{fields: %{Revoked_by: master, "Revoked_by (from UK) - binary": copy}} ->
            IO.inspect(copy)
            {String.split(master, ","), String.split(copy, ", ")}

          %{fields: %{Revoked_by: master}} ->
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
      ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_new_laws.json]
    )

    IO.puts("#{Enum.count(records)} records saved to .json")
  end
end
