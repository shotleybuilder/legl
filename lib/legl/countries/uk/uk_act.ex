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
    :amendment,
    :text,
    :region,
    :max_amendments,
    :max_modifications,
    :max_commencements,
    :max_enactments,
    :changes
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
    Creates the UK.Act struct with the structure given by @fields
  """
  def act, do:
    struct(__MODULE__, Enum.into(@fields, %{},
      fn
        :max_amendments -> {:max_amendments, 0}
        :max_modifications -> {:max_modifications, 0}
        :max_commencements -> {:max_commencements, 0}
        :max_enactments -> {:max_enactments, 0}
        :changes -> {:changes, []}
        k -> {k, ""}
      end)
    )

  def fields(), do: @fields
  def number_fields(), do: @number_fields
end
