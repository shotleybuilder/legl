defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.Patch do
  @api_patch_results_path ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_patch_results.json]
  def patch([], _), do: :ok

  def patch(records, %{patch?: false}),
    do:
      records
      |> Enum.map(&clean(&1))
      |> Legl.Utility.save_json_returning(@api_patch_results_path)

  def patch(record, opts) when is_map(record) do
    IO.write("PATCH single record - ")
    Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.patch([record], opts)
  end

  def patch(records, opts) do
    IO.write("PATCH bulk - ")

    records
    |> Enum.map(&clean(&1))
    |> Legl.Utility.save_json_returning(@api_patch_results_path)
    |> elem(1)
    |> Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.patch(opts)
  end

  def clean(%{record_id: _} = record) when is_map(record) do
    record =
      record
      |> Map.drop([
        :Name,
        :Title_EN,
        :Year,
        :Number,
        :type_code,
        :record_id
      ])
      |> (&Map.merge(%{id: record.record_id}, %{fields: &1})).()

    IO.write("Records cleaned - ")
    record
  end

  def clean(record), do: record
end
