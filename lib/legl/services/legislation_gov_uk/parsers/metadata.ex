defmodule Legl.Services.LegislationGovUk.Parsers.Metadata do

  @type state() :: %Legl.Services.LegislationGovUk.Parsers.Metadata.SaxState{}

  defmodule SaxState do
    defstruct [
      ele: nil,
      metadata: %{
        md_subjects: [],
        md_description: nil,
        md_total_paras: nil,
        md_body_paras: nil,
        md_schedule_paras: nil,
        md_attachment_paras: nil,
        md_images: nil,
        md_modified: nil
      },
      si_code: false,
      # core control
      # main_section [:metadata, :contents, :prelims, :resources, :schedules, :earlier_orders, :body, :explanatory_notes, :versions :footnotes]
      main_section: nil,
      element_acc: "",
      number: "",
      #body
      acc: [],
      ele_prefix: "",
      class: [],
      id: 0,
      pid_acc: [nil],
      # acronyms
      annotation?: false,
      annotation_acc: [],
      annotation_elem_acc: "",
      # for testing element coverage only
      parsed?: true
    ]
  end

  def state do
    %SaxState{}
  end

  @metadata ~w(
    AffectedProvisions
    AffectedTitle
    AffectingProvisions
    AffectingTitle
    Alternative
    AlternativeNumber
    Alternatives
    AttachmentParagraphs
    BodyParagraphs
    ComingIntoForce
    CommencementAuthority
    DateTime
    DepartmentCode
    DocumentCategory
    DocumentClassification
    DocumentMainType
    DocumentMinorType
    DocumentStatus
    EnactmentDate
    InForce
    InForceDates
    ISBN
    Laid
    Made
    Note
    Notes
    Number
    PrimaryMetadata
    Resolution
    RoyalPresence
    Savings
    ScheduleParagraphs
    SecondaryMetadata
    Section
    SectionRange
    Statistics
    TotalImages
    TotalParagraphs
    UnappliedEffect
    UnappliedEffects
    Year
    )c
  def metadata do
    @metadata
  end

  @dublincore ~w(
    creator
    description
    publisher
    modified
    contributor
    date
    type
    format
    identifier
    source
    language
    relation
    coverage
    rights
  )c
  def dublin_core do
    @dublincore
  end

  # *****************************************************************************
  # START DOCUMENT
  # *****************************************************************************
  def sax_event_handler(:startDocument, _state), do: %SaxState{}
  # *****************************************************************************
  # Content accumulator
  # *****************************************************************************
  def sax_event_handler(
        {:characters, value},
        %SaxState{element_acc: element_acc, annotation_elem_acc: annotation_elem_acc} = state
      ) do
    case state.annotation? do
      true ->
        %{
          state
          | element_acc: IO.iodata_to_binary([element_acc, to_string(value)]),
            annotation_elem_acc: IO.iodata_to_binary([annotation_elem_acc, to_string(value)])
        }

      _ ->
        %{state | element_acc: IO.iodata_to_binary([element_acc, to_string(value)])}
    end
  end
  # *****************************************************************************
  # Catch all calls to sax_event_handler/2
  # *****************************************************************************
  # Print the element being parsed
  # Then call sax_event_handler/3
  # *****************************************************************************
  def sax_event_handler({:startElement, _, element, _, _} = e, state) do
    #if Mix.env == :dev do IO.puts(["Start: ", element]) end
    sax_event_handler(e, state, element)
  end

  def sax_event_handler({:endElement, _, element, _} = e, state) do
    #if Mix.env == :dev do IO.puts(["End: ", element]) end
    sax_event_handler(e, state, element)
  end

  # *******************************************************************************
  # END DOCUMENT
  # *******************************************************************************
  def sax_event_handler(:endDocument, state) do
    subjects = Enum.reverse(state.metadata.md_subjects)
    Map.merge(state, %{
      element_acc: "", metadata: %{state.metadata | md_subjects: subjects}
    })
  end
  # *****************************************************************************
  # COMMON CATCHER RETURNS STATE
  # *****************************************************************************
  # def sax_event_handler( what?, state), do: ( IO.inspect(what?); state ) # %{ state | parsed?: false }
  def sax_event_handler(_, state), do: state
  # ****************************************************************************
  # <metadata>
  # *****************************************************************************
  # ukm:metadata
  def sax_event_handler({:startElement, _, 'Metadata', 'ukm', _}, state, _),
    do: %{state | main_section: :metadata}

  def sax_event_handler({:endElement, _, 'Metadata', 'ukm'}, state, _), do: state

  def sax_event_handler({:startElement, _, 'TotalParagraphs', 'ukm',  [{:attribute, 'Value', [], [], value}]}, state, _),
  do: %{state | metadata: Map.put(state.metadata, :md_total_paras, value)}

  def sax_event_handler({:startElement, _, 'BodyParagraphs', 'ukm',  [{:attribute, 'Value', [], [], value}]}, state, _),
  do: %{state | metadata: Map.put(state.metadata, :md_body_paras, value)}

  def sax_event_handler({:startElement, _, 'ScheduleParagraphs', 'ukm',  [{:attribute, 'Value', [], [], value}]}, state, _),
  do: %{state | metadata: Map.put(state.metadata, :md_schedule_paras, value)}

  def sax_event_handler({:startElement, _, 'AttachmentParagraphs', 'ukm',  [{:attribute, 'Value', [], [], value}]}, state, _),
  do: %{state | metadata: Map.put(state.metadata, :md_attachment_paras, value)}

  def sax_event_handler({:startElement, _, 'TotalImages', 'ukm',  [{:attribute, 'Value', [], [], value}]}, state, _),
  do: %{state | metadata: Map.put(state.metadata, :md_images, value)}

  def sax_event_handler({:startElement, _, metadata, 'ukm', _}, state, _)
      when metadata in @metadata,
      do: state

  def sax_event_handler({:endElement, _, metadata, 'ukm'}, state, _)
      when metadata in @metadata,
      do: state

  # atom:link
  def sax_event_handler(
        {:startElement, _, 'link', 'atom', attr},
        %{main_section: :metadata} = state,
        _
      ) do
    case Enum.find(attr, &match?({_, 'type', _, _, _}, &1)) do
      {_, _, _, _, 'application/pdf'} ->
        case Enum.find(attr, &match?({_, 'href', _, _, _}, &1)) do
          {_, _, _, _, pdf_href} ->
            pdf_href = pdf_href |> to_string()
            metadata = Map.put(state.metadata, :pdf_href, pdf_href)
            %{state | metadata: metadata}

          _ ->
            state
        end

      _ ->
        state
    end
  end

  def sax_event_handler({:endElement, _, 'link', 'atom'}, state, _), do: state

  # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  # DUBLIN CORE
  # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  # dc:title
  #def sax_event_handler({:startElement, _, _, 'dc', _} = v, state, _) do
  #  IO.inspect(v)
  #  %{state | element_acc: ""}
  #end

  def sax_event_handler({:startElement, _, 'title', 'dc', _}, state, _),
    do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'title', 'dc'}, %{main_section: :metadata} = state, _) do
    %{state | metadata: Map.put(state.metadata, :title, state.element_acc), element_acc: ""}
  end

  def sax_event_handler({:startElement, _, 'subject', 'dc', [{:attribute, 'scheme', [], [], 'SIheading'}]}, state, _),
  do: %{state | element_acc: "", si_code: true}

  def sax_event_handler({:startElement, _, 'subject', 'dc', _}, state, _), do: state

  def sax_event_handler({:endElement, _, 'subject', 'dc'}, %{main_section: :metadata} = state, _) do
    case state.si_code do
      true ->
        %{state | metadata: Map.put(state.metadata, :si_code, state.element_acc), element_acc: "", si_code: false}
      false ->
        subject = [String.downcase(state.element_acc) | state.metadata.md_subjects]
        %{state | metadata: Map.put(state.metadata, :md_subjects, subject), element_acc: ""}
    end
  end

  def sax_event_handler({:startElement, _, 'modified', 'dc', _}, state, _),
  do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'modified', 'dc'}, %{main_section: :metadata} = state, _) do
    %{state | metadata: Map.put(state.metadata, :md_modified, state.element_acc), element_acc: ""}
  end

  def sax_event_handler({:startElement, _, 'description', 'dc', _}, state, _),
  do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'description', 'dc'}, %{main_section: :metadata} = state, _) do
    %{state | metadata: Map.put(state.metadata, :md_description, state.element_acc), element_acc: ""}
  end

  # <dc:creator> <dc:subject> <dc:description> <dc:publisher> <dc:contributor> <dc:date>
  def sax_event_handler({:startElement, _, dublin_core, 'dc', _}, state, _)
      when dublin_core in @dublincore,
      do: state

  def sax_event_handler({:endElement, _, dublin_core, 'dc'}, state, _)
      when dublin_core in @dublincore,
      do: state

  # *****************************************************************************
  # COMMON CATCHER RETURNS STATE
  # *****************************************************************************
  def sax_event_handler({:startElement, _, _, _, _}, state, _),
    do: state

  def sax_event_handler({:endElement, _, _, _}, state, _),
    do: state

end
