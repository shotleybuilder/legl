defmodule Legl.Services.Airtable.AtTables do



  @doc """
  Returns a map of the Airtable Base Table Names and IDs for a given Base ID.
  """
  def get_table_id(base_id, table_name) do
    case String.starts_with?(base_id, "app") and String.length(base_id) == 17 do
      false ->
        {:error, "not a valid base id"}
      _ ->
        case Map.get(table_ids(), base_id) do
          nil ->
            {:error, "base id not found"}
          tables ->
            case Map.get(tables, format_table_name(table_name)) do
              nil ->
                {:error, "table name #{table_name} not found for #{base_id}"}
              table_id ->
                {:ok, table_id}
            end
        end
    end
  end

  defp format_table_name(str) do
    str
    |> String.downcase()
    |> String.replace(" ","_")
  end

  defp table_ids do
    %{
      #uk e
      "appq5OQW9bTHC1zO5" => %{
        "uk" => "tblJW0DMpRs74CJux",
        "articles" => "tblJM9zmThl82vRD4"
      },
      #climate_change
      "appGv6qmDJK2Kdr3U" => %{
        "uk_climate_change" => "tblf0C8GtEXO0J8mk",
        "Articles" => "tblZcr9MnPctaHJST"
      },
      #energy
      "app4L95N2NbK7x4M0" => %{
        "uk_energy" => "tblTc2z9Jfl7Mqc2N",
        "Articles" => "tblnsuOdMTDbx1mBZ"
      },
      #finance
      "appokFoa6ERUUAIkF" => %{
        "uk_finance" => "tblf0C8GtEXO0J8mk",
        "Articles" => "tblH107AQKjlk409E"
      },
      #marine_riverine
      "appLXqkeiiqrOXwWw" => %{
        "uk_marine_riverine" => "tbl235dp4xykUjJ0Z",
        "Articles" => "tbl4EL3E2oSSerOLv"
      },
      #planning
      "appJ3UVvRHEGIpNi4" => %{
        "uk_planning" => "tblzltGwSX2DcP8oH",
        "Articles" => "tbl2KfEVBN678T573"
      },
      #pollution
      "appj4oaimWQfwtUri" => %{
        "uk_pollution" => "tblkO070AAO2ARVvb",
        "Articles" => "tblCLJTI62iGWXcgh"
      }















    }
  end

end
