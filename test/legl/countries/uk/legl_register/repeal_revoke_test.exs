# mix test test/legl/countries/uk/legl_register/repeal_revoke_test.exs:8
defmodule Legl.Countries.Uk.LeglRegister.RepealRevokeTest do
  use ExUnit.Case

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke

  describe "Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke" do
    test "single_records/1" do
      opts = [
        base_name: "UK S",
        workflow: :update,
        name: "UK_uksi_2023_1164_DDDTEWO",
        view: "VS_CODE_REPEALED_REVOKED",
        patch?: false
      ]

      result = RepealRevoke.single_record(opts)
      assert :ok = result
    end

    test "single_record/1 - not in force" do
      opts = [
        base_name: "UK S",
        workflow: :update,
        name: "UK_uksi_2023_764_CPRCSR",
        view: "VS_CODE_REPEALED_REVOKED",
        patch?: false
      ]

      result = RepealRevoke.single_record(opts)
      assert :ok = result
    end
  end
end
