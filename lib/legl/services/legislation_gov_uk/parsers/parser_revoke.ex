defmodule Legl.Services.LegislationGovUk.Parsers.ParserRevoke do

  @moduledoc """

    Parses the <Legislation> tag of the resource view at legislation.gov.uk
    URLs such as:
      https://www.legislation.gov.uk/ukpga/2023/1/resources/data.xml

    Tag shape for a primary piece of law:
      <Legislation
        DocumentURI="http://www.legislation.gov.uk/ukpga/1964/40"
        IdURI="http://www.legislation.gov.uk/id/ukpga/1964/40"
        NumberOfProvisions="153"
        xsi:schemaLocation="http://www.legislation.gov.uk/namespaces/legislation http://www.legislation.gov.uk/schema/legislation.xsd"
        SchemaVersion="1.0"
        RestrictExtent="E+W+S"
        RestrictStartDate="2021-02-17">

      <dc:title>Harbours Act 1964</dc:title>

      <dct:valid>2021-02-17</dct:valid>

    The attribute of the Legislation has this shape:
      [
        {:attribute, 'RestrictStartDate', [], [], '2021-02-17'},
        {:attribute, 'RestrictExtent', [], [], 'E+W+S'},
        {:attribute, 'SchemaVersion', [], [], '1.0'},
        {:attribute, 'schemaLocation', 'xsi',
        'http://www.w3.org/2001/XMLSchema-instance',
        'http://www.legislation.gov.uk/namespaces/legislation http://www.legislation.gov.uk/schema/legislation.xsd'},
        {:attribute, 'NumberOfProvisions', [], [], '153'},
        {:attribute, 'IdURI', [], [],
        'http://www.legislation.gov.uk/id/ukpga/1964/40'},
        {:attribute, 'DocumentURI', [], [],
        'http://www.legislation.gov.uk/ukpga/1964/40'}
      ]

    The two tag elements we're interested in are RestrictStartDate and RestrictExtent

    Shape of the returned data:
      [
        %{
          title: title,
          revoked: true||false,
          restrict_start_date: date,
          dct_valid: date
        }
      ]
  """

  defmodule RevokeState do
    defstruct acc: %{
                      title: nil,
                      revoked: false,
                      restrict_extent: nil,
                      restrict_start_date: nil,
                      dct_valid: nil
                    },
              element_acc: ""
  end

  def sax_event_handler(:startDocument, _state), do: %RevokeState{}

  def sax_event_handler(:endDocument, state) do
    state
  end

  def sax_event_handler({:characters, value}, %RevokeState{element_acc: element_acc} = state) do
    %{state | element_acc: element_acc <> to_string(value)}
  end

  def sax_event_handler({:startElement, _, 'Legislation', _, attr}, state) do
    acc =
      Enum.reduce(attr, state.acc, fn x, acc ->
        case x do
          {_, 'RestrictExtent', _, _, extent} ->
            Map.put(acc, :restrict_extent, String.replace(to_string(extent), ".", ""))
          {_, 'RestrictStartDate', _, _, date} ->
            date = Legl.Utility.yyyy_mm_dd(to_string(date))
            Map.put(acc, :restrict_start_date, date)
          _ ->
            acc
        end
      end)
    %{state | acc: acc}
  end

  def sax_event_handler({:startElement, _, 'title', 'dc', _}, state),
  do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'title', 'dc'}, state) do
    pattern = ~w/REVOKED Revoked revoked REPEALED Repealed repealed/
    revoked? = String.contains?(state.element_acc, pattern)
    acc = Map.merge(state.acc, %{revoked: revoked?, title: state.element_acc})
    %{state | acc: acc, element_acc: ""}
  end

  def sax_event_handler({:startElement, _, 'valid', 'dct', _}, state),
  do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'valid', 'dct'}, state) do
    date = Legl.Utility.yyyy_mm_dd(state.element_acc)
    %{state | acc: Map.put(state.acc, :dct_valid, date), element_acc: ""}
  end

  # *****************************************************************************
  # COMMON CATCHER RETURNS STATE
  # *****************************************************************************
  def sax_event_handler({:startElement, _, _, _, _}, state),
    do: state

  def sax_event_handler({:endElement, _, _, _}, state),
    do: state

  def sax_event_handler(_, state), do: state
end
