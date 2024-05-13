defmodule Legl.Countries.Uk.LeglFitness.Parse do
  @moduledoc """
  Parses the applies_to field in the Legal Fitness Table (LFT)
  """

  require Logger
  require Legl.Countries.Uk.LeglFitness.Parse
  alias Legl.Countries.Uk.LeglFitness.Fitness

  alias Legl.Countries.Uk.LeglFitness.ParseDefs

  @applies [
    "(?:shall |doe?s? )?(?:apply|extend) (?:only )?(?:to|within)"
  ]

  @disapplies [
    "(?:shall|doe?s?) not (?:apply|extend) (?:to|where)"
  ]

  # Build the regex based on the combinations of the applies_to fields
  # person, person_verb, process, person_ii_verb, person_ii, place, plant, property
  # A Person with a Process MUST have a person_verb
  # A Process with a Person MUST have a person_ii

  @term_map [
    # 6
    # [:person, :property, :person_verb, :process, :person_ii_verb, :person_ii],
    # [:person, :plant, :person_verb, :process, :property],
    # [:person, :plant, :person_verb, :place, :property],
    # [:person, :plant, :process, :place, :property],
    # [:process, :person_verb, :person, :place, :property],
    # 4
    [:person, :person_verb, :place, :property],
    [:process, :plant, :person, :property],
    [:process, :person_verb, :person, :place],
    [:process, :person_verb, :plant, :person],
    [:person_verb, :plant, :person, :property],
    #
    # [:person, :plant, :person_verb, :place],
    # [:person, :plant, :process, :property],
    # [:person, :plant, :process, :place],
    # [:person, :process, :place, :property],
    # [:process, :person, :place, :property],
    # [:process, :person_verb, :person, :place],
    # 3
    [:process, :plant, :person],
    [:plant, :property, :process],
    [:plant, :person, :property],
    [:place, :property, :process],
    [:person, :place, :property],
    [:person, :person_verb, :place],
    #
    # [:person, :process, :property],
    # [:person, :process, :place],
    # [:process, :person, :place],
    # [:process, :person, :property],
    # [:process, :person_verb, :person],
    # [:process, :person_verb, :place],
    # [:process, :person_verb, :property],
    # [:process, :place, :property],
    # 2
    [:person, :process],
    [:process, :person],
    [:place, :process],
    #
    # [:person, :place],
    # [:process, :person_verb],
    # [:process, :place],
    # [:process, :property],
    # [:place, :property],
    # 1
    [:process],
    [:person],
    [:place]
    #
    # [:property]
  ]
  @specials [
    [:person_ii, :property, :person_ii_verb, :process, :person_verb, :person],
    [:person_ii, :person_ii_verb, :process, :person_verb, :person]
  ]
  @applies_specials Enum.map(@specials, fn special ->
                      Regex.compile!(
                        special
                        |> Enum.map(fn x -> ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/ end)
                        |> Enum.join(".*?")
                        |> (&(~s/.*?(?:he|employer)[ ](?:is|must|shall).*?under a like duty in respect of.*?/ <>
                                &1)).()
                      )
                    end)
  @applies_regex Enum.map(
                   @term_map,
                   fn term ->
                     term
                     |> Enum.map(fn x -> ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/ end)
                     |> Enum.join(".*?")
                     |> (&(~s/.*?#{@applies}.*?/ <> &1)).()
                     |> Regex.compile!()
                   end
                 )
                 |> (&(&1 ++ @applies_specials)).()

  @disapplies_regex Enum.map(
                      @term_map,
                      fn term ->
                        term
                        |> Enum.map(fn x -> ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/ end)
                        |> Enum.join(".*?")
                        |> (&(~s/.*?#{@disapplies}.*?/ <> &1)).()
                        |> Regex.compile!()
                      end
                    )

  def regex_printer(index),
    do: List.pop_at(@applies_regex, index) |> elem(0)

  # IO.inspect(@applies_to, label: "Applies To REGEX")

  def api_parse(%{category: category} = fitness) do
    case category do
      "applies-to" -> parse(fitness, @applies_regex)
      "disapplies-to" -> parse(fitness, @disapplies_regex)
    end
  end

  defp parse(%{rule: text} = fitness, regexes) do
    Enum.reduce_while(regexes, [], fn regex, acc ->
      case Regex.named_captures(regex, text, capture: :all_names) do
        result when is_map(result) ->
          IO.puts("")
          IO.inspect(result, label: "Result")
          IO.inspect(regex, label: "Regex")
          IO.inspect(text, label: "Text")

          acc =
            result
            |> format()
            |> Fitness.make_fitness_struct(fitness)
            |> (&[&1 | acc]).()

          {:halt, acc}

        nil ->
          {:cont, acc}
      end
    end)
    |> case do
      [] -> [%{unmatched_text: text}]
      list -> list
    end
  end

  defp format(result) do
    result
    |> Enum.map(fn {key, value} ->
      case key do
        # Selects
        k
        when k in [
               "person_verb",
               "person_ii_verb",
               "person_ii",
               "plant",
               "property"
             ] ->
          {key, format_select_option(value)}

        # Multi Selects
        "place" ->
          {key, format_multi_select_option(value)}

        "process" ->
          # Separate processes with "and" or ","
          processes =
            String.split(value, " and ")
            |> Enum.map(&String.split(&1, ", "))
            |> List.flatten()
            |> Enum.map(&format_select_option/1)

          {key, processes}

        "person" ->
          # Separate persons with "or"
          persons =
            Enum.map(String.split(value, " or "), &format_select_option/1)
            |> Enum.map(&remap_person_match(&1))

          {key, persons}

        _ ->
          {key, value}
      end
    end)
    |> Enum.into(%{})
  end

  defp format_select_option(text) do
    text
    |> String.replace(~r/[\s,]+/, " ")
    |> String.downcase()
    |> String.replace(" ", "-")
  end

  defp format_multi_select_option(text) do
    text
    |> String.replace(~r/[\s,]+/, " ")
    |> String.downcase()
    |> String.replace(" ", "-")
    |> List.wrap()
  end

  defp remap_person_match(person) do
    # Maps person phrases to simpler tags
    mapping = %{
      "persons" => "person",
      "persons-who-are-not-its-employees" => "x-employee",
      "persons-who-are-not-his-employees" => "x-employee",
      "persons-who-are-not-employees-of-that-employer" => "x-employee"
    }

    case Map.get(mapping, person) do
      nil -> person
      result -> result
    end
  end
end
