defmodule Legl.Countries.Uk.LeglFitness.ParseTest do
  @moduledoc false
  # mix test test/legl/countries/uk/legl_fitness/parse_test.exs:8
  require Logger
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness
  alias Legl.Countries.Uk.Support.LeglFitnessParseTest

  test "regex_printer/1" do
    index = 0

    LeglFitness.Parse.regex_printer_applies(index)
    |> tap(&Logger.info("Regex:  #{inspect(&1)}"))
  end

  # @data ParseTestFixtures.data()

  test "api_parse/1" do
    Enum.each(LeglFitnessParseTest.data(), fn %{test: test, result: result} ->
      full_result =
        cond do
          test.rule == "" ->
            result

          Map.has_key?(result, :unmatched_fitness) ->
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

  test "parse_extends_to/1" do
    fitnesses =
      [
        %{
          test: %LeglFitness.Fitness{
            category: "applies-to",
            rule: %LeglFitness.Rule{
              rule:
                "These Regulations shall apply outside Great Britain as sections 1 to 59 and 80 to 82 of the 1974 Act apply by virtue of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2001 M3."
            },
            place: "Great Britain"
          },
          result: %LeglFitness.Fitness{
            category: "extends-to",
            pattern: ["<place>"],
            place: ["outside-great-britain"],
            rule: %LeglFitness.Rule{
              rule:
                "These Regulations shall apply outside Great Britain as sections 1 to 59 and 80 to 82 of the 1974 Act apply by virtue of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2001 M3.",
              scope: "Whole"
            }
          }
        },
        %{
          test: %LeglFitness.Fitness{
            category: "applies-to",
            rule: %LeglFitness.Rule{
              rule:
                "Paragraph (6) does not apply to a ship's work equipment provided for use or used in an activity (whether carried on in or outside Great Britain) specified in the 1995 Order."
            },
            place: "Great Britain"
          },
          result: %LeglFitness.Fitness{
            category: "applies-to",
            place: "Great Britain",
            rule: %Legl.Countries.Uk.LeglFitness.Rule{
              rule:
                "Paragraph (6) does not apply to a ship's work equipment provided for use or used in an activity (whether carried on in or outside Great Britain) specified in the 1995 Order."
            }
          }
        }
      ]

    Enum.each(fitnesses, fn %{test: test, result: result} ->
      response = LeglFitness.ParseExtendsTo.parse_extends_to(test)

      assert result == response
    end)
  end
end
