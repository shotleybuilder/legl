defmodule Legl.Countries.Uk.LeglFitness.ParseTest do
  # mix test test/legl/countries/uk/legl_fitness/parse_test.exs:8
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness
  alias Legl.Countries.Uk.Support.LeglFitnessParseTest

  test "regex_printer/1" do
    index = 0

    LeglFitness.Parse.regex_printer_applies(index)
    |> IO.inspect(label: "Regex")
  end

  # @data ParseTestFixtures.data()

  test "api_parse/1" do
    Enum.each(LeglFitnessParseTest.data(), fn %{test: test, result: result} ->
      full_result =
        cond do
          test.rule == "" ->
            result

          result.category != nil ->
            Map.merge(result, %{rule: test.rule})

          true ->
            Map.merge(result, %{category: test.category, rule: test.rule})
        end

      response = LeglFitness.Parse.api_parse(test) |> List.first()

      assert full_result == response
    end)
  end

  test "api_parse/1 - extends-to" do
    fitnesses =
      [
        %{
          test: %LeglFitness.Fitness{
            category: "applies-to",
            rule:
              "These Regulations shall apply outside Great Britain as sections 1 to 59 and 80 to 82 of the 1974 Act apply by virtue of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2001 M3."
          },
          result: %LeglFitness.Fitness{
            category: "extends-to",
            pattern: ["<place>"],
            place: ["outside-gb"],
            scope: "Whole"
          }
        },
        %{
          test: %LeglFitness.Fitness{
            category: "applies-to",
            rule:
              "Paragraph (6) does not apply to a ship's work equipment provided for use or used in an activity (whether carried on in or outside Great Britain) specified in the 1995 Order."
          },
          result: %LeglFitness.Fitness{
            pattern: ["<place>"],
            category: "applies-to",
            place: ["outside-great-britain"]
          }
        }
      ]

    Enum.each(fitnesses, fn %{test: test, result: result} ->
      response = LeglFitness.Parse.api_parse(test) |> List.first()

      result = Map.put(result, :rule, test.rule)

      assert result == response
    end)
  end
end
