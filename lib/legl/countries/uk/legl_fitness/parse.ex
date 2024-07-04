defmodule Legl.Countries.Uk.LeglFitness.Parse do
  @moduledoc """
  Parses the applies_to field in the Legal Fitness Table (LFT)
  """

  require Logger
  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Countries.Uk.LeglFitness.ParseDefs

  @applies ParseDefs.applies()

  @disapplies ParseDefs.disapplies()

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
    [:person, :person_verb, :person_ii, :person_ii_verb, :plant],
    # 4
    [:person, :person_verb, :place, :property],
    [:person, :process, :plant, :property],
    [:person, :person_verb, :plant, :process],
    [:process, :plant, :person, :property],
    [:process, :person_verb, :person, :place],
    [:process, :person_verb, :plant, :person],
    [:person_verb, :plant, :person, :property],
    [:plant, :person_verb, :person, :process],
    #
    # [:person, :plant, :person_verb, :place],
    # [:person, :plant, :process, :property],
    # [:person, :plant, :process, :place],
    # [:person, :process, :place, :property],
    # [:process, :person, :place, :property],
    # [:process, :person_verb, :person, :place],
    # 3
    [:person, :person_verb, :plant],
    [:person, :person_verb, :place],
    [:person, :process, :property],
    [:person, :process, :plant],
    [:person, :plant, :person_verb],
    [:person, :plant, :process],
    [:person, :place, :property],
    [:plant, :property, :process],
    [:plant, :person_verb, :process],
    [:plant, :person, :property],
    [:place, :property, :process],
    [:process, :plant, :person],

    #

    # [:person, :process, :place],
    # [:process, :person, :place],
    # [:process, :person, :property],
    # [:process, :person_verb, :person],
    # [:process, :person_verb, :place],
    # [:process, :person_verb, :property],
    # [:process, :place, :property],
    # 2
    [:person, :plant],
    [:person, :process],
    [:plant, :process],
    [:plant, :person_verb],
    [:process, :person],
    [:process, :plant],
    [:place, :process],
    #
    # [:person, :place],
    # [:process, :person_verb],
    # [:process, :place],
    # [:process, :property],
    # [:place, :property],
    # 1
    [:place],
    [:plant],
    [:process],
    [:person]
    # [:property]
  ]
  @specials [
    [:person_ii, :property, :person_ii_verb, :process, :person_verb, :person],
    [:person_ii, :person_ii_verb, :process, :person_verb, :person]
  ]
  @applies_specials Enum.map(
                      @specials,
                      fn special ->
                        special
                        |> Enum.map_join(".*?", fn x ->
                          ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/
                        end)
                        |> (&(~s/.*?(?:he|employer)[ ](?:is|must|shall).*?under a like duty in respect of.*?/ <>
                                &1)).()
                        |> Regex.compile!()
                      end
                    )
  @applies_regex Enum.map(
                   @term_map,
                   fn term ->
                     term
                     |> Enum.map_join(".*?", fn x -> ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/ end)
                     |> (&(~s/.*?#{@applies}.*?/ <> &1)).()
                     |> Regex.compile!()
                   end
                 )
                 |> (&(&1 ++ @applies_specials)).()

  @disapplies_regex Enum.map(
                      @term_map,
                      fn term ->
                        term
                        |> Enum.map_join(".*?", fn x ->
                          ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/
                        end)
                        |> (&(~s/.*?#{@disapplies}.*?/ <> &1)).()
                        |> Regex.compile!()
                      end
                    )

  @qualified_applies_regex Enum.map(
                             @term_map,
                             fn term ->
                               term
                               |> Enum.map_join(".*?", fn x ->
                                 ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/
                               end)
                               |> (&(~s/.*?/ <> &1)).()
                               |> Regex.compile!()
                             end
                           )

  @qualified_disapplies_regex Enum.map(
                                @term_map,
                                fn term ->
                                  term
                                  |> Enum.map_join(".*?", fn x ->
                                    ~s/(?<#{x}>#{apply(ParseDefs, x, [])})/
                                  end)
                                  |> (&(~s/.*?/ <> &1)).()
                                  |> Regex.compile!()
                                end
                              )

  def regex_printer_applies(index),
    do: List.pop_at(@applies_regex, index) |> elem(0)

  def regex_printer_disapplies(index),
    do: List.pop_at(@disapplies_regex, index) |> elem(0)

  @doc """
    Parses the fitness struct based on the category

    Normally only content after the (dis)applies clause is parsed.
    However, if the rule contains a qualified rule, the entire rule is parsed.

    ## Parameters
    fitness - The fitness struct

  """
  def api_parse(%{category: category} = fitness) do
    case qualified_rule?(fitness.rule.rule) do
      true ->
        case category do
          "applies-to" -> parse(fitness, @qualified_applies_regex)
          "disapplies-to" -> parse(fitness, @qualified_disapplies_regex)
        end

      false ->
        case category do
          "applies-to" -> parse(fitness, @applies_regex)
          "disapplies-to" -> parse(fitness, @disapplies_regex)
        end
    end
  end

  defp qualified_rule?(rule) do
    Enum.any?(ParseDefs.qualified_rule(), &Regex.match?(~r/#{&1}/, rule))
  end

  defp parse(%{rule: %{rule: rule}} = fitness, regexes) do
    Enum.reduce_while(regexes, [], fn regex, acc ->
      case Regex.named_captures(regex, rule, capture: :all_names) do
        result when is_map(result) ->
          IO.puts("")
          Logger.info(~s/Rule: #{rule}/)
          Logger.info(~s/Regex: #{inspect(regex)}/)
          Logger.info(~s/Result: #{inspect(result)}/)

          pattern =
            Regex.scan(~r/<.*?>/, ~s/#{inspect(regex)}/)
            |> List.flatten()
            |> tap(&Logger.info(~s/Pattern: #{inspect(&1)}/))

          result =
            result
            |> Map.put("pattern", pattern)
            |> format()

          acc =
            result
            |> Fitness.make_fitness_struct(fitness)
            |> (&[&1 | acc]).()

          {:halt, acc}

        nil ->
          {:cont, acc}
      end
    end)
    |> case do
      [] -> [%{unmatched_fitness: fitness}]
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
               "plant"
             ] ->
          {key, format_select_option(value)}

        "property" ->
          property =
            value
            |> format_select_option()
            |> (&standardise(ParseDefs.standard_properties(), &1)).()

          {key, property}

        # Multi Selects
        "place" ->
          {key, format_multi_select_option(value)}

        "process" ->
          # Separate processes with ["and", ",", "or"]
          processes =
            String.split(value, " and ")
            |> Enum.map(&String.split(&1, ", "))
            |> List.flatten()
            |> Enum.map(&on_or_off/1)
            |> List.flatten()
            |> Enum.map(&String.split(&1, " or "))
            |> List.flatten()
            |> Enum.map(&format_select_option/1)
            |> Enum.map(&standardise(ParseDefs.standard_processes(), &1))

          {key, processes}

        "person" ->
          persons =
            value
            |> format_select_option()
            |> remap_person_match()

          {key, persons}

        _ ->
          {key, value}
      end
    end)
    |> List.flatten()
    |> Enum.into(%{})
  end

  defp on_or_off(text) do
    case Regex.named_captures(~r/(?<pre>.*?) (?<mid>on or off) (?<post>.*)/, text) do
      nil ->
        text

      map ->
        [
          map["pre"] <> " on " <> map["post"],
          map["pre"] <> " off " <> map["post"]
        ]
    end
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

  defp remap_person_match("master" <> _person) do
    ["master-of-a-ship", "crew-of-a-ship", "employer-of-such-persons"]
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
      nil -> [person]
      result -> [result]
    end
  end

  defp standardise(standards, text) do
    Enum.map(standards, fn standard ->
      case String.jaro_distance(text, standard) do
        distance when distance > 0.8 -> standard
        _ -> text
      end
    end)
    |> List.first()
  end
end
