defmodule Legl.Countries.Uk.LeglRegister.Credentials.Number do
  @moduledoc """
  Module for functions that control the `Number` field in a Legal Register
  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  def set_number(%LR{} = record) when is_struct(record) do
    IO.write(" NUMBER")

    record =
      case String.contains?(record."Number", "/") do
        true ->
          number = Regex.run(~r/\d+$/, record."Number")

          record
          |> Map.put(:old_record_number, record."Number")
          |> Map.put(:Number, number)

        false ->
          record
      end

    {:ok, record}
  end
end
