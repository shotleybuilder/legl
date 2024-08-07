defmodule Legl.Countries.Uk.Support.LeglFitnessTransformTest do
  @moduledoc """
  Test data and expected results for LeglFitness.Transform
  """

  @such [
    %{
      rule: "in respect of work equipment shall apply to such equipment ",
      result: "in respect of work equipment shall apply to work equipment "
    },
    %{
      rule:
        "Any requirement or prohibition imposed by these Regulations on a person—\n(a) who designs, manufactures, imports or supplies any pressure system, or any article which is intended to be a component part of any pressure system, shall extend only to such a system or article designed, manufactured, imported or supplied in the course of a trade, business or other undertaking carried on by him (whether for profit or not);\n(b) who designs or manufactures such a system or article shall extend only to matters within his control.",
      result:
        "Any requirement or prohibition imposed by these Regulations on a person—\n(a) who designs, manufactures, imports or supplies any pressure system, or any article which is intended to be a component part of any pressure system, shall extend only to a pressure system, or any article which is intended to be a component part of any pressure system designed, manufactured, imported or supplied in the course of a trade, business or other undertaking carried on by him (whether for profit or not);\n(b) who designs or manufactures a pressure system, or any article which is intended to be a component part of any pressure system shall extend only to matters within his control."
    },
    %{
      rule:
        "a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in",
      result:
        "a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to a workplace which is or is in or on a ship, where the work involves any of the relevant operations in"
    }
  ]

  def such(), do: @such
end
