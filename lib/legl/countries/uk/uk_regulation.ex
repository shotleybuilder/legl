defmodule UK.Regulation do
  @fields [
    :id,
    :name,
    :flow,
    :type,
    :part,
    :chapter,
    :heading,
    :section,
    :sub_section,
    :para,
    :sub_para,
    :amendment,
    :changes,
    :region,
    :max_amendments,
    :max_modifications,
    :max_commencements,
    :max_extents,
    :max_editorials,
    :heading?,
    :table_counter,
    :text
  ]
  @number_fields [
    :part,
    :chapter,
    :heading,
    :section,
    :sub_section,
    :para,
    :sub_para,
    :amendment
  ]

  defstruct @fields

  @doc """
    %UK.Regulation{
      flow: "",
      type: "",
      part: "",
      chapter: "",
      section: "",
      sub_section: "",
      article: "",
      para: "",
      sub_para: "",
      amendment: "",
      text: "",
      region: ""
    }
  """
  def regulation, do: struct(__MODULE__, Enum.into(@fields, %{}, fn k -> {k, ""} end))

  def fields(), do: @fields

  def number_fields(), do: @number_fields
end
