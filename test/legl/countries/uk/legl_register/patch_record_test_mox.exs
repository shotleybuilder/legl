defmodule PatchRecordTestMox do
  # mix test test/legl/countries/uk/legl_register/patch_record_test_mox.exs
  use ExUnit.Case
  import Mox
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.PatchRecord, as: Patch

  setup :verify_on_exit!

  @name "UK_uksi_2000_1"
  @opts %{supabase_table: "uk_lrt"}

  describe "supabase_patch_record/2" do
    test "returns the correct URL" do
      SupabaseHttpClientBehaviourMock
      |> expect(:update_legal_register_record, fn _, _ ->
        {:ok, %{status: 200, body: "UK_uksi_2000_1"}}
      end)

      result = Patch.supabase_patch_record(%LegalRegister{}, @opts)
      assert result == {:ok, %{status: 200, body: "UK_uksi_2000_1"}}
    end
  end
end
