defmodule Legl.Countries.Uk.LeglRegister.Metadata.Options do
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO

  @default_opts %{
    type_code: nil,
    type_class: nil,
    base_name: nil,
    table: "UK",
    # source of Airtable records
    at_source: :web,
    # source of legislation-gov-uk records
    leg_gov_uk_source: :web,
    workflow: nil,
    family: nil,
    filesave?: true,
    csv?: true,
    patch?: true,
    patch_as_you_go?: false
  }

  @get_fields ~w[
    type_code
    Number
    Year
    md_checked
    md_description
    md_subjects
    md_modified
    md_total_paras
    md_body_paras
    md_schedule_paras
    md_attachment_paras
    md_images
    md_error_code
    md_change_log
    record_id
  ]

  def set_options(opts) do
    Enum.into(opts, @default_opts)
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> LRO.type_code()
    |> LRO.type_class()
    |> LRO.family()
    |> LRO.today()
    |> LRO.view()
    |> LRO.at_source()
    |> LRO.leg_gov_uk_source()
    |> fields()
    |> formula()
    |> IO.inspect(label: "\nOptions: ")
  end

  defp fields(%{at_source: :web, workflow: :update} = opts) do
    Map.merge(opts, %{
      fields: ["Title_EN", "leg.gov.uk intro text"] ++ @get_fields
    })
  end

  defp fields(%{at_source: :web} = opts) do
    Map.merge(opts, %{
      fields: ["Name", "Title_EN", "leg.gov.uk intro text"]
    })
  end

  defp fields(opts), do: opts

  defp formula(%{at_source: :web, workflow: :update} = opts) do
    f =
      LRO.formula_today(opts, "md_checked")
      |> LRO.formula_type_code(opts)
      |> LRO.formula_type_class(opts)
      |> LRO.formula_family(opts)

    Map.put(
      opts,
      :formula,
      ~s/AND(#{Enum.join(f, ",")})/
    )
  end

  defp formula(%{at_source: :web} = opts) do
    Map.merge(opts, %{formula: ~s/AND({type_code}="#{opts.type_code}", {md_modified}=BLANK())/})
  end

  defp formula(opts), do: opts
end
