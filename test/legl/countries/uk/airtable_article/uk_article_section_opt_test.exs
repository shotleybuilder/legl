defmodule Legl.Countries.Uk.AirtableArticle.UkArticleSectionOptTest do
  use ExUnit.Case
  import Legl.Countries.Uk.AirtableArticle.UkArticleSectionsOptimisation
  # mix test test/legl/countries/uk/airtable_article/uk_article_section_opt_test.exs:8

  @test_data_single Enum.reduce(30..4, [], fn x, acc ->
                      [{:"F#{x}", {"F#{x}", "33-59", "repealed"}} | acc]
                    end)
                    # mapsets enforce non dupe values
                    |> MapSet.new()
                    # returns a list since mapsets do not guarantee order
                    |> Enum.sort_by(&Atom.to_string(elem(&1, 0)), {:desc, NaturalOrder})

  # [key: {["Fx",...], ["y",...], ["repealed",...]}, ]
  @model_optimiser [
    {:"33-59",
     {
       Enum.map(30..4, &"F#{&1}"),
       Enum.map(59..33, &"#{&1}"),
       Enum.map(1..27, fn _x -> "repealed" end)
     }}
  ]
  # [{:Fx, "Fx", "y", "repealed}}, ...]
  @mapper Enum.zip([
            Enum.map(30..4, &"F#{&1}"),
            Enum.map(59..33, &"#{&1}"),
            Enum.map(1..27, fn _x -> "repealed" end)
          ])
          |> Enum.reduce([], fn {ef, sn, amd}, acc ->
            acc ++ [{:"#{ef}", {ef, sn, amd}}]
          end)

  describe "optimise_ef_codes/2" do
    test "single_range of ef_codes" do
      result = optimise_ef_codes(@test_data_single, "TEST")

      assert result == @mapper
    end
  end

  describe "optimiser/1" do
    test "single_range of ef_codes" do
      result = optimiser(@test_data_single)

      assert result == @model_optimiser
    end
  end

  describe "mapper/1" do
    test "mapper/1 list count 1" do
      result = mapper(@model_optimiser)
      assert result == @mapper
    end
  end

  describe "remover/2" do
    test "remover/2 list count 1" do
      result = remover(@test_data_single, @mapper)
      assert [] == result
    end
  end
end
