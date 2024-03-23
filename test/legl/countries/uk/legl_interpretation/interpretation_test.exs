defmodule Legl.Countries.Uk.LeglInterpretation.InterpretationTest do
  # mix test test/legl/countries/uk/legl_interpretation/interpretation_test.exs
  use ExUnit.Case
  alias Legl.Countries.Uk.LeglInterpretation.Interpretation

  # Parse a law into at_schema.json by running:
  # UK.lat(type: :regulation, filesave?: true, pbs?: true, country: :uk)

  @path ~s[lib/legl/data_files/json/at_schema.json] |> Path.absname()
  @records Legl.Utility.read_json_records(@path)

  test "api_interpretation/1" do
    lrt_opts = [query_name: :Name, name: "UK_uksi_1992_2793"]
    lat_opts = []
    lit_opts = [lit_query_name: :Term]
    opts = [LRT: lrt_opts, LAT: lat_opts, LIT: lit_opts]
    response = Interpretation.api_interpretation(opts)
    assert response == :ok
  end

  test "interpretation_patterns/0" do
    result = Interpretation.interpretation_patterns(false)
    assert result == [~r/“([a-z -]*)”([\s\S]*?)(?=(?:\.$|;\n“|\]$))/m]
  end

  test "filter_interpretation_sections/1" do
    {interpretation_section, rest} = Interpretation.filter_interpretation_sections(@records)
    assert is_list(interpretation_section)
    assert is_list(rest)
    assert Enum.count(interpretation_section) > 1
    assert Enum.count(rest) > 1
  end

  # parse the law into at_schema.json before running this test

  test "parse_interpretation_section/1" do
    [h | _] = @records
    %{name: name} = h
    [_, type_code, _, _] = String.split(name, "_")

    {interpretation_section, rest} =
      @records
      |> Interpretation.filter_interpretation_sections()

    results =
      interpretation_section
      |> Interpretation.parse_interpretation_section(type_code, :inter)

    Enum.each(results, fn
      {term, _welsh, defn, _scope} ->
        assert is_binary(term)
        assert is_binary(defn)

      {term, defn, _scope} ->
        assert is_binary(term)
        assert is_binary(defn)
        # IO.puts(~s/RESULT\n#{inspect(result)}\n/)
    end)

    results =
      rest
      |> Interpretation.parse_interpretation_section(type_code, :rest)

    Enum.each(results, fn
      {term, _welsh, defn, _scope} ->
        assert is_binary(term)
        assert is_binary(defn)

      {term, defn, _scope} ->
        assert is_binary(term)
        assert is_binary(defn)
        # IO.puts(~s/RESULT\n#{inspect(result)}\n/)
    end)
  end

  test "build_interpretation_struct/2" do
    [h | _] = @records
    %{name: name} = h
    [_, type_code, _, _] = String.split(name, "_")

    {interpretation_section, rest} =
      @records
      |> Interpretation.filter_interpretation_sections()

    interpretation_section =
      interpretation_section
      |> Interpretation.parse_interpretation_section(type_code, :inter)

    rest = rest |> Interpretation.parse_interpretation_section(type_code, :rest)

    results =
      (interpretation_section ++ rest)
      |> Enum.uniq()
      |> Interpretation.build_interpretation_struct("xxxxxx")

    Enum.each(results, fn %_{Term: term, Definition: defn} = _result ->
      assert is_binary(term)
      assert is_binary(defn)
      # IO.puts(~s/RESULT\n#{inspect(result)}\n/)
    end)
  end

  test "process/2" do
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

  alias Legl.Countries.Uk.LeglInterpretation.Read

  describe "api_lit_read/1" do
    test "cancelled" do
      opts = [lit_query_name: -1]
      response = Read.api_lit_read(opts)
      assert response == :ok
    end

    test "term" do
      opts = [lit_query_name: :Term, term: "foo", test: true]
      response = Read.api_lit_read(opts)
      assert is_map(response)
      assert response.base_id == "appq5OQW9bTHC1zO5"
      assert response.formula == "AND({term}=\"foo\")"
    end

    test "lit @airtable" do
      opts = [lit_query_name: :Term, term: ""]
      response = Read.api_lit_read(opts)
      assert is_list(response)
      [h | _] = response
      assert h."Name" == "_"
      assert Map.has_key?(h, :record_id)
    end
  end
end
