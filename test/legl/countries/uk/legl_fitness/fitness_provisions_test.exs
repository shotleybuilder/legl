defmodule Legl.Countries.Uk.LeglFitness.FitnessProvisionsTest do
  # mix test test/legl/countries/uk/legl_fitness/fitness_provisions_test.exs:8
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness.FitnessProvisions, as: FP

  @articles [
    %{
      rule: "These regulations shall not apply to a workplace which is or is in or on a ship",
      result: []
    },
    %{rule: "Regulation 20 applies", result: ["20"]},
    %{
      rule: "Regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to a",
      result: ["7(1A)", "12", "14", "15", "16", "18", "19", "26(1)"]
    },
    %{rule: "Regulations 18 and 25A apply to a", result: ["18", "25A"]},
    %{
      rule: "Regulations 8(1) and (3) and 12(1) and (3) apply to a",
      result: ["8(1)", "8(3)", "12(1)", "12(3)"]
    },
    %{rule: "Regulation 13 shall apply to a", result: ["13"]},
    %{
      rule: "Regulations 5 to 7 and 14 to 20 shall not apply to a",
      result: ["5", "6", "7", "14", "15", "16", "17", "18", "19", "20"]
    },
    %{
      rule:
        "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply",
      result: ["9", "18(1)(a)", "22"]
    },
    %{
      rule:
        "As respects any workplace which is in fields, woods or other land forming part of an agricultural or forestry undertaking but which is not inside a building and is situated away from the undertaking's main buildings any requirement to ensure that any such workplace complies with any of regulations 20 to 22 shall have effect as a requirement to so ensure so far as is reasonably practicable.",
      result: []
    }
  ]

  test "get_list_of_article_numbers/1" do
    Enum.each(@articles, fn %{rule: rule, result: test_result} ->
      result = FP.get_list_of_article_numbers(rule)
      IO.inspect(result)
      assert result == test_result
    end)
  end

  test "build_heading_map/1" do
    records = Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))
    # IO.inspect(records, limit: :infinity, label: "records")
    result = FP.build_heading_map(records)
    IO.inspect(result)
    assert is_map(result)
  end

  @heading_index %{
    "7" => "risk-assessment",
    "20" => "general-duties-of-employers-to-their-employees",
    "26" => "prohibition-of-smoking-in-certain-premises"
  }

  @fitnesses [
    %{
      rule: "Regulation 20 applies to a workplace.",
      provision: [],
      provision_number: ["20"]
    },
    %{
      rule: "Regulations 7(1a), 12 and 26(1) apply to a workplace",
      provision: [],
      provision_number: ["7(1A)", "12", "26(1)"]
    }
  ]

  test "api_get_provision/2" do
    result = FP.api_get_provision(@fitnesses, @heading_index)
    IO.inspect(result)
    assert is_list(result)
  end
end
