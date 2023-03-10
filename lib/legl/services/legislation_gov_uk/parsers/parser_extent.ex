defmodule Legl.Services.LegislationGovUk.Parsers.ParserExtent do

  @moduledoc """

    Parses teh <ContentItem> tags of the content views at legislation.gov.uk
    URLs such as:
      https://www.legislation.gov.uk/ukpga/2023/1/contents/data.xml

    Tag shape for a primary piece of law:
      <ContentsItem
        ContentRef="section-1"
        IdURI="http://www.legislation.gov.uk/id/ukpga/2023/1/section/1"
        DocumentURI="http://www.legislation.gov.uk/ukpga/2023/1/section/1"
        RestrictExtent="E+W+S+N.I.">

    The attribute of the ContentsItem has this shape:
      [
        {:attribute, 'RestrictExtent', [], [], 'E+W+S+N.I.'},
        {:attribute, 'DocumentURI', [], [],
          'http://www.legislation.gov.uk/ukpga/2023/1/section/12'},
        {:attribute, 'IdURI', [], [],
          'http://www.legislation.gov.uk/id/ukpga/2023/1/section/12'},
        {:attribute, 'ContentRef', [], [], 'section-12'}
      ]

    The two tag elements we're interested in are ContentRef and RestrictExtent

    Shape of the returned data:
      [
        {"section-1", "E+W+S+NI"},
        {"section-2", "E+W+S+NI"},
        {"section-3", "E+W+S+NI"},
        {"section-4", "E+W+S"},
        {"section-5", "NI"},
        {"section-6", "E+W"},
        {"section-7", "E+W"}
      ]
  """

  defmodule ExtentState do
    defstruct acc: %{extents: nil},
              extents: []
  end

  def sax_event_handler(:startDocument, _state), do: %ExtentState{}

  #def sax_event_handler({:characters, value}, %ExtentState{element_acc: element_acc} = state) do
  #  %{state | element_acc: element_acc <> to_string(value)}
  #end

  def sax_event_handler({:startElement, _, 'ContentsItem', _, attr}, state) do
    extents =
      Enum.reduce(attr, {}, fn x, acc ->
        case x do
          {_, 'RestrictExtent', _, _, extent} ->
            {String.replace(to_string(extent), ".", "")}
          {_, 'ContentRef', _, _, ref} ->
            Tuple.insert_at(acc, 0,to_string(ref))
          _ -> acc
        end
      end)
    %{state | extents: [extents | state.extents]}
  end


  def sax_event_handler(:endDocument, state) do
    acc = %{state.acc | extents: Enum.reverse(state.extents)}
    Map.merge(state, %{acc: acc})
  end

  def sax_event_handler(_, state), do: state

end
