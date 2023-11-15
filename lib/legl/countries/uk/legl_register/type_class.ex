defmodule Legl.Countries.Uk.LeglRegister.TypeClass do
  @type_classes ~w[Act Regulations Order Rules Byelaws]
  defstruct act: "Act",
            regulation: "Regulation",
            order: "Order",
            rule: "Rules",
            byelaw: "Byelaws",
            measure: "Measure"

  def type_class(nil), do: {:ok, ""}

  def type_class(type_class) when is_atom(type_class) do
    case Map.get(%__MODULE__{}, type_class) do
      nil -> {:error, "No type_class result for #{type_class}"}
      result -> {:ok, result}
    end
  end

  def type_class(type_class)
      when is_binary(type_class) and type_class in @type_classes,
      do: {:ok, type_class}

  def type_class(""), do: {:ok, ""}

  def type_class(type_class) when is_binary(type_class),
    do: {:error, "No type_class result for #{type_class}"}

  @doc """
  Function to set the value of the type_class field in the Legal Register
  """
  @spec set_type_class(LR.legal_register()) :: LR.legal_register()

  def set_type_class(%_{type_class: type_class} = record)
      when type_class in [
             "Act",
             "Regulation",
             "Order",
             "Rules",
             "Scheme",
             "Confirmation Statement",
             "Byelaws"
           ],
      do: record

  def set_type_class(%_{Title_EN: title} = record) when title != nil do
    IO.write(" TYPE-CLASS")
    # A nil return means we've not been able to parse the :Title_EN field correctly
    case get_type_class(title) do
      nil ->
        IO.puts(
          "\nERROR: :Title_EN field could not be parsed for type_class\ntype_class cannot be set\n#{inspect(record)}"
        )

        record

      type_class ->
        {:ok, Map.put(record, :type_class, type_class)}
    end
  end

  def set_type_class(record), do: record

  defp get_type_class(title) do
    cond do
      Regex.match?(~r/Act[ ]?$|Act[ ]\(Northern Ireland\)[ ]?$/, title) ->
        "Act"

      Regex.match?(~r/Regulations?[ ]?$|Regulations? \(Northern Ireland\)[ ]?$/, title) ->
        "Regulation"

      Regex.match?(~r/Order[ ]?$|Order[ ]\(Northern Ireland\)[ ]?$/, title) ->
        "Order"

      Regex.match?(~r/Rules?[ ]?$|Rules?[ ]\(Northern Ireland\)[ ]?$/, title) ->
        "Rules"

      Regex.match?(~r/Scheme$|Schem[ ]\(Northern Ireland\)$/, title) ->
        "Scheme"

      Regex.match?(
        ~r/Confirmation[ ]Instrument$|Confirmation Instrument[ ]\(Northern Ireland\)$/,
        title
      ) ->
        "Confirmation Instrument"

      Regex.match?(~r/Byelaws$|Bye-?laws \(Northern Ireland\)$/, title) ->
        "Byelaws"

      true ->
        nil
    end
  end

  @doc """
  Function to set the value of the type field in the Legal Register
  """
  @spec set_type(LR.legal_register()) :: {:ok, LR.legal_register()}
  def set_type(%_{type_code: type_code} = record) do
    IO.write(" TYPE")

    {:ok,
     Map.put(
       record,
       :Type,
       case type_code do
         "ukpga" ->
           "Public General Act of the United Kingdom Parliament"

         "uksi" ->
           "UK Statutory Instrument"

         # SCOTLAND
         "asp" ->
           "Act of the Scottish Parliament"

         "ssi" ->
           "Scottish Statutory Instrument"

         # NORTHERN IRELAND
         "nisr" ->
           "Northern Ireland Statutory Rule"

         "nisi" ->
           "Northern Ireland Order in Council 1972-date"

         # WALES
         "wsi" ->
           "Wales Statutory Instrument 2018-date"

         "mwa" ->
           "Measure of the National Assembly for Wales 2008-2011"

         _ ->
           nil
       end
     )}
  end
end
