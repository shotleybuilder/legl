defmodule Legl.Countries.Uk.LeglInterpretation.InterpretationTest do
  # mix test test/legl/countries/uk/legl_interpretation/interpretation_test.exs
  use ExUnit.Case
  alias Legl.Countries.Uk.LeglInterpretation.Interpretation

  @path ~s[lib/legl/data_files/json/at_schema.json] |> Path.absname()
  @records Legl.Utility.read_json_records(@path)

  test "interpretation_patterns/0" do
    result = Interpretation.interpretation_patterns()
    assert result == [~r/“([a-z -]*)”([\s\S]*?)(?=(?:\.$|;\n“|\]$))/m]
  end

  test "filter_interpretation_sections/1" do
    result = Interpretation.filter_interpretation_sections(@records)
    assert is_list(result)
    assert Enum.count(result) > 1
  end

  test "parse_interpretation_section/1" do
    result = Interpretation.parse_interpretation_section(@records)

    Enum.each(result, fn {term, defn} ->
      assert is_binary(term)
      assert is_binary(defn)
    end)
  end

  test "api_interpretation/2" do
    result = Interpretation.process(@records, %{})

    Enum.each(result, fn map ->
      assert %Interpretation{} = map
      IO.inspect(map)
    end)
  end

  @records Kernel.struct(Interpretation,
             Term: "foo",
             Definition: "Bar",
             Linked_LRT_Records: ["abc123"]
           )
           |> List.wrap()

  describe "tag_for_create_or_update/2" do
    test "term present = false" do
      results = []

      result = Interpretation.tag_for_create_or_update(@records, results)
      [record | _] = @records

      assert result == record |> Map.from_struct() |> Map.put(:action, :post) |> List.wrap()
    end

    test "term present = true & term defined by this law? = true & definition changed? = false" do
      results = [%{Term: "foo", Definition: "Bar", Linked_LRT_Records: ["abc123", "xyz321"]}]

      result = Interpretation.tag_for_create_or_update(@records, results)

      assert result == []
    end

    test "term present = true & term defined by this law? = true & multiple defining laws? = true & definition changed? = true" do
      results = [
        %{
          record_id: "123456",
          Term: "foo",
          Definition: "Baz",
          Linked_LRT_Records: ["abc123", "xyz321"]
        }
      ]

      response = Interpretation.tag_for_create_or_update(@records, results)

      assert response == [
               @records |> List.first() |> Map.from_struct() |> Map.put(:action, :post),
               results
               |> List.first()
               |> Map.put(:Linked_LRT_Records, ["xyz321"])
               |> Map.put(:action, :patch)
             ]
    end

    test "term present = true & term defined by this law? = true & multiple defining laws? = false & definition changed? = true" do
      results = [
        %{record_id: "123456", Term: "foo", Definition: "Baz", Linked_LRT_Records: ["abc123"]}
      ]

      response = Interpretation.tag_for_create_or_update(@records, results)

      assert response == [
               results
               |> List.first()
               |> Map.put(:action, :patch)
               |> Map.put(:Definition, "Bar")
               |> Map.drop([:Linked_LRT_Records])
             ]
    end

    test "term present = true & term defined by this law? = false & definition present? = true" do
      results = [
        %{record_id: "123456", Term: "foo", Definition: "Bar", Linked_LRT_Records: ["xyz321"]}
      ]

      response = Interpretation.tag_for_create_or_update(@records, results)

      assert response == [
               results
               |> List.first()
               |> Map.put(:action, :patch)
               |> Map.put(:Linked_LRT_Records, ["abc123", "xyz321"])
             ]
    end

    test "term present = true & term defined by this law? = false & definition present? = false" do
      results = [
        %{record_id: "123456", Term: "foo", Definition: "Baz", Linked_LRT_Records: ["xyz321"]}
      ]

      response = Interpretation.tag_for_create_or_update(@records, results)

      assert response == [
               @records
               |> List.first()
               |> Map.from_struct()
               |> Map.put(:action, :post)
             ]
    end
  end
end
