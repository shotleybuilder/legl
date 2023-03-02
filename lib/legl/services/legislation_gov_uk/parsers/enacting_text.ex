defmodule Legl.Services.LegislationGovUk.Parsers.EnactingText do

  defmodule EnactingTextState do
    defstruct enacting_text: false,
              element_acc: "",
              acc: %{
                enacting_text: nil,
                urls: nil
              },
              footnote_section: false,
              footnote: nil,
              footnotes: %{}
  end

  def sax_event_handler(:startDocument, _state), do: %EnactingTextState{}

  def sax_event_handler({:characters, value}, %EnactingTextState{element_acc: element_acc} = state) do
    %{state | element_acc: element_acc <> to_string(value)}
  end

  def sax_event_handler({:startElement, _, 'EnactingText', _, _}, state) , do: %{state | element_acc: "", enacting_text: true}

  def sax_event_handler({:endElement, _, 'EnactingText', _}, state) do
    #{_, acc} =
      #get_and_update_in(state.acc, [Access.at(0), :enacting_text], &{&1, state.element_acc })
    acc = %{state.acc | enacting_text: state.element_acc}
    Map.merge(state, %{acc: acc, element_acc: "", enacting_text: false})
  end

  def sax_event_handler({:startElement, _, 'FootnoteRef', _, [{:attribute, _id, [], [], ref}] = _attr}, state) do
    footnotes = Map.put_new(state.footnotes, "#{ref}", nil)
    state = %{state | footnotes: footnotes}
    case state.enacting_text do
      true ->
        %{state | element_acc: "#{state.element_acc} #{ref}"}
      _ -> state
    end
  end

  def sax_event_handler({:endElement, _, 'FootnoteRef', _}, state), do: state

  def sax_event_handler({:startElement, _, 'Footnotes', _, _}, state) do
    %{state | footnote_section: true}
  end

  def sax_event_handler({:endElement, _, 'Footnotes', _}, state) do
    %{state | footnote_section: false}
  end

  def sax_event_handler({:startElement, _, 'Footnote', _, [{:attribute, _id, [], [], ref}] = _attr}, state) do
    %{state | footnote: ref}
  end

  def sax_event_handler({:startElement, _, 'Citation', _, attr}, state) do
    case state.footnote_section do
      true ->
        uri =
          Enum.reduce(attr, nil, fn x, acc ->
            case x do
              {:attribute, 'URI', [], [], uri} -> uri
              _ -> acc
            end
          end)
        footnotes = %{state.footnotes | "#{state.footnote}" => uri}
        %{state | footnotes: footnotes}
      _ -> state
    end
  end

  def sax_event_handler(:endDocument, state) do
    acc = %{state.acc | urls: state.footnotes}
    Map.merge(state, %{acc: acc, element_acc: ""})
  end

  def sax_event_handler(_, state), do: state

end
