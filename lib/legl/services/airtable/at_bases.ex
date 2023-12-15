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
        base = reformat_base_name(base)

        case Map.get(base_ids(), base) do
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
      # 🖤 EHS -  🇬🇧️ UK
      "uk_ehs" => "appq5OQW9bTHC1zO5",

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
      "uk_e_town_country_planning" => "appPocx8hT0EPCSfh",

      # 💙 Health & Safety - 🇬🇧 ️UK
      "uk_s" => "appRhQoz94zyVh2LR",
      # 💙 OH&S - 🇬🇧 ️UK - Occupational / Personal Health and Safety
      "uk_s_ohs" => "appiwDnCNQaZOSaVR",
      # 💙 Fire Safety - 🇬🇧 ️UK
      "uk_fire" => "app0bGzy4uDbKrCF5"
    }
  end

  @bases [
           {"💙💚️ LRT - Environment, Health & Safety - UK", "appRhQoz94zyVh2LR"},
           {"💙 Occupational / Personal Health and Safety - UK", "appiwDnCNQaZOSaVR"},
           {"💙 Fire Safety - UK", "app0bGzy4uDbKrCF5"},
           {"💙 Product Safety & Consumer Protection - UK", ""},
           {"💙 Gas & Electrical Safety - UK", ""},
           {"💙 Offshore Safety - UK", ""},
           {"💙 Mine & Quarry Safety - UK", ""},
           {"💙 Dangerous & Explosive Substances - UK", ""},
           {"💚️ Climate Change - UK", "appGv6qmDJK2Kdr3U"},
           {"💚️ Energy - UK", "app4L95N2NbK7x4M0"},
           {"💚️ Environmental Protection - UK Environmental Protection", "appPFUz8wfo9RU7gN"},
           {"💚️ Finance - UK", "appokFoa6ERUUAIkF"},
           {"💚️ M&R - UK - Marine & Riverine", "appLXqkeiiqrOXwWw"},
           {"💚️ Planning - UK", "appJ3UVvRHEGIpNi4"},
           {"💚️ Pollution - UK", "appj4oaimWQfwtUri"},
           {"💚️ Radiological - UK", "appozWdOMaGdp77eL"},
           {"💚️ Town & Country Planning - UK", ""},
           {"️💚️ Waste - UK", "appfXbCYZmxSFQ6uY"},
           {"💚️ Water - UK", "appCZkMT3VlCLtBjy"},
           {"💚️ Wildlife & Countryside - UK", "appXXwjSS8KgDySB6"}
         ]
         |> Enum.with_index()
         |> Enum.into(%{}, fn {k, v} -> {v, k} end)

  def bases, do: @bases
end
