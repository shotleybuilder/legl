defmodule Legl.Countries.Uk.LeglRegister.IdField do
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  def id(%LR{} = record) when is_struct(record) do
    IO.write(" NAME")

    {:ok,
     Map.put(
       record,
       :Name,
       id(record."Number", record."Title_EN", record.type_code, record."Year")
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

  def id(title, type, year, number) do
    title
    |> Legl.Airtable.AirtableTitleField.remove_the()
    |> downcase()
    |> split_title()
    |> proper_title()
    |> acronym()
    |> (&Kernel.<>("UK_#{type}_#{year}_#{number}_", &1)).()
  end

  @spec downcase(binary) :: binary
  def downcase(title) do
    String.trim(title)
    |> (&Regex.replace(~r/([A-Za-z])A/, &1, "\\g{1}a")).()
    |> (&Regex.replace(~r/([A-Za-z])BB/, &1, "\\g{1}bb")).()
    |> (&Regex.replace(~r/([A-Za-z])B/, &1, "\\g{1}b")).()
    |> (&Regex.replace(~r/([A-Za-z])CC/, &1, "\\g{1}cc")).()
    |> (&Regex.replace(~r/([A-Za-z])C/, &1, "\\g{1}c")).()
    |> (&Regex.replace(~r/([A-Za-z])D/, &1, "\\g{1}d")).()
    |> (&Regex.replace(~r/([A-Za-z])EE/, &1, "\\g{1}ee")).()
    |> (&Regex.replace(~r/([A-Za-z])E/, &1, "\\g{1}e")).()
    |> (&Regex.replace(~r/([A-Za-z])FF/, &1, "\\g{1}ff")).()
    |> (&Regex.replace(~r/([A-Za-z])F/, &1, "\\g{1}f")).()
    |> (&Regex.replace(~r/([A-Za-z])GG/, &1, "\\g{1}gg")).()
    |> (&Regex.replace(~r/([A-Za-z])G/, &1, "\\g{1}g")).()
    |> (&Regex.replace(~r/([A-Za-z])H/, &1, "\\g{1}h")).()
    |> (&Regex.replace(~r/([A-Za-z])I/, &1, "\\g{1}i")).()
    |> (&Regex.replace(~r/([A-Za-z])J/, &1, "\\g{1}j")).()
    |> (&Regex.replace(~r/([A-Za-z])K/, &1, "\\g{1}k")).()
    |> (&Regex.replace(~r/([A-Za-z])LL/, &1, "\\g{1}ll")).()
    |> (&Regex.replace(~r/([A-Za-z])L/, &1, "\\g{1}l")).()
    |> (&Regex.replace(~r/([A-Za-z])MM/, &1, "\\g{1}mm")).()
    |> (&Regex.replace(~r/([A-Za-z])M/, &1, "\\g{1}m")).()
    |> (&Regex.replace(~r/([A-Za-z])NN/, &1, "\\g{1}nn")).()
    |> (&Regex.replace(~r/([A-Za-z])N/, &1, "\\g{1}n")).()
    |> (&Regex.replace(~r/([A-Za-z])OO/, &1, "\\g{1}oo")).()
    |> (&Regex.replace(~r/([A-Za-z])O/, &1, "\\g{1}o")).()
    |> (&Regex.replace(~r/([A-Za-z])PP/, &1, "\\g{1}pp")).()
    |> (&Regex.replace(~r/([A-Za-z])P/, &1, "\\g{1}p")).()
    |> (&Regex.replace(~r/([A-Za-z])Q/, &1, "\\g{1}q")).()
    |> (&Regex.replace(~r/([A-Za-z])R/, &1, "\\g{1}r")).()
    |> (&Regex.replace(~r/([A-Za-z])SS/, &1, "\\g{1}ss")).()
    |> (&Regex.replace(~r/([A-Za-z])S/, &1, "\\g{1}s")).()
    |> (&Regex.replace(~r/([A-Za-z])TT/, &1, "\\g{1}tt")).()
    |> (&Regex.replace(~r/([A-Za-z])T/, &1, "\\g{1}t")).()
    |> (&Regex.replace(~r/([A-Za-z])U/, &1, "\\g{1}u")).()
    |> (&Regex.replace(~r/([A-Za-z])V/, &1, "\\g{1}v")).()
    |> (&Regex.replace(~r/([A-Za-z])W/, &1, "\\g{1}w")).()
    |> (&Regex.replace(~r/([A-Za-z])X/, &1, "\\g{1}x")).()
    |> (&Regex.replace(~r/([A-Za-z])Y/, &1, "\\g{1}y")).()
    |> (&Regex.replace(~r/([A-Za-z])Z/, &1, "\\g{1}z")).()
  end

  @spec split_title(binary) :: binary
  def split_title(title) do
    String.trim(title)
    |> (&Regex.replace(~r/\(revoked\)/, &1, "")).()
    |> (&Regex.replace(
          ~r/\(|\)|\/|\"|\-|[A-Za-z]+\.?\d+|\d+|:|\.|,|—|\*|&|\[|\]|\+|’|'/,
          &1,
          ""
        )).()
    |> (&Regex.replace(~r/[ ][T|t]o[ ]|[ ][T|t]h[a|e|i|o]t?s?e?[ ]/, &1, " ")).()
    |> (&Regex.replace(
          ~r/[ ][A|a][ ]|[ ][A|a]n[ ]|[ ][A|a]nd[ ]|[ ][A|a]t[ ]|[ ][A|a]re[ ]/,
          &1,
          " "
        )).()
    |> (&Regex.replace(~r/[ ][F|f]?[O|o]r[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][I|i][f|n][ ]|[ ][I|i][s|t]s?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][O|o][f|n][ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][N|n]ot?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][B|b][e|y][ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][W|w]i?t?ho?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][A-Z|a-z][ |\\.|,]/, &1, " ")).()
    |> (&Regex.replace(~r/[H| h]as?v?e?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ –]+/, &1, ", ")).()
    |> (&Regex.replace(~r/^,[ ]/, &1, "")).()
  end

  @spec proper_title(binary) :: binary
  def proper_title(title) do
    String.trim(title)
    |> (&Regex.replace(~r/^[a-z]/, &1, fn x -> String.upcase(x) end)).()
    |> (&Regex.replace(~r/[ ][a-z]/, &1, fn x -> String.upcase(x) end)).()
  end

  @spec acronym(binary) :: binary
  def acronym(title) do
    Regex.replace(~r/[a-z ,\']/, title, "")
  end
end
