defmodule Legl.Countries.Uk.LeglFitness.RuleProvisionsTest do
  @moduledoc false
  # mix test test/legl/countries/uk/legl_fitness/rule_provisions_test.exs:8
  use ExUnit.Case, async: true

  alias Legl.Countries.Uk.LeglFitness.RuleProvisions, as: RP
  alias Legl.Countries.Uk.Support.LeglFitnessProvisionTest, as: Data

  @articles Data.data()

  test "api_get_list_of_article_numbers/1" do
    Enum.map(@articles, fn {rule, result: result} ->
      IO.puts("RULE: #{inspect(rule.rule)}")
      response = RP.api_get_list_of_article_numbers([rule]) |> hd() |> Map.get(:provision_number)
      IO.puts("RESPONSE: #{inspect(response)}\n")
      assert response == result
    end)
  end

  test "build_heading_map/1" do
    records = Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))
    # IO.inspect(records, limit: :infinity, label: "records")
    result = RP.build_heading_map(records)
    IO.puts("#{inspect(result)}")
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
    result = RP.api_get_provision(@fitnesses, @heading_index)
    IO.puts("#{inspect(result)}")
    assert is_list(result)
  end
end
