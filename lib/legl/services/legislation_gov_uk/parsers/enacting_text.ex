defmodule Legl.Services.LegislationGovUk.Parsers.EnactingText do
  defmodule EnactingTextState do
    defstruct introductory_text: false,
              enacting_text: false,
              element_acc: "",
              acc: %{
                enacting_text: "",
                introductory_text: "",
                urls: []
              },
              section: nil,
              footnote: nil,
              footnotes: %{},
              commentary: nil,
              commentaries: %{}
  end

  def sax_event_handler(:startDocument, _state), do: %EnactingTextState{}

  def sax_event_handler(
        {:characters, value},
        %EnactingTextState{element_acc: element_acc} = state
      ) do
    %{state | element_acc: element_acc <> to_string(value)}
  end

  def sax_event_handler({:startElement, _, 'EnactingText', _, _}, state),
    do: %{state | element_acc: "", enacting_text: true}

  def sax_event_handler({:endElement, _, 'EnactingText', _}, state) do
    acc = %{state.acc | enacting_text: state.element_acc}
    Map.merge(state, %{acc: acc, element_acc: "", enacting_text: false})
  end

  def sax_event_handler({:startElement, _, 'IntroductoryText', _, _}, state),
    do: %{state | element_acc: "", introductory_text: true}

  def sax_event_handler({:endElement, _, 'IntroductoryText', _}, state) do
    acc = %{state.acc | introductory_text: state.element_acc}
    Map.merge(state, %{acc: acc, element_acc: "", introductory_text: false})
  end

  def sax_event_handler(
        {:startElement, _, 'FootnoteRef', _, [{:attribute, _id, [], [], id}] = _attr},
        state
      ) do
    footnotes = Map.put_new(state.footnotes, "#{id}", [])
    state = %{state | footnotes: footnotes}

    case state.enacting_text || state.introductory_text do
      true ->
        %{state | element_acc: "#{state.element_acc} #{id}"}

      _ ->
        state
    end
  end

  def sax_event_handler(
        {:startElement, _, 'CommentaryRef', _, [{:attribute, _id, [], [], ref}] = _attr},
        state
      ) do
    commentaries = Map.put_new(state.commentaries, "#{ref}", [])
    state = %{state | commentaries: commentaries}

    case state.enacting_text || state.introductory_text do
      true ->
        %{state | element_acc: "#{state.element_acc} [start_ref]#{ref}[end_ref]"}

      _ ->
        state
    end
  end

  def sax_event_handler({:endElement, _, 'FootnoteRef', _}, state), do: state

  def sax_event_handler({:startElement, _, 'Footnotes', _, _}, state) do
    %{state | section: :fn}
  end

  def sax_event_handler({:endElement, _, 'Footnotes', _}, state) do
    %{state | section: nil}
  end

  def sax_event_handler(
        {:startElement, _, 'Footnote', _, attr},
        state
      ) do
    id =
      Enum.reduce(attr, "", fn
        {:attribute, 'Type', [], [], _}, acc -> acc
        {:attribute, 'id', [], [], id}, acc -> acc <> to_string(id)
        _, acc -> acc
      end)

    %{state | footnote: id}
  end

  # COMMENTARIES

  def sax_event_handler({:startElement, _, 'Commentaries', _, _}, state),
    do: %{state | section: :cmt}

  def sax_event_handler({:endElement, _, 'Commentaries', _}, state),
    do: %{state | section: nil}

  def sax_event_handler(
        {:startElement, _, 'Commentary', _, attr},
        state
      ) do
    id =
      Enum.reduce(attr, "", fn
        {:attribute, 'Type', [], [], _}, acc -> acc
        {:attribute, 'id', [], [], id}, acc -> acc <> to_string(id)
        _, acc -> acc
      end)

    %{state | commentary: id}
  end

  # CITATIONS

  def sax_event_handler({:startElement, _, 'Citation', _, attr}, state) do
    case state.section do
      :fn ->
        uri =
          Enum.reduce(attr, nil, fn x, acc ->
            case x do
              {:attribute, 'URI', [], [], uri} -> to_string(uri)
              _ -> acc
            end
          end)

        footnote = [uri | Map.get(state.footnotes, "#{state.footnote}")]
        footnotes = Map.put(state.footnotes, "#{state.footnote}", footnote)
        %{state | footnotes: footnotes}

      :cmt ->
        uri =
          Enum.reduce(attr, nil, fn x, acc ->
            case x do
              {:attribute, 'URI', [], [], uri} -> to_string(uri)
              _ -> acc
            end
          end)

        # Push the uri into the list in the commentaries map
        commentary = Map.get(state.commentaries, "#{state.commentary}") ++ [uri]
        # Put the list into the commentaries map
        commentaries = Map.put(state.commentaries, "#{state.commentary}", commentary)
        %{state | commentaries: commentaries}

      _ ->
        state
    end
  end

  def sax_event_handler(:endDocument, state) do
    urls = Map.merge(state.footnotes, state.commentaries)
    acc = %{state.acc | urls: urls}
    Map.merge(state, %{acc: acc, element_acc: ""})
  end

  def sax_event_handler(_, state), do: state
end
