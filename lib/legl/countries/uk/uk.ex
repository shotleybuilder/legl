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

  @typedoc """
  The type of a piece of legislation.

  `:act`, `:regulation`
  """
  @type uk_law_type :: atom

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
  def dutyholders(),
    do:
      Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib.print_dutyholders_to_console()

  def dutyTypes(),
    do: Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType.print_duty_types_to_console()

  def enact(opts),
    do: Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.run(opts)

  def amend(opts),
    do: Legl.Countries.Uk.LeglRegister.Amend.UkAmendClient.run(opts)

  def revoke(opts),
    do: Legl.Countries.Uk.RepealRevoke.RepealRevoke.run(opts)

  def metadata(opts),
    do: Legl.Countries.Uk.Metadata.run(opts)

  def extent(opts),
    do: Legl.Countries.Uk.LeglRegister.Extent.run(opts)

  def regulation(url) do
    Legl.Countries.Uk.AtArticle.Original.Original.run(url)
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
          part: ~s/^(\\d+|[A-Z])[ ](.*)/,
          chapter_name: "chapter",
          chapter: ~s/^(\\d+)[ ](.*)/,
          heading: ~s/^(\\d+[A-Z]?)[ ](.*)/,
          heading_name: "heading",
          article: ~s/^(\\d+[a-zA-Z]*)-?(\\d+)?[ ](.*)/,
          article_name: "article",
          sub_article: ~s/^(\\d+)[ ](.*)/,
          sub_article_name: "sub-article",
          para: ~s/^(\\d+)[ ](.*)/,
          para_name: "sub-article",
          signed_name: "signed",
          annex: ~s/^(\\d*[A-Z]?)[ ](.*)/,
          annex_name: "schedule",
          footnote_name: "footnote",
          amendment: ~s/^([A-Z])(\\d+)(.*)/,
          paragraph: ~s/^([A-Z]?\\d+[a-zA-Z]*\\d?)-?(\\d+)?[ ](.*)/
        }
    end
  end

  @parse_default_opts %{
    type: :regulation,
    clean: false,
    annotation: true,
    parse: true,

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

  UK Acts and Regulations (primary and secondary legislation) have to be parsed
  differently and this is set with the `:type` option.

  Laws often have 2 parts: a main content section and a section of schedules.
  Save text copied from the main content section  as `original.txt` & that copied from
  the schedules as `original_annex.txt`.  Use the `:part` option to use `:both` (which is also the default) files,
  or just `:main` for laws without schedules.

  ## Options

  :clean -> true = clean before parsing or false = use clean.txt

  Type can be `:act` or `:regulation`, defaults to `:regulation`

  Part can be `:both`, `:main` or `:annex`, defaults to `:both`

  ## Running

  `>iex -S mix`

  `iex(1)>UK.parse()`

  or with Options

  `iex(2)>UK.parse(part: :annex, type: :regulation)`

  `iex(3)>UK.parse(:main, :regulation)`

  `iex(4)>UK.parse(:annex)`
  """
  def parse(opts \\ []) do
    opts = Enum.into(opts, @parse_default_opts)

    IO.inspect(opts, label: "\nOptions: ")

    binary =
      case opts.clean do
        true ->
          clean(opts)

        _ ->
          Legl.txt("clean")
          |> Path.absname()
          |> File.read!()
      end

    binary =
      case opts.annotation do
        true ->
          IO.puts("\n\n***********ANNOTATION***********\n")
          Legl.Countries.Uk.AirtableArticle.UkAnnotations.annotations(binary, opts)

        _ ->
          Legl.txt("tagged")
          |> Path.absname()
          |> File.read!()
      end

    if opts.annotation, do: Legl.txt("tagged") |> Path.absname() |> File.write(binary)

    case opts.parse do
      true ->
        IO.puts("\n\n***********PARSER***********\n")

        Legl.txt("annotated")
        |> Path.absname()
        |> File.write("#{UK.Parser.parser(binary, opts)}")

        :ok

      _ ->
        :ok
    end
  end

  @clean_default_opts %{
    type: :regulation,
    # parse Acts with Ordinal schedules eg First Schedule
    numericalise_schedules: false,

    # Sections with rare acronyms as text rather than amendment suffix
    split_acronymed_sections: false
  }

  def clean(opts \\ []) do
    opts = Enum.into(opts, @clean_default_opts)
    IO.puts("\n***********CLEAN***********\n")

    Legl.txt("original")
    |> Path.absname()
    |> File.read!()
    |> Legl.Countries.Uk.UkClean.clean_original(opts)
  end

  @airtable_default_opts %{
    name: "default",
    country: :uk,
    type: :regulation,
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
    type = opts.type

    IO.inspect(opts, label: "Options: ")

    # fields as a list
    # [:flow, :type, :part, :chapter, :heading, :section, :sub_section, :article, :para, :text, :region]
    fields =
      case type do
        :act -> UK.Act.fields()
        :regulation -> UK.Regulation.fields()
      end

    schema = schema(type)

    opts = Keyword.merge(Map.to_list(opts), fields: fields, schema: schema)

    # IO.inspect(opts)
    case type do
      :act ->
        Legl.airtable(schema, opts)
        |> Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess.process(opts)

      :regulation ->
        Legl.airtable(schema, opts)
    end

    :ok
  end
end
