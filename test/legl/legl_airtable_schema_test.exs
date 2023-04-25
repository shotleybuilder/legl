defmodule Legl.Airtable.Schema.Test do

  # mix test test/legl/legl_airtable_schema_test.exs:25

  use ExUnit.Case

  @moduletag timeout: 5000

  import Legl.Airtable.Schema

  @record %{
    part: "1",
    chapter: "",
    heading: "1",
    section: "1",
    sub_section: "",
    para: ""
  }
  describe "add_id_and_name_to_record/2" do
    test "pre" do
      name = "test"
      record = Map.put(@record, :flow, "pre")
      new_record = add_id_and_name_to_record(name, record)
      assert "test1__1_1" == new_record.id
      assert "test" == new_record.name
    end
  end

  describe "make_id/1" do
    test "flow: pre" do
      record = Map.merge(@record, %{flow: "pre", name: "test"})
      id = make_id(record)
      assert "test1__1_1" == id
    end
  end
end
