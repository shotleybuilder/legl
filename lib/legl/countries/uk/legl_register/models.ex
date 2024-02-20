defmodule Legl.Countries.Uk.LeglRegister.Models do
  @moduledoc """

  """
  @typeclass ~w[Act Regulation Order Rules Byelaws Measure Scheme]

  def type_class, do: @typeclass

  @hs_family [
    "💙 FIRE",
    "💙 FIRE: Dangerous and Explosive Substances",
    "💙 FOOD",
    "💙 HEALTH: Coronavirus",
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

  @hs_bases [
    # "💙 FIRE",
    "app0bGzy4uDbKrCF5",
    # "💙 FIRE: Dangerous and Explosive Substances",
    "appqDhGjs1G7oVHrW",
    # "💙 FOOD",
    "",
    # "💙 HEALTH: Drug & Medicine Safety",
    "",
    # "💙 HEALTH: Patient Safety",
    "",
    # "💙 HEALTH: Public",
    "",
    # "💙 HR: Employment",
    "",
    # "💙 HR: Insurance / Compensation / Wages / Benefits",
    "",
    # "💙 HR: Working Time",
    "",
    # "💙 OH&S: Gas & Electrical Safety",
    "appJu2qnECHmo9cln",
    # "💙 OH&S: Mines & Quarries",
    "appuoNQFKM2SUI3lK",
    # "💙 OH&S: Occupational / Personal Safety",
    "appiwDnCNQaZOSaVR",
    # "💙 OH&S: Offshore Safety",
    "appDoxScBrdBhxnOb",
    # "💙 PUBLIC",
    "",
    # "💙 PUBLIC: Building Safety",
    "",
    # "💙 PUBLIC: Consumer / Product Safety",
    "appnTQBGljRQgVUhU",
    # "💙 TRANS: Air Safety",
    "",
    # "💙 TRANS: Rail Safety",
    "",
    # "💙 TRANS: Road Safety",
    "",
    # "💙 TRANS: Maritime Safety"
    ""
  ]

  def hs_family, do: @hs_family

  def hs_bases, do: Enum.zip(@hs_family, @hs_bases)

  @e_family [
    "💚 AGRICULTURE",
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
    "💚 Planning & Infrastructure",
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

  @e_bases [
    # "💚 AGRICULTURE",
    "",
    # "💚 Air Quality",
    "",
    # "💚 Animals & Animal Health",
    "",
    # "💚 Antarctica",
    "",
    # "💚 Aviation",
    "",
    # "💚 Buildings",
    "",
    # "💚 Climate Change",
    "appGv6qmDJK2Kdr3U",
    # "💚 Energy",
    "app4L95N2NbK7x4M0",
    # "💚 Environmental Protection",
    "appPFUz8wfo9RU7gN",
    # "💚 Finance",
    "appokFoa6ERUUAIkF",
    # "💚 Fisheries & Fishing",
    "",
    # "💚 GMOs",
    "",
    # "💚 Historic Environment",
    "",
    # "💚 Marine & Riverine",
    "appLXqkeiiqrOXwWw",
    # "💚 Merchant Shipping",
    "",
    # "💚 Noise",
    "",
    # "💚 Planning & Infrastructure",
    "appJ3UVvRHEGIpNi4",
    # "💚 Plant Health",
    "",
    # "💚 Pollution",
    "appj4oaimWQfwtUri",
    # "💚 Nuclear & Radiological",
    "appozWdOMaGdp77eL",
    # "💚 Railways & Rail Transport",
    "",
    # "💚 Roads & Vehicles",
    "",
    # "💚 Town & Country Planning",
    "",
    # "💚 Trees, Forestry & Timber",
    "",
    # "💚 Waste",
    "appfXbCYZmxSFQ6uY",
    # "💚 Water & Wastewater",
    "appCZkMT3VlCLtBjy",
    # "💚 Wildlife & Countryside"
    "appXXwjSS8KgDySB6"
  ]

  def e_family, do: @e_family

  def e_bases, do: Enum.zip(@e_family, @e_bases)

  def ehs_family, do: @hs_family ++ @e_family
end
