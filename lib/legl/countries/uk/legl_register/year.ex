defmodule Legl.Countries.Uk.LeglRegister.Year do
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  @spec set_year(LR.legal_register()) :: {:ok, LR.legal_register()}
  def set_year(%LR{Year: year} = record) when is_struct(record) do
    IO.write("YEAR")

    {:ok,
     cond do
       is_integer(year) ->
         record

       is_binary(year) ->
         Map.put(record, :Year, String.to_integer(year))
     end}
  end

  def set_year(%LR{}),
    do: {:error, "ERROR: Year not found in struct"}

  def set_year(_),
    do: {:error, "ERROR: Not a Legal Register struct"}
end
