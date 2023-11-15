defmodule Legl.Countries.Uk.LeglRegister.Tags do
  @doc """
  Function to set the value of the Tags field in the Legal Register
  """
  @spec set_tags(LR.legal_register()) :: {:ok, LR.legal_register()}
  def set_tags(record) do
    IO.write(" TAGS")

    record =
      case record do
        # Accumulate any record with a :Tags key containing a non-empty list
        %_{Tags: [_, _]} = record ->
          record

        %_{Title_EN: title} = record when title != nil ->
          Map.put(
            record,
            :Tags,
            tags(title)
          )

        %_{Title_EN: title} = record when title == nil ->
          IO.puts("...ERROR: :Title_EN == nil.  Tags key cannot be set")
          record

        # Pass through the record w/o setting :type_class if :Title_EN absent
        record ->
          IO.puts(
            "\nERROR: Record does not have a :Title_EN field\n:Tags key cannot be set\n#{inspect(record)}"
          )

          record
      end

    {:ok, record}
  end

  defp tags(title) do
    title
    |> String.trim()
    # Emulate the Airtable name_downcase formula field
    |> String.downcase()
    # Removes numbers and non-alphabetic characters
    |> (&Regex.replace(~r/[^a-zA-Z\s:]+/m, &1, "")).()
    # Duped space
    |> (&Regex.replace(~r/[ ]{2,}/, &1, " ")).()

    # REMOVE COMMON WORDS
    # Emulates the Airtable name_split formula field

    # To, the, this, that, these, those ...
    |> (&Regex.replace(~r/[ ]to[ ]|[ ]th[a|e|i|o]t?s?e?[ ]/, &1, " ")).()
    # A, an, and, at, are
    |> (&Regex.replace(
          ~r/^a[ ]|[ ]a[ ]|[ ]an[ ]|[ ]and[ ]|[ ]at[ ]|[ ]are[ ]/,
          &1,
          " "
        )).()
    # For, or
    |> (&Regex.replace(~r/[ ]f?or[ ]/, &1, " ")).()
    # If, in, is, it, its
    |> (&Regex.replace(~r/[ ][I|i][f|n][ ]|[ ][I|i][s|t]s?[ ]/, &1, " ")).()
    # Of, off, on
    |> (&Regex.replace(~r/[ ][O|o][f|n]f?[ ]/, &1, " ")).()
    # No, not
    |> (&Regex.replace(~r/[ ][N|n]ot?[ ]/, &1, " ")).()
    # Be, by
    |> (&Regex.replace(~r/[ ][B|b][e|y][ ]/, &1, " ")).()
    # Who, with
    |> (&Regex.replace(~r/[ ][W|w]i?t?ho?[ ]/, &1, " ")).()
    # Has, have
    |> (&Regex.replace(~r/[H| h]as?v?e?[ ]/, &1, " ")).()
    # Single letter word, a. a,
    |> (&Regex.replace(~r/[ ][A-Z|a-z][ |\.|,]/, &1, " ")).()
    # Depluralise
    # |> (&Regex.replace(~r/([abcdefghijklmnopqrtuvwxyz])s[ ]/, &1, "\\g{1} ")).()

    # Duped space
    |> (&Regex.replace(~r/[ ]{2,}/, &1, " ")).()
    # Comma at the start
    |> (&Regex.replace(~r/^,[ ]/, &1, "")).()

    # LIST of WORDS
    |> String.trim()
    |> String.split(" ")
    |> Enum.map(&String.trim(&1))
    |> Enum.map(&String.capitalize(&1))
  end
end
