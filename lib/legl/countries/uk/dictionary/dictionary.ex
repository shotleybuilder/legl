defmodule Dictionary do
  @moduledoc false

  @empty_set MapSet.new()
  @dictionary Path.absname("lib/legl/countries/uk/dictionary/dictionary.txt")
  @word_list Path.absname("lib/legl/countries/uk/dictionary/words.txt")
  # Builds the @words MapSet at compile time
  @words Regex.split(~r/[\n+]/, @word_list |> File.read!())
         |> Enum.filter(fn x -> x != "" end)
         |> Enum.reduce(Map.new(), fn item, acc ->
           Map.update(acc, String.slice(item, 0..4), 1, &(&1 + 1))
         end)
         |> Map.keys()
         |> MapSet.new()

  @doc """
  Created to help fix concatenated Roman Numeral section numbering and headings,
  e.g.

  Section IInformation -> Section I Information

  Section IIInformation -> section II Information

  Match a single word provided as the parameter

  Returns `:true` or `:false`
  """
  @spec match?(String.t()) :: Boolean
  def match?(word) do
    ms =
      String.slice(word, 0..4)
      |> String.downcase()
      |> (&MapSet.put(@empty_set, &1)).()

    cond do
      MapSet.intersection(ms, @words) != @empty_set ->
        true

      true ->
        false
    end
  end

  @doc """
  Converts the whole words in the Dictionary file into
  unqiue 5 character or less starts of "I" and "V" words
  eg "ill", "inter", "vote"

  Saves into the words.txt file.

  Function should be run after including more I and V words into the dictionary.

  Returns `:ok`
  """
  @spec __save_words__() :: Atom
  def __save_words__ do
    File.read!(@dictionary)
    |> (&Regex.replace(~r/^\*\*[\s\S]+^\*\*/m, &1, "")).()
    |> (&Regex.split(
          ~r/[\s+]/,
          &1
          |> String.downcase()
        )).()
    |> Enum.filter(fn x -> x != "" end)
    |> Enum.sort()
    |> Enum.join("\n")
    |> (&File.write("lib/uk/dictionary/words.txt", &1)).()
  end
end
