defmodule Legl.Services.Airtable.AtFormulas do
  @doc """

  """
  def hseplan_formula(%{sector: "on", schema: schema}) do
    ~s[FIND("#{schema}",{on_sch.md})>0]
  end
  def hseplan_formula(%{sector: "on", hse_processes: processes}) do
    process_filter =
      Enum.join(Enum.map(processes, fn process -> ~s[FIND("#{process}",{HSE Process Model})>0] end),",")
    schema = hd(HSEPlan.SectorSchema.sector_schema())
    ~s[OR(#{process_filter},FIND("#{schema}",{on_sch.md})>0)]
  end
  def hseplan_formula(%{sector: "off", hse_processes: processes}) do
    process_filter =
      Enum.join(Enum.map(processes, fn process -> ~s[FIND("#{process}",{HSE Process Model})>0] end),",")
    core_records_filter =
      Enum.join(
        Enum.map(@core_records, fn record ->
          ~s[FIND("#{record}",{record_id.md})>0]
        end),
        ","
      )
    ~s[OR(#{process_filter},#{core_records_filter})]
  end
end
