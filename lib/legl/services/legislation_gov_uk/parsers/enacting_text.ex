defmodule Legl.Services.LegislationGovUk.Parsers.EnactingText do

  defmodule EnactingTextState do
    defstruct element_acc: "",
              acc: [%{
                enacting_text: nil
              }]
  end

  def sax_event_handler(:startDocument, _state), do: %EnactingTextState{}

  def sax_event_handler({:characters, value}, %EnactingTextState{element_acc: element_acc} = state) do
    %{ state | element_acc: element_acc <> to_string(value) }
  end

  def sax_event_handler({:startElement, _, 'EnactingText', _, _}, state) , do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'EnactingText', _}, state) do
    { _, acc} =
      get_and_update_in(state.acc, [Access.at(0), :enacting_text], &{&1, state.element_acc } )
    Map.merge( state, %{ acc: acc, element_acc: "" } )
  end

  def sax_event_handler(:endDocument, state), do: Map.merge( state, %{element_acc: ""} )

  def sax_event_handler(_, state), do: state

end
