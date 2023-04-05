defmodule UK.Regulation do
  @fields [
    :flow,
    :type,
    :part,
    :chapter,
    :section,
    :sub_section,
    :article,
    :para,
    :sub,
    :text
  ]
  @number_fields [
    :part,
    :chapter,
    :section,
    :sub_section,
    :article,
    :para,
    :sub
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
      sub: "",
      text: ""
    }
  """
  def regulation, do:
    struct(__MODULE__, Enum.into(@fields, %{}, fn k -> {k, ""} end))

  def fields(), do: @fields

  def number_fields(), do: @number_fields
end
