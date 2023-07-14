defmodule Legl.Countries.Uk.UkTypeCode do
  defstruct ukpga: "ukpga",
            uksi: "uksi",
            nia: "nia",
            apni: "apni",
            nisi: "nisi",
            nisr: "nisr",
            nisro: "nisro",
            asp: "asp",
            ssi: "ssi",
            asc: "asc",
            anaw: "anaw",
            mwa: "mwa",
            wsi: "wsi",
            ni: ["nia", "apni", "nisi", "nisr", "nisro"],
            s: ["asp", "ssi"],
            uk: ["ukpga", "uksi"],
            w: ["asc", "anaw", "mwa", "wsi"],
            o: ["ukcm", "ukla", "asc", "ukmo", "apgb", "aep"]
end

defmodule Legl.Countries.Uk.UkTypeClass do
  defstruct act: "Act",
            regulation: "Regulations",
            order: "Order",
            rule: "Rules",
            byelaw: "Byelaws"
end
