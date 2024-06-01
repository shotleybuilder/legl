defmodule Legl.Countries.Uk.LeglFitness.ParseTest do
  # mix test test/legl/countries/uk/legl_fitness/parse_test.exs:8
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness
  alias Legl.Countries.Uk.LeglFitness.ParseFixturesTest

  test "regex_printer/1" do
    index = 0

    LeglFitness.Parse.regex_printer_applies(index)
    |> IO.inspect(label: "Regex")
  end

  # @data ParseTestFixtures.data()

  test "api_parse/1" do
    Enum.each(ParseFixturesTest.data(), fn %{test: test, result: result} ->
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
    test = %LeglFitness.Fitness{
      category: "applies-to",
      rule:
        "These Regulations shall apply outside Great Britain as sections 1 to 59 and 80 to 82 of the 1974 Act apply by virtue of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2001 M3."
    }

    result = %LeglFitness.Fitness{
      rule: test.rule,
      category: "extends-to",
      place: ["outside-gb"],
      scope: "Whole"
    }

    response = LeglFitness.Parse.api_parse(test) |> List.first()

    assert result == response
  end
end
