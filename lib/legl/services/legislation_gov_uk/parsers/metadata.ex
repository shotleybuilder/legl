defmodule Legl.Services.LegislationGovUk.Parsers.Metadata do
  @type state() :: %Legl.Services.LegislationGovUk.Parsers.Metadata.SaxState{}

  defmodule SaxState do
    defstruct ele: nil,
              metadata: %{
                md_subjects: [],
                md_description: nil,
                md_total_paras: nil,
                md_body_paras: nil,
                md_schedule_paras: nil,
                md_attachment_paras: nil,
                md_images: nil,
                md_enactment_date: nil,
                md_coming_into_force_date: nil,
                md_dct_valid_date: nil,
                md_restrict_start_date: nil,
                md_restrict_extent: nil,
                md_modified: nil,
                si_code: "",
                Title_EN: "",
                pdf_href: ""
              },
              si_code: false,
              # core control
              # main_section [:metadata, :contents, :prelims, :resources, :schedules, :earlier_orders, :body, :explanatory_notes, :versions :footnotes]
              main_section: nil,
              element_acc: "",
              number: "",
              # body
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
    # IO.puts(["Start: ", element])
    sax_event_handler(e, state, element)
  end

  def sax_event_handler({:endElement, _, element, _} = e, state) do
    # if Mix.env == :dev do IO.puts(["End: ", element]) end
    sax_event_handler(e, state, element)
  end

  # *******************************************************************************
  # END DOCUMENT
  # *******************************************************************************
  def sax_event_handler(:endDocument, state) do
    subjects = Enum.reverse(state.metadata.md_subjects)

    Map.merge(state, %{
      element_acc: "",
      metadata: %{state.metadata | md_subjects: subjects}
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

  # Legislation tag <Legislation
  # DocumentURI="http://www.legislation.gov.uk/ukpga/2022/44"
  # IdURI="http://www.legislation.gov.uk/id/ukpga/2022/44"
  # NumberOfProvisions="94"
  # xsi:schemaLocation="http://www.legislation.gov.uk/namespaces/legislation
  # http://www.legislation.gov.uk/schema/legislation.xsd" SchemaVersion="1.0"
  # RestrictExtent="E+W+S+N.I." RestrictStartDate="2022-12-25">
  def sax_event_handler(
        {:startElement, _, 'Legislation', _, attributes},
        state,
        _
      ) do
    md =
      Enum.reduce(attributes, state.metadata, fn a, acc ->
        case get_attribute(a) do
          nil -> acc
          {k, v} -> Map.put(acc, k, v)
        end
      end)

    Map.put(state, :metadata, md)
  end

  def sax_event_handler(
        {:startElement, _, 'DateText', _, _},
        state,
        _
      ),
      do: %{state | element_acc: ""}

  # <MadeDate>
  # <Text>Made</Text>
  # <DateText>at 3.32 p.m. on 10th September 2020</DateText>
  # </MadeDate>

  def sax_event_handler(
        {:startElement, _, 'MadeDate', _, _},
        state,
        _
      ),
      do: %{
        state
        | metadata: Map.merge(state.metadata, %{md_made_date: true, element_acc: ""})
      }

  def sax_event_handler(
        {:endElement, _, 'DateText', _},
        %SaxState{metadata: %{md_made_date: true}} = state,
        _
      ),
      do: %{
        state
        | metadata: Map.put(state.metadata, :md_made_date, string_date(state.element_acc))
      }

  # <ComingIntoForce>
  #   <Text>Coming into force</Text>
  #   <DateText>at 6.00 p.m. on 10th September 2020</DateText>
  # </ComingIntoForce>

  def sax_event_handler(
        {:startElement, _, 'ComingIntoForce', _, _},
        state,
        _
      ),
      do: %{
        state
        | metadata: Map.merge(state.metadata, %{md_coming_into_force_date: true, element_acc: ""})
      }

  def sax_event_handler(
        {:endElement, _, 'DateText', _},
        %SaxState{metadata: %{md_coming_into_force_date: true}} = state,
        _
      ),
      do: %{
        state
        | metadata:
            Map.put(state.metadata, :md_coming_into_force_date, string_date(state.element_acc))
      }

  def sax_event_handler(
        {:endElement, _, 'ComingIntoForce', _},
        %SaxState{metadata: %{md_coming_into_force_date: true}} = state,
        _
      ),
      do: %{
        state
        | metadata: Map.put(state.metadata, :md_coming_into_force_date, nil)
      }

  # ukm:metadata
  def sax_event_handler({:startElement, _, 'Metadata', 'ukm', _}, state, _),
    do: %{state | main_section: :metadata}

  def sax_event_handler({:endElement, _, 'Metadata', 'ukm'}, state, _), do: state

  def sax_event_handler(
        {:startElement, _, 'TotalParagraphs', 'ukm', [{:attribute, 'Value', [], [], value}]},
        state,
        _
      ),
      do: %{state | metadata: Map.put(state.metadata, :md_total_paras, value)}

  def sax_event_handler(
        {:startElement, _, 'BodyParagraphs', 'ukm', [{:attribute, 'Value', [], [], value}]},
        state,
        _
      ),
      do: %{state | metadata: Map.put(state.metadata, :md_body_paras, value)}

  def sax_event_handler(
        {:startElement, _, 'ScheduleParagraphs', 'ukm', [{:attribute, 'Value', [], [], value}]},
        state,
        _
      ),
      do: %{state | metadata: Map.put(state.metadata, :md_schedule_paras, value)}

  def sax_event_handler(
        {:startElement, _, 'AttachmentParagraphs', 'ukm', [{:attribute, 'Value', [], [], value}]},
        state,
        _
      ),
      do: %{state | metadata: Map.put(state.metadata, :md_attachment_paras, value)}

  def sax_event_handler(
        {:startElement, _, 'TotalImages', 'ukm', [{:attribute, 'Value', [], [], value}]},
        state,
        _
      ),
      do: %{state | metadata: Map.put(state.metadata, :md_images, value)}

  # <ukm:EnactmentDate Date="2022-10-25"/>
  # <ukm:EnactmentDate Date="1971-05-27"/>
  def sax_event_handler(
        {:startElement, _, 'EnactmentDate', 'ukm', [{:attribute, 'Date', [], [], value}]},
        state,
        _
      ),
      do: %{
        state
        | metadata:
            Map.put(state.metadata, :md_enactment_date, string_date(List.to_string(value)))
      }

  # <ukm:Made Date="2021-06-15" Time="09:00:00"/>
  def sax_event_handler(
        {:startElement, _, 'Made', 'ukm', [{:attribute, 'Date', [], [], value}, _]},
        state,
        _
      ),
      do: %{
        state
        | metadata: Map.put(state.metadata, :md_made_date, string_date(List.to_string(value)))
      }

  # <ukm:Made Date="2021-06-15"/>
  def sax_event_handler(
        {:startElement, _, 'Made', 'ukm', [{:attribute, 'Date', [], [], value}]},
        state,
        _
      ),
      do: %{
        state
        | metadata: Map.put(state.metadata, :md_made_date, string_date(List.to_string(value)))
      }

  # <ukm:ComingIntoForce>
  #   <ukm:DateTime Date="2022-04-01"  Time="00:00:00"/>
  # </ukm:ComingIntoForce>

  def sax_event_handler(
        {:startElement, _, 'ComingIntoForce', 'ukm', _},
        state,
        _
      ),
      do: %{state | metadata: Map.put(state.metadata, :md_coming_into_force_date, true)}

  def sax_event_handler(
        {:startElement, _, 'DateTime', 'ukm', attributes},
        %SaxState{metadata: %{md_coming_into_force_date: true}} = state,
        _
      ) do
    md = enum_attributes(attributes, state.metadata)
    Map.put(state, :metadata, md)
  end

  # <ukm:InForceDates>
  # <ukm:InForce Date="2012-05-28" Qualification="wholly in force" Applied="false"/>
  # </ukm:InForceDates>
  """
  def sax_event_handler(
        {:startElement, _, 'InForceDates', 'ukm', _},
        %SaxState{metadata: %{md_coming_into_force_date: nil}} = state,
        _
      ),
      do: %{state | metadata: Map.put(state.metadata, :md_coming_into_force_date, true)}

  def sax_event_handler(
        {:startElement, _, 'InForce', 'ukm', attributes},
        %SaxState{metadata: %{md_coming_into_force_date: true}} = state,
        _
      ) do
    md = enum_attributes(attributes, state.metadata)

    Map.put(state, :metadata, md)
  end
  """

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
  # def sax_event_handler({:startElement, _, _, 'dc', _} = v, state, _) do
  #  IO.inspect(v)
  #  %{state | element_acc: ""}
  # end

  def sax_event_handler({:startElement, _, 'title', 'dc', _}, state, _),
    do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'title', 'dc'}, %{main_section: :metadata} = state, _) do
    %{state | metadata: Map.put(state.metadata, :Title_EN, state.element_acc), element_acc: ""}
  end

  # <dc:date>1984-06-26</dc:date>
  def sax_event_handler({:startElement, _, 'date', 'dc', _}, state, _),
    do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'date', 'dc'}, %{main_section: :metadata} = state, _) do
    %{
      state
      | metadata: Map.put(state.metadata, :enactment_date, state.element_acc),
        element_acc: ""
    }
  end

  # <dct:valid>2013-10-01</dct:valid>
  def sax_event_handler({:startElement, _, 'valid', 'dct', _}, state, _),
    do: %{state | element_acc: ""}

  def sax_event_handler({:endElement, _, 'valid', 'dct'}, %{main_section: :metadata} = state, _) do
    %{
      state
      | metadata: Map.put(state.metadata, :md_dct_valid_date, state.element_acc),
        element_acc: ""
    }
  end

  def sax_event_handler(
        {:startElement, _, 'subject', 'dc', [{:attribute, 'scheme', [], [], 'SIheading'}]},
        state,
        _
      ),
      do: %{state | element_acc: "", si_code: true}

  def sax_event_handler({:startElement, _, 'subject', 'dc', _}, state, _), do: state

  def sax_event_handler({:endElement, _, 'subject', 'dc'}, %{main_section: :metadata} = state, _) do
    case state.si_code do
      true ->
        %{
          state
          | metadata: Map.put(state.metadata, :si_code, state.element_acc),
            element_acc: "",
            si_code: false
        }

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

  def sax_event_handler(
        {:endElement, _, 'description', 'dc'},
        %{main_section: :metadata} = state,
        _
      ) do
    %{
      state
      | metadata: Map.put(state.metadata, :md_description, state.element_acc),
        element_acc: ""
    }
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

  defp enum_attributes([], metadata), do: metadata

  defp enum_attributes(attributes, metadata) do
    Enum.reduce(attributes, metadata, fn a, acc ->
      case get_attribute(a) do
        nil -> acc
        {k, v} -> Map.put(acc, k, v)
      end
    end)
  end

  defp get_attribute({:attribute, att, [], [], value}) do
    cond do
      att == 'RestrictStartDate' -> {:md_restrict_start_date, List.to_string(value)}
      att == 'RestrictExtent' -> {:md_restrict_extent, List.to_string(value)}
      att == 'Date' -> {:md_coming_into_force_date, string_date(List.to_string(value))}
      true -> nil
    end
  end

  defp get_attribute(_), do: nil

  @months ~w[january february march april may june july august september october november december]
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {k, v + 1} end)

  defp string_date(""), do: nil

  defp string_date(date) when is_binary(date) do
    case String.contains?(date, "-") do
      true ->
        date

      false ->
        # Handles dates like 6th September 2023, [2nd June 1960], at 4.30 p.m. on 10th September 2020, 6th May2004
        # IO.puts(~s/ #{date}/)

        date = Regex.replace(~r/[[:punct:]]/m, date, "")

        # separate May2004 -> May 2004
        date = Regex.replace(~r/([a-z])(\d{4})$/, date, "\\g{1} \\g{2}")

        # separate 1stApril -> 1st April
        date = Regex.replace(~r/(st|nd|rd|th)([A-Z])/, date, "\\g{1} \\g{2}")

        [day, month, year] = date |> rm_time |> String.split()

        day = String.replace(day, ~r/[^\d]/, "") |> add_zero()

        month = String.downcase(month) |> (&Map.get(@months, &1)).() |> add_zero()

        ~s/#{year}-#{month}-#{day}/
    end
  end

  defp rm_time(date) when is_binary(date) do
    # rm time from 'at 4.30 p.m. on 10th September 2020'
    # IO.puts(date)

    Regex.replace(~r/.*?on[ ]/, date, "")
    |> (&Regex.replace(~r/at.*/, &1, "")).()
    |> (&Regex.replace(~r/.*?pm[ ]/, &1, "")).()
  end

  defp add_zero(s) when is_integer(s), do: add_zero(Integer.to_string(s))

  defp add_zero(s) when is_binary(s) do
    case String.length(s) do
      1 -> ~s/0#{s}/
      _ -> s
    end
  end
end
