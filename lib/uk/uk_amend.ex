defmodule UK.Amend do
  @moduledoc """
  A script to list unique legislation IDs.
  Source is amending.txt and which is scrapped from the changes to legislation table in legislation.gov.uk
  Output is amends.txt
  """


  @spec parse_amend :: :ok
  def parse_amend do

    binary =
      Legl.txt("amending")
      |> Path.absname()
      |> File.read!()

    Legl.txt("amends")
    |> Path.absname()
    |> File.write("#{UK.Amend.parse(binary)}")

    String.split(binary, "\n")
    |> Enum.reduce([],
      fn x, acc ->
        [amending_title, year, number] = line_item(x)
        id(amending_title, "UK_#{year}_#{number}_")
        |> (&[&1 | acc]).()
      end )
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join(", ")
    |> IO.inspect()
    |> Legl.copy()
    :ok
  end

  @spec parse(binary) :: binary
  def parse(binary) do
    String.split(binary, "\n")
    |> Enum.reduce([],
      fn x, acc ->
        line_item(x)
        |> file_text()
        |> (&[&1 | acc]).()
      end )
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join("\n")
  end

  def line_item(str) do
    [_amended_title, _year, _changed_provision, _type, amending_title, yr_num, _affecting_provision, _web, _note] = String.split(str, "\t")
    <<year::binary-size(4), rest::binary>> = yr_num
    number =
      case rest do
        " No. " <> number -> number
        " c. " <> number -> number
        " asp " <> number -> number
        " anaw " <> number -> number
        " asc " <> number -> number
      end
    [amending_title, year, number]
  end

  def file_text([amending_title, year, number]) do
    "#{id(amending_title, "UK_#{year}_#{number}_")}, #{amending_title}"
  end

  def id("The " <> amending_title = _amending_title, str) do
    id(amending_title, str)
  end

  def id(amending_title, str) do
    amending_title
    |> downcase()
    |> split_title()
    |> proper_title()
    |> acronym()
    |> (&Kernel.<>(str,&1)).()
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
    |> (&Regex.replace(~r/\(|\)|\/|\"|\-|[A-Za-z]+\.?\d+|\d+|:|\.|,|—|\*|&|\[|\]|\+/, &1, "")).()
    |> (&Regex.replace(~r/[ ][T|t]o[ ]|[ ][T|t]h[a|e|i|o]t?s?e?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][A|a][ ]|[ ][A|a]n[ ]|[ ][A|a]nd[ ]|[ ][A|a]t[ ]|[ ][A|a]re[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][F|f]?[O|o]r[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][I|i][f|n][ ]|[ ][I|i][s|t]s?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][O|o][f|n][ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][N|n]ot?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][B|b][e|y][ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][W|w]i?t?ho?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ][A-Z|a-z][ |\\.|,]/, &1, " ")).()
    |> (&Regex.replace(~r/[H| h]as?v?e?[ ]/, &1, " ")).()
    |> (&Regex.replace(~r/[ ]+/, &1, ", ")).()
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
