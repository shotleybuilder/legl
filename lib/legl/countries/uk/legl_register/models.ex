defmodule Legl.Countries.Uk.LeglRegister.Models do
  @moduledoc """

  """
  @typeclass ~w[Act Regulation Order Rules Byelaws Measure Scheme]

  def type_class, do: @typeclass

  @hsfamily [
    "💙 FIRE",
    "💙 FIRE: Dangerous and Explosive Substances",
    "💙 FOOD",
    "💙 HEALTH: Drug & Medicine Safety",
    "💙 HEALTH: Patient Safety",
    "💙 HEALTH: Public",
    "💙 HR: Employment",
    "💙 HR: Insurance / Compensation / Wages / Benefits",
    "💙 HR: Working Time",
    "💙 OH&S: Gas & Electrical Safety",
    "💙 OH&S: Mines & Quarries",
    "💙 OH&S: Occupational / Personal Safety",
    "💙 OH&S: Offshore Safety",
    "💙 PUBLIC",
    "💙 PUBLIC: Building Safety",
    "💙 PUBLIC: Consumer / Product Safety",
    "💙 TRANS: Air Safety",
    "💙 TRANS: Rail Safety",
    "💙 TRANS: Road Safety",
    "💙 TRANS: Maritime Safety"
  ]

  def hs_family, do: @hsfamily

  @efamily [
    "💚 Agriculture",
    "💚 Air Quality",
    "💚 Animals & Animal Health",
    "💚 Antarctica",
    "💚 Aviation",
    "💚 Buildings",
    "💚 Climate Change",
    "💚 Energy",
    "💚 Environmental Protection",
    "💚 Finance",
    "💚 Fisheries & Fishing",
    "💚 GMOs",
    "💚 Historic Environment",
    "💚 Marine & Riverine",
    "💚 Merchant Shipping",
    "💚 Noise",
    "💚 Planning",
    "💚 Plant Health",
    "💚 Pollution",
    "💚 Nuclear & Radiological",
    "💚 Railways & Rail Transport",
    "💚 Roads & Vehicles",
    "💚 Town & Country Planning",
    "💚 Trees, Forestry & Timber",
    "💚 Waste",
    "💚 Water & Wastewater",
    "💚 Wildlife & Countryside"
  ]

  def e_family, do: @efamily

  def ehs_family, do: @hsfamily ++ @efamily
end
