defmodule Legl.Countries.Uk.AirtableArticle.UkRegionConversion do
  @doc """

  """
  def region_conversion(records, %{country: "UK"} = _opts) do
    Enum.map(records, &convert_region_code(&1))
    IO.puts("\nRegion Code Conversion Completed\n")
  end

  def region_conversion(records, _opts), do: records

  defp convert_region_code(%{region: ""} = record), do: record

  defp convert_region_code(%{region: "U.K."} = record) do
    region = Legl.Utility.csv_quote_enclosure("UK,England,Wales,Scotland,Northern Ireland")
    %{record | region: region}
  end

  defp convert_region_code(%{region: "E+W+S"} = record) do
    region = Legl.Utility.csv_quote_enclosure("GB,England,Wales,Scotland")
    %{record | region: region}
  end

  defp convert_region_code(%{region: "E"} = record), do: %{record | region: "England"}

  defp convert_region_code(%{region: "S"} = record), do: %{record | region: "Scotland"}

  defp convert_region_code(%{region: "W"} = record), do: %{record | region: "Wales"}

  defp convert_region_code(%{region: "N.I."} = record), do: %{record | region: "Northern Ireland"}

  defp convert_region_code(%{region: region} = record)
       when region in ["E+W", "E+W+N.I.", "S+N.I."] do
    region =
      String.split(region, "+")
      |> Enum.reduce([], fn x, acc ->
        cond do
          x == "E" -> ["England" | acc]
          x == "W" -> ["Wales" | acc]
          x == "N.I." -> ["Northern Ireland" | acc]
          x == "S" -> ["Scotland" | acc]
          true -> IO.inspect(x, label: "convert_region_code/1")
        end
      end)
      |> Enum.reverse()
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()

    %{record | region: region}
  end
end
