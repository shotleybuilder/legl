defmodule UK.Act do
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
    :text,
    :region
  ]
  @number_fields [
    :part,
    :chapter,
    :heading,
    :section,
    :sub_section,
    :para,
    :sub_para
  ]

  defstruct @fields

  @doc """
    %UK.Act{
      flow: "",
      type: "",
      part: "",
      chapter: "",
      heading: "",
      section: "",
      sub_section: "",
      article: "",
      para: "",
      text: "",
      region: ""
    }
  """
  def act, do:
    struct(__MODULE__, Enum.into(@fields, %{}, fn k -> {k, ""} end))

  def fields(), do: @fields
  def number_fields(), do: @number_fields
end
