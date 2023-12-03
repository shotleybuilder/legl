defmodule Legl.Countries.Uk.LeglRegister.IdFieldTest do
  # mix test test/legl/countries/uk/legl_register/id_field_test.exs

  use ExUnit.Case
  import Legl.Countries.Uk.LeglRegister.IdField

  @title "Environmental Protection (Controls on Ozone–Depleting Substances) (Amendment) Regulations"

  test "w/ title" do
    with(
      title = Legl.Airtable.AirtableTitleField.remove_the(@title),
      downcased = downcase(title),
      split = split_title(downcased),
      proper = proper_title(split),
      acronym = acronym(proper)
    ) do
      assert downcased ==
               "Environmental Protection (Controls on Ozone–Depleting Substances) (Amendment) Regulations"

      assert split ==
               "Environmental, Protection, Controls, Ozone, Depleting, Substances, Amendment, Regulations"

      assert proper ==
               "Environmental, Protection, Controls, Ozone, Depleting, Substances, Amendment, Regulations"

      assert acronym == "EPCODSAR"
    end
  end

  test "id/4" do
    title =
      "Wildlife and Natural Environment (Scotland) Act 2011 (Commencement No. 2) Amendment (No. 2) Order"

    result = id(title, "ssi", 2012, "281")
    assert result == ""
  end
end
