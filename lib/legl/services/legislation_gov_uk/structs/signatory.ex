defmodule Signatory do
  defstruct(
    children: [],
    class: "",
    id: nil,
    parent_id: nil,
    resource: %{}, # %{resource_id: "uri"}
    signee: %Signee{},
    text: []
  )
end
