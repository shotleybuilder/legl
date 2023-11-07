defmodule Legl.Countries.Uk.LeglRegister.Models do
  @moduledoc """

  """
  @typeclass ~w[Act Regulation Order Rules Byelaws Measure]

  def type_class, do: @typeclass

  @hsfamily [
    "FIRE",
    "FIRE: Dangerous and Explosive Substances",
    "FOOD",
    "GAS & ELECTRIC",
    "HEALTH: Drug & Medicine Safety",
    "HEALTH: Patient Safety",
    "HEALTH: Public",
    "HR: Employment",
    "HR: Insurance / Compensation / Wages / Benefits",
    "HR: Working Time",
    "OH&S: Mines & Quarries",
    "OH&S: Occupational / Personal Safety",
    "OH&S: Offshore Safety",
    "PUBLIC",
    "PUBLIC: Building Safety",
    "PUBLIC: Consumer / Product Safety",
    "TRANS: Air Safety",
    "TRANS: Rail Safety",
    "TRANS: Road Safety",
    "TRANS: Ship Safety"
  ]

  def hs_family, do: @hsfamily

  @efamily [
    "Climate Change",
    "Energy",
    "Environmental Protection",
    "Finance",
    "Marine & Riverine",
    "Planning",
    "Pollution",
    "Waste",
    "Water & Wastewater",
    "Wildlife & Countryside"
  ]

  def e_family, do: @efamily
end
