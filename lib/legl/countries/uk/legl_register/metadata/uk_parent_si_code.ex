defmodule Legl.Countries.Uk.UkParentSiCode do

  alias Legl.Services.Airtable.Records
  alias Legl.Services.Airtable.AtBasesTables
  @doc """
    Legl.Countries.Uk.UkSiCode.get_parent_at_records_with_multi_si_codes("UK E")
  """
  def get_parent_at_records_with_multi_si_codes(base_name, filesave? \\ false) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
          view: "SI_CODE-PARENTS",
          fields: ["Name", "Title_EN", "SI_Code_(from_Children)"],
          formula: ~s/{SI_Code_Children_(Count)}>1/}
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params),
      uniq_recordset <- Enum.map(recordset, fn x -> uniq_si_codes(x) end)
    ) do
      IO.puts("Records returned from Airtable")
      if filesave? == true do save_to_file(uniq_recordset) end
      make_csv(uniq_recordset, "airtable_parent_si_codes")
    else
      {:error, error} -> {:error, error}
    end
  end

  def uniq_si_codes(
    %{"fields" =>
      %{"SI_Code_(from_Children)" => si_codes}
    } = record) do
    Enum.uniq(si_codes)
    |> Enum.sort()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
    |> (&(Map.put_new(record["fields"], "SI CODE", &1))).()
  end

  def save_to_file(records) when is_list(records) do
    {:ok, file} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.open([:read, :utf8, :write])
    IO.puts(file, inspect(records, limit: :infinity))
    File.close(file)
    :ok
  end

  def make_csv(records, filename) do
    csv_list =
      Enum.join(["Name,", "SI CODE"])
      |> (&[&1 | []]).()

      Enum.reduce(records, csv_list,
        fn
          %{"Name" => name, "SI CODE" => si_code}, acc ->
            [Enum.join([name, si_code], ",") | acc]
          %{"fields" => %{"Name" => name, "SI CODE" => si_code}}, acc ->
          [Enum.join([name, si_code], ",") | acc]
      end)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> save_to_csv("lib/#{filename}.csv")
  end

  def save_to_csv(binary, filename) do
    line_count = binary |> String.graphemes |> Enum.count(& &1 == "\n")
    filename
    |> Path.absname()
    |> File.write(binary)
    {:ok, line_count}
  end
end
