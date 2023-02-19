# mix test test/legl/countries/uk/si_code_test.exs
# mix test test/legl/countries/uk/si_code_test.exs:11

defmodule Lgl.Countries.Uk.SiCodeTest do

  use ExUnit.Case
  import Legl.Countries.Uk.SiCode

  @moduletag :uk

  describe "get_at_records_with_empty_si_code/1" do
    test "uk" do
      response = get_at_records_with_empty_si_code("UK E")
      assert {:ok, {json, records}} = response
      IO.inspect(records)
      IO.inspect(Enum.count(records))
    end
  end
end
