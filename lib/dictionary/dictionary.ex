defmodule Dictionary do
  @moduledoc """
  Builds the @words MapSet at compile time
  The MapSet is unqiue 5 character or less start of "I" and "V" words
  eg "ill", "inter", "vote"
  """
  @empty_set MapSet.new()
  @dictionary Path.absname("lib/dictionary/dictionary.txt")
  @word_list Path.absname("lib/dictionary/words.txt")
  @words Regex.split(~r/[\n+]/, @word_list |> File.read!())
         |> Enum.filter(fn x -> x != "" end)
         |> Enum.reduce(Map.new(), fn item, acc ->
           Map.update(acc, String.slice(item, 0..4), 1, &(&1 + 1))
         end)
         |> Map.keys()
         |> MapSet.new()

  @doc """
  Match a single word provided as the parameter
  """
  @spec match?(String.t()) :: Boolean
  def match?(word) do
    ms =
      String.slice(word, 0..4)
      |> String.downcase()
      |> (&MapSet.put(@empty_set, &1)).()

    cond do
      MapSet.intersection(ms, @words) != @empty_set -> true
      true -> false
    end
  end

  @doc """
  Converts the whole words in the Dictionary file into
  unqiue 5 character or less starts of "I" and "V" words
  eg "ill", "inter", "vote"
  Saves into the words.txt file.
  Function should be run after including more I and V words into the dictionary
  """
  @spec save_words() :: Atom
  def save_words do
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
    |> (&File.write("lib/dictionary/words.txt", &1)).()
  end
end
