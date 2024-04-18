defmodule Legl.Countries.Uk.LeglRegister.Credentials.Creds do
  @moduledoc """
  Module to set credentials for the Legal Register
  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  @doc """
    Sets the credentials for the given LR record.

    The credentials include the year, id, lrt acronym, number, family, type, type class, and tags.

    ## Examples

        iex> record = %LR{}
        iex> Legl.Countries.Uk.LeglRegister.Credentials.set_credentials(record)
        {:ok, %LR{...}}  # Updated record with credentials set

    ## Parameters

      * `record` - The LR record to set the credentials for.

    ## Returns

      A tuple `{:ok, record}` indicating that the credentials were successfully set for the record.
  """

  def set_credentials(%LR{} = record) when is_struct(record) do
    record =
      [
        &Legl.Countries.Uk.LeglRegister.Year.set_year/1,
        &Legl.Countries.Uk.LeglRegister.IdField.id/1,
        &Legl.Countries.Uk.LeglRegister.IdField.lrt_acronym/1,
        &Legl.Countries.Uk.LeglRegister.Credentials.Number.set_number/1,
        &Legl.Countries.Uk.LeglRegister.Credentials.Family.set_family/1,
        &Legl.Countries.Uk.LeglRegister.TypeClass.set_type/1,
        &Legl.Countries.Uk.LeglRegister.TypeClass.set_type_class/1,
        &Legl.Countries.Uk.LeglRegister.Tags.set_tags/1
      ]
      |> creds_builder(record)

    {:ok, record}
  end

  defp creds_builder(creds, record) do
    Enum.reduce(creds, record, fn f, acc ->
      {:ok, record} = f.(acc)
      IO.puts("\nCREDENTIALS: #{record."Name"} #{inspect(f)}")
      record
    end)
  end
end
