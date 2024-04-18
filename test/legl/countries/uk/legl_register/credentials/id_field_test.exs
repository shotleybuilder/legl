defmodule Legl.Countries.Uk.LeglRegister.Credentials.IdFieldTest do
  alias Legl.Countries.Uk.LeglRegister
  # mix test test/legl/countries/uk/legl_register/credentials/id_field_test.exs

  use ExUnit.Case
  import Legl.Countries.Uk.LeglRegister.IdField

  @titles [
    {"Health and Safety at Work etc. Act", 1974, "uksi", "37", "UK_uksi_1974_37"},
    {"Environmental Protection (Controls on Ozone–Depleting Substances) (Amendment) Regulations",
     2008, "uksi", "91", "UK_uksi_2008_91"},
    {"Wildlife and Natural Environment (Scotland) Act 2011 (Commencement No. 2) Amendment (No. 2) Order",
     2012, "ssi", "281", "UK_ssi_2012_281"},
    {"Fishing Vessels (Safety of 15–24 Metre Vessels) Regulations", 2002, "uksi", 2201,
     "UK_uksi_2002_2201"},
    {"Merchant Shipping (Passenger Ship Construction: Ships of Classes I, II and II(A)) Regulations",
     1998, "uksi", "2514", "UK_uksi_1998_2514"}
  ]

  test "id/4" do
    Enum.each(
      @titles,
      fn {t, y, tc, n, result} ->
        assert id(t, tc, y, n) == result
      end
    )
  end

  test "id/1" do
    record =
      %LeglRegister.LegalRegister{}
      |> Kernel.struct(%{Title_EN: "Foo Bar", type_code: "uksi", Year: "2023", Number: "100"})

    {:ok, result} = id(record)

    assert result."Name" == "UK_uksi_2023_100"
  end
end
