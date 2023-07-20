defmodule Legl.Countries.Uk.UkTypeCode do
  defstruct ukpga: "ukpga",
            uksi: "uksi",
            nia: "nia",
            apni: "apni",
            nisi: "nisi",
            nisr: "nisr",
            nisro: "nisro",
            asp: "asp",
            ssi: "ssi",
            asc: "asc",
            anaw: "anaw",
            mwa: "mwa",
            wsi: "wsi",
            ni: ["nia", "apni", "nisi", "nisr", "nisro"],
            s: ["asp", "ssi"],
            uk: ["ukpga", "uksi"],
            w: ["asc", "anaw", "mwa", "wsi"],
            o: ["ukcm", "ukla", "asc", "ukmo", "apgb", "aep"]

  def type_code(type_code) when is_atom(type_code) do
    case Map.get(%__MODULE__{}, type_code) do
      nil -> {:error, "No result for #{type_code}"}
      result when is_list(result) -> {:ok, result}
      result -> {:ok, [result]}
    end
  end

  def type_code(type_code) when is_list(type_code), do: {:ok, type_code}

  def type_code(nil), do: {:ok, [""]}

  def type_code(type_code) when is_binary(type_code), do: {:ok, [type_code]}

  def type_code(type_code),
    do: {:error, "Types for type_code must be Atom or List. You gave #{type_code}"}
end

defmodule Legl.Countries.Uk.UkTypeClass do
  @type_classes ~w[Act Regulations Order Rules Byelaws]
  defstruct act: "Act",
            regulation: "Regulations",
            order: "Order",
            rule: "Rules",
            byelaw: "Byelaws",
            measure: "Measure"

  def type_class(type_class) when is_atom(type_class) do
    case Map.get(%__MODULE__{}, type_class) do
      nil -> {:error, "No result for #{type_class}"}
      result -> {:ok, result}
    end
  end

  def type_class(type_class)
      when is_binary(type_class) and type_class in @type_classes,
      do: {:ok, type_class}

  def type_class(""), do: {:ok, ""}

  def type_class(type_class) when is_binary(type_class),
    do: {:error, "No result for #{type_class}"}
end

defmodule Legl.Countries.Uk.SClass do
  defstruct occupational_personal_safety: "Occupational / Personal Safety"

  def sClass(sClass) when is_atom(sClass) do
    case Map.get(%__MODULE__{}, sClass) do
      nil -> {:error, "No result for #{sClass}"}
      result -> {:ok, [result]}
    end
  end

  def sClass(sClass) when is_binary(sClass), do: {:ok, sClass}
end
