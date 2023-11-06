defmodule UK do
  @moduledoc """
  Parsing text copied from the plain view at [legislation.gov.uk](https://legislation.gov.uk)
  """

  alias Types.AirtableSchema

  @typedoc """
  A part of a piece of legislation.

  `:both`, `:law`, `:annex`
  """
  @type part :: atom

  @typedoc "The Name (unique ID) field of the Legal Register"
  @type lr_name_field :: String.t()
  @typedoc """
  The type of a piece of legislation.
  `:act`, `:regulation`
  """
  @type uk_law_type :: atom
  @typedoc """
    law_type_code is one of the three params that uniquely ids UK law
    e.g. "uksi", "ukpga"
  """
  @type law_type_code :: String.t()
  @typedoc """
    law_number is one of the three params that uniquely ids UK law
    e.g. "700"
  """
  @type law_number :: String.t()
  @typedoc """
    law_year is one of the three params that uniquely ids UK law
    e.g. 2023
  """
  @type law_year :: integer()

  @region_regex "U\\.K\\.|E\\+W\\+N\\.I\\.|E\\+W\\+S|E\\+W|S\\+N\\.I\\."
  @country_regex "N\\.I\\.|S|W|E"
  @geo_regex @region_regex <> "|" <> @country_regex
  # U\\.K\\.|E\\+W\\+N\\.I\\.|E\\+W\\+S|E\\+W|N\\.I\\.
  # geo U\.K\.|E\+W\+N\.I\.|E\+W\+S|E\+W|N\.I\.|S|W|E

  def region(), do: @region_regex
  def country(), do: @country_regex
  def geo(), do: @geo_regex

  @doc """
  Function provides a shortcut to list all the members of the Dutyholders taxonomy
  """

  def create(), do: Legl.Countries.Uk.LeglRegister.New.New.create()
  def create_from_file(), do: Legl.Countries.Uk.LeglRegister.New.New.create_from_file()
  def creates(), do: Legl.Countries.Uk.LeglRegister.New.New.creates()
  def bare(), do: Legl.Countries.Uk.LeglRegister.New.New.create_from_bare_file()

  def dutyholders(),
    do:
      Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib.print_dutyholders_to_console()

  def dutyTypes(),
    do: Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType.print_duty_types_to_console()

  def enact(opts),
    do: Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.run(opts)

  def amend(opts \\ []),
    do: Legl.Countries.Uk.LeglRegister.Amend.run(opts)

  def revoke(opts),
    do: Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.run(opts)

  def metadata(opts),
    do: Legl.Countries.Uk.Metadata.run(opts)

  def extent(opts),
    do: Legl.Countries.Uk.LeglRegister.Extent.run(opts)

  def legl_content(opts) do
    Legl.Countries.Uk.AtArticle.Original.Original.run(opts)
    parse(opts)
    airtable(opts)
  end

  # @impl true
  def schema(type) do
    case type do
      :act ->
        %AirtableSchema{
          country: :UK,
          fields: UK.Act.fields(),
          number_fields: UK.Act.number_fields(),
          part: ~s/^(\\d+[A-Z]*|[A-Z])[ ](.*)[ ]\\[::region::\\](.*)/,
          chapter: ~s/^(\\d+[A-Z]*|[A-Z])[ ](.*)[ ]\\[::region::\\](.*)/,
          heading: ~s/^([A-Z]?\\d*[A-Z]*)[ ]?(.*)[ ]\\[::region::\\](.*)/,
          section: ~s/^([A-Z]?\\d+[a-zA-Z]*\\d?)-?(\\d+)?[ ](.*)[ ]\\[::region::\\](.*)/,
          sub_section: ~s/^([A-Z]?\\d+[A-Z]*)[ ](.*)/,
          paragraph: ~s/^([A-Z]?\\d+[a-zA-Z]*\\d?)-?(\\d+)?[ ](.*)[ ]\\[::region::\\](.*)/,
          sub_paragraph: ~s/^([A-Z]?\\d+[A-Z]*)[ ](.*)/,
          amendment: ~s/^([A-Z])(\\d+)(.*)/,
          modification: ~s/^(C)(\\d+)(.*)/,
          annex_name: "schedule",
          annex: ~s/(\\d*[A-Z]*)[ ]?(.*?(SCHEDULES?|Schedules?).*)[ ]\\[::region::\\](.*)/
        }

      :regulation ->
        %AirtableSchema{
          country: :UK,
          fields: UK.Regulation.fields(),
          number_fields: UK.Regulation.number_fields(),
          part: ~s/^(\\d+[A-Z]*|[A-Z])[ ](.*)[ ]?\\[::region::\\](.*)/,
          chapter_name: "chapter",
          chapter: ~s/^(\\d+[A-Z]*|[A-Z])[ ](.*)[ ]\\[::region::\\](.*)/,
          heading: ~s/^([A-Z]?[\\d\.]*[A-Z]*)[ ]?(.*)[ ]\\[::region::\\](.*)/,
          heading_name: "heading",
          article: ~s/^([A-Z]?\\d+[a-zA-Z]*\\d?)-?([A-Z]?\\d+)?[ ](.*)[ ]\\[::region::\\](.*)/,
          article_name: "article",
          sub_article: ~s/^([A-Z]?\\d+[A-Z]*)[ ](.*)/,
          sub_article_name: "sub-article",
          para: ~s/^(\\d+)[ ](.*)/,
          para_name: "sub-article",
          signed_name: "signed",
          annex: ~s/(\\d*[A-Z]*)[ ]?(.*?(SCHEDULES?|Schedules?).*)[ ]\\[::region::\\](.*)/,
          annex_name: "schedule",
          footnote_name: "footnote",
          amendment: ~s/^([A-Z])(\\d+)(.*)/,
          paragraph: ~s/^([A-Z]?[\\.\\d]+[a-zA-Z]*\\d?)-?(\\d+)?[ ](.*)[ ]\\[::region::\\](.*)/,
          sub_paragraph: ~s/^([A-Z]?\\d+[A-Z]*)[ ](.*)(?:\\[::region::\\])?/
        }
    end
  end

  @parse_default_opts %{
    type: :regulation,
    html?: true,
    clean?: true,
    annotation: true,
    parse: true,
    # provision_before_schedule
    pbs?: false,
    opts?: false,

    # parse Acts with Ordinal schedules eg First Schedule
    numericalise_schedules: false,

    # Sections with rare acronyms as text rather than amendment suffix
    split_acronymed_sections: false,

    # switch for Acts with period after number
    "s_.": false,

    # parse Acts with numbered headings
    numbered_headings: false,

    # overarching switch for the QA functions
    qa: true,
    # finer control of QA functions
    qa_sched_s_limit?: true,
    qa_sched_s?: true,
    qa_sched_paras?: true,
    qa_sched_paras_limit?: true,
    qa_si?: true,
    qa_si_limit?: true,
    qa_sii?: true,
    qa_sii_limit?: true,
    qa_list_efs: true,
    qa_list_bracketed_efs: false,
    qa_list_clean_efs: false,
    list_headings: false,
    qa_sections: true,
    list_section_efs: false,

    # PARSER QA
    # List Clause Numbers
    qa_lcn_part: true,
    qa_lcn_chapter: true,
    qa_lcn_annex: true,
    qa_lcn_section: true,
    qa_lcn_sub_section: false,
    qa_lcn_paragraph: true
  }

  @doc """
  Creates an annotated text file that can be quality checked by a human.
  """
  @original ~s[lib/legl/data_files/txt/original.txt] |> Path.absname()
  @clean ~s[lib/legl/data_files/txt/clean.txt] |> Path.absname()
  @annotated ~s[lib/legl/data_files/txt/annotated.txt] |> Path.absname()
  @parsed ~s[lib/legl/data_files/txt/parsed.txt] |> Path.absname()
  def parse(opts \\ []) do
    opts = Enum.into(opts, @parse_default_opts)

    if opts.opts?, do: IO.inspect(opts, label: "\nOptions: ")

    binary =
      case opts.clean? do
        true ->
          IO.puts("***********CLEAN***********")

          text =
            File.read!(@original)
            |> Legl.Countries.Uk.UkClean.clean_original(opts)

          File.open(@clean, [:write, :utf8])
          |> elem(1)
          |> IO.write(text)

          text

        _ ->
          File.read!(@clean)
      end

    binary |> (&IO.puts("\nLAW: #{String.slice(&1, 0, 300)}...")).()

    binary =
      if opts.html? do
        binary
      else
        case opts.annotation do
          true ->
            IO.puts("\n***********ANNOTATION***********\n")
            Legl.Countries.Uk.AirtableArticle.UkAnnotations.annotations(binary, opts)

          _ ->
            File.read!(@annotated)
        end
      end

    if opts.type == :act and opts.annotation, do: File.write(@annotated, binary)

    case opts.parse do
      true ->
        IO.write("\n***********PARSER***********\n")

        binary = UK.Parser.parser(binary, opts)

        IO.puts("...complete")

        File.open(@parsed, [:write, :utf8])
        |> elem(1)
        |> IO.write(binary)

      _ ->
        :ok
    end
  end

  @airtable_default_opts %{
    name: "default",
    country: :uk,
    type: :regulation,
    made?: false,
    csv: true,
    # tab delimited list
    tdl: false,
    chunk: 200,
    # debug print to screen
    separate_ef_codes_from_numerics: false,
    separate_ef_codes_from_non_numerics: false
  }

  @doc """

    Translates the annotated text file of the law into a tab-delimited text file and a csv file
    suitable for pasting / uploading directly into an Airtable grid view.

    Create Airtable data using all fields

    Run as:
    iex>UK.airtable()

    Options as list.

    For fields, eg DE.airtable(fields: [:text])  See %UK{}

    The Airtable fields are:

    * flow
    * type
    * part
    * chapter
    * subchapter
    * article
    * para
    * sub
    * text

    ## Options

    Type can be `:act` or `:regulation`, defaults to `:regulation`

    Part can be `:both`, `:law` or `:annex`, defaults to `:both`

    Fields, a list of one or more of the Airtable field names, to generate data just for those fields.
    E.g. `[:flow, :text]`  Defaults to an empty list `[]`.

    ## Running

    `>iex -S mix`

    `iex(1)>UK.airtable(name: "airtable-id", type: :regulation)`

  """
  def airtable(opts \\ []) do
    opts = Enum.into(opts, @airtable_default_opts)

    IO.inspect(opts, label: "Options: ")

    {:ok, binary} = File.read(@parsed)

    # fields as a list
    # [:flow, :type, :part, :chapter, :heading, :section, :sub_section, :article, :para, :text, :region]
    fields =
      case opts.type do
        :act -> UK.Act.fields()
        :regulation -> UK.Regulation.fields()
      end

    schema = schema(opts.type)

    opts_at = Keyword.merge(Map.to_list(opts), fields: fields, schema: schema)

    # IO.inspect(opts)
    case opts do
      %{type: :act} ->
        Legl.airtable(binary, schema, opts_at)
        |> Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess.process(opts_at)

      %{type: :regulation, made?: false} ->
        Legl.airtable(binary, schema, opts_at)
        |> Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess.process(opts_at)

      %{type: :regulation} ->
        records = Legl.airtable(binary, schema, opts_at)
        Legl.Legl.LeglPrint.to_csv(records, opts)
    end

    :ok
  end
end
