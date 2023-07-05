defmodule Legl.Services.Airtable.AtBases do
  @doc """
    Returns the Airtable Base ID
    If the real Base ID is used then this is simply returned after checking
    the structure and length.
    If the name of the Base is used then the actual ID is read from the map.
  """
  def get_base_id(base) do
    case String.starts_with?(base, "app") and String.length(base) == 17 do
      true ->
        {:ok, base}

      _ ->
        case Map.get(base_ids(), reformat_base_name(base)) do
          nil ->
            {:error, "Base not found for #{base}"}

          base_id ->
            {:ok, base_id}
        end
    end
  end

  @spec reformat_base_name(binary) :: binary
  defp reformat_base_name(str) do
    str
    |> String.downcase()
    |> String.replace("base", "")
    |> String.replace(~r/ +/, " ", global: true)
    |> String.replace(~r/[-|&| ]/, "_")
    |> String.trim()
    |> String.replace(~r/_+/, "_", global: true)
    |> String.replace("+", "")
  end

  defp base_ids() do
    %{
      # UK
      # UK 🇬🇧️ E 💚️
      "uk_e" => "appq5OQW9bTHC1zO5",
      # 💚️ EP - 🇬🇧️ UK Environmental Protection
      "uk_e_environmental_protection" => "appPFUz8wfo9RU7gN",
      # UK 🇬🇧️ E 💚️ - Climate Change
      "uk_e_climate_change" => "appGv6qmDJK2Kdr3U",
      # UK 🇬🇧️ E 💚️ - Energy
      "uk_e_energy" => "app4L95N2NbK7x4M0",
      # UK 🇬🇧️ E 💚️ - Marine & Riverine
      "uk_e_marine_riverine" => "appLXqkeiiqrOXwWw",
      # UK 🇬🇧️ E 💚️ - Planning
      "uk_e_planning" => "appJ3UVvRHEGIpNi4",
      # UK 🇬🇧️ E 💚️ - Pollution
      "uk_e_pollution" => "appj4oaimWQfwtUri",
      # UK 🇬🇧️ E 💚️ - Waste
      "uk_e_waste" => "appfXbCYZmxSFQ6uY",
      # 💚️ Finance - 🇬🇧️ UK
      "uk_e_finance" => "appokFoa6ERUUAIkF",
      # 💚️ Water - 🇬🇧️ UK
      "uk_e_water" => "appCZkMT3VlCLtBjy",
      # 💚️ W&C - 🇬🇧️ UK - Wildlife & Countryside
      "uk_e_wildlife_countryside" => "appXXwjSS8KgDySB6",
      # 💚️ Radiological - 🇬🇧️ UK
      "uk_e_radiological" => "appozWdOMaGdp77eL",
      # 💚️ T&CP - 🇬🇧️ UK - Town & Country Planning
      "uk_e_town_country_planning" => "appPocx8hT0EPCSfh"
    }
  end
end
