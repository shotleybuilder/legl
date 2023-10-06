defmodule MetadataTest do
  # mix test test/legl/countries/uk/legl_register/metadata_test.exs
  # mix test test/legl/countries/uk/legl_register/metadata_test.exs:11
  use ExUnit.Case
  import Legl.Countries.Uk.Metadata.Delta

  @moduletag :uk

  # new records may not have had metadata added
  @new %{md_change_log: "", md_subjects: []}

  @base %{
    Description: "foobar",
    md_description: "foobar",
    md_total_paras: 90,
    md_body_paras: 50,
    md_schedule_paras: 30,
    md_attachment_paras: 10,
    md_images: 0,
    md_modified: "2022-10-03",
    si_code: "FOOBAR",
    md_change_log: ""
  }

  @wo_subjects %{
    md_subjects: [],
    md_modified_csv: "03/10/2022"
  }

  @w_subjects %{
    md_subjects: ["foo", "bar"],
    md_modified_csv: "03/10/2022"
  }

  @src_wo_sub Map.merge(@base, @wo_subjects)
  @src_w_sub Map.merge(@base, @w_subjects)

  @latest %{
    md_description: "foobar, foobar",
    md_modified: "2023-10-03",
    md_total_paras: 100,
    md_body_paras: 60,
    md_schedule_paras: 30,
    md_attachment_paras: 10,
    md_images: 0,
    si_code: "FOOBAR"
  }

  @latest_wo_subjects Map.put(@latest, :md_subjects, [])
  @latest_w_subjects Map.put(@latest, :md_subjects, ["foo", "bar", "baz"])

  describe "compare_fields/2" do
    test "new" do
      result = compare_fields(@new, @new)
      assert result == ""
    end

    test "new w/ subjects" do
      result = compare_fields(@new, @latest_w_subjects)
      assert result == ""
    end

    test "matching w/o subject" do
      result = compare_fields(@src_wo_sub, @src_wo_sub)
      assert result == ""
    end

    test "matching w/ subject" do
      result = compare_fields(@src_w_sub, @src_w_sub)

      assert result == ""
    end

    test "not matching w/o subjects" do
      result = compare_fields(@src_wo_sub, @latest_wo_subjects)

      assert result ==
               "\"4/10/2023\nmd_body_paras:       50 -> 60\nmd_total_paras:      90 -> 100\nmd_modified:         2022-10-03 -> 2023-10-03\nmd_description:         foobar -> foobar, foobar\""
    end

    test "not matching w/ subjects" do
      result = compare_fields(@src_w_sub, @latest_w_subjects)

      assert result ==
               "\"4/10/2023\nmd_body_paras:       50 -> 60\nmd_total_paras:      90 -> 100\nmd_modified:         2022-10-03 -> 2023-10-03\nmd_subjects:         foo, bar -> foo, bar, baz\nmd_description:         foobar -> foobar, foobar\""
    end
  end
end
