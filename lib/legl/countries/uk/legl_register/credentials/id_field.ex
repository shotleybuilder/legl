defmodule Legl.Countries.Uk.LeglRegister.IdField do
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  def id(%LR{} = record) when is_struct(record) do
    IO.write(" NAME")

    {:ok,
     Map.put(
       record,
       :Name,
       id(record."Title_EN", record.type_code, record."Year", record."Number")
     )}
  end

  def id(%{Number: number, Title_EN: title, type_code: type_code, Year: year})
      when is_binary(number) and is_binary(title) and is_binary(type_code) and is_binary(year) do
    id(title, type_code, year, number)
  end

  def id(%{Number: number, Title_EN: title, type_code: type_code, Year: year})
      when is_binary(number) and is_binary(title) and is_binary(type_code) and is_integer(year) do
    id(title, type_code, Integer.to_string(year), number)
  end

  def id(_title, type, year, number) do
    id(type, year, number)
  end

  def id(type, year, number) do
    ~s/UK_#{type}_#{year}_#{number}/
  end

  def lrt_acronym(%LR{} = record) when is_struct(record) do
    IO.write(" ACRONYM")

    {:ok,
     Map.put(
       record,
       :Acronym,
       lrt_acronym(record."Title_EN")
     )}
  end

  @spec lrt_acronym(binary()) :: binary()
  def lrt_acronym(title) when is_binary(title) do
    title
    |> Legl.Airtable.AirtableTitleField.remove_the()
    |> (&Regex.replace(~r/ /, &1, " ")).()
    |> (&Regex.scan(~r/[[:upper:]]/, &1)).()
    |> List.flatten()
    |> Enum.join()
  end
end
