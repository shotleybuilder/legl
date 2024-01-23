defmodule UK do
  @moduledoc """
  Parsing text copied from the plain view at [legislation.gov.uk](https://legislation.gov.uk)
  """

  alias Types.AirtableSchema
  alias Legl.Countries.Uk.LeglRegister.New.New
  alias Legl.Countries.Uk.LeglRegister.Crud.CreateFromInput
  alias Legl.Countries.Uk.LeglRegister.Crud.CreateFromFile
  alias Legl.Countries.Uk.LeglRegister.Crud.Update
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke, as: RR
  alias Legl.Countries.Uk.LeglRegister.CRUD.FindNewLaw
  alias Legl.Countries.Uk.LeglRegister.PublicationDate
  # ARTICLES
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa, as: Taxa

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

  @api [
    "MENU: Update": {:update},
    "MENU: Taxa": {:taxa},
    "LRT: UPDATE Single Law using 'Name'": {Update, :api_update_single_name},
    "LRT: UPDATE using an AT View": {Update, :api_update_single_view},
    "LRT: UPDATE": {Update, :api_update, [[csv?: false]]},
    "POST or PATCH Single Law using :type_code, :number, :year":
      {CreateFromInput, :api_create_update_single_record, [[patch?: true, csv?: false]]},
    "***NEW PUBLISHED LAWS WORKFLOW***": nil,
    "GET Newly Published Laws from gov.uk": {New, :api_get_newly_published_laws},
    "CATEGORISE New Laws from File": {CreateFromFile, :api_read_new_laws_and_categorise},
    "CREATE New Laws from File": {CreateFromFile, :api_create_newly_published_laws},
    "Newly Published Laws from gov.uk": {New, :api_create_newly_published_laws},
    "Newly Published Laws from File":
      {CreateFromFile, :api_create_newly_published_laws,
       [
         [
           workflow: :update,
           csv?: false,
           mute?: true,
           post?: false,
           patch?: false
         ]
       ]},
    "Categorised Bare Laws from File":
      {CreateFromFile, :api_create_from_file_categorised, [[csv?: false]]},
    "Excluded Laws from File": {New, :save_bare_excluded, [[patch?: true, csv?: false]]},
    "Bare Laws from File":
      {CreateFromFile, :api_create_from_file_bare,
       [
         [
           workflow: :update,
           csv?: false,
           mute?: true,
           post?: false,
           patch?: false
         ]
       ]},
    "Bare Laws w/ metadata from File":
      {CreateFromFile, :api_create_from_file_w_metadata,
       [
         [
           workflow: :update,
           csv?: false,
           mute?: true,
           post?: false,
           patch?: false
         ]
       ]},
    "FIND Publication Date": {PublicationDate, :find_publication_date, []},
    "Amend - single record - patch":
      {Legl.Countries.Uk.LeglRegister.Amend, :single_record, [workflow: :create]},
    "Amend - patch": {Amend, :run, [workflow: :create]},
    "DELTA Amend - single record - patch": {Amend, :single_record, [workflow: :update]},
    "DELTA Amend": {Amend, :run, [workflow: :update]},
    "Repeal|Revoke - single record - patch": {RR, :single_record, [workflow: :update]},
    "Repeal|Revoke - patch": {RR, :run, [workflow: :update]},
    "DELTA Repeal|Revoke - single record - patch": {RR, :single_record, [workflow: :update]},
    "DELTA Repeal|Revoke - patch": {RR, :run, [workflow: :delta]},
    "***NEW LAWS FROM AT AMENDS & REVOKES WORKFLOW***": nil,
    "DIFF Amended by - amending laws that aren't in the Base 'EARM Amended by & Revoked by'":
      {FindNewLaw, :amending},
    "DIFF Amending - amended by laws that aren't in the Base VIEW: '% DIFF Amending' 'EARM Amending & Revoking'":
      {FindNewLaw, :new_amended_law}
  ]

  def api(opts \\ []) do
    IO.puts(~s/Menu from [#{__MODULE__}].api/)

    case ExPrompt.choose("spongl API", Enum.map(@api, fn {k, _} -> k end)) do
      -1 ->
        :ok

      n ->
        run =
          Enum.map(@api, fn {_k, v} -> v end)
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)
          |> Map.get(n)

        # |> IO.inspect()

        case run do
          {module, function, args} when is_atom(function) ->
            args = [List.first(args) ++ opts]
            apply(module, function, args)

          {module, function} when is_atom(module) and is_atom(function) ->
            apply(module, function, [opts])

          {function, args} when is_atom(function) and is_list(args) ->
            args = [List.first(args) ++ opts]
            apply(__MODULE__, function, args)

          {function} ->
            apply(__MODULE__, function, [opts])
        end
    end
  end

  @update [
            {Update, :api_update_metadata_fields, [[]]},
            {Update, :api_update_extent_fields, [[]]},
            {Update, :api_update_enact_fields, [patch?: true, csv?: false]},
            {Update, :api_update_amend_fields, [patch?: true, csv?: false, mute?: true]},
            {Update, :api_update_repeal_revoke_fields, [patch?: true, csv?: false, mute?: true]}
          ]
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)

  def update do
    case ExPrompt.choose(
           "Update Choices",
           ~W/Metadata Extent Enact Amend Re[peal|voke]/
         ) do
      -1 ->
        :ok

      n ->
        {module, function, args} = Map.get(@update, n)
        apply(module, function, args)
    end
  end

  @taxa [
          {Taxa, :api_update_lat_taxa},
          {Taxa, :api_update_multi_lat_taxa}
        ]
        |> Enum.with_index()
        |> Enum.into(%{}, fn {k, v} -> {v, k} end)

  def taxa(opts) do
    case ExPrompt.choose(
           "Taxa Choices",
           ~W/Update_Single_Law Update_Laws/
         ) do
      -1 ->
        :ok

      n ->
        case Map.get(@taxa, n) do
          {module, function, args} ->
            args = [List.first(args) ++ opts]
            IO.inspect(args, label: "args")
            apply(module, function, [args])

          {module, function} ->
            apply(module, function, [opts])
        end
    end
  end

  @doc """
  Function provides a shortcut to list all the members of the Dutyholders taxonomy
  """
  def dutyholders(),
    do: Legl.Countries.Uk.Article.Taxa.Actor.ActorLib.print_dutyholders_to_console()

  def dutyTypes(),
    do: Legl.Countries.Uk.Article.Taxa.DutyTypeTaxa.DutyType.print_duty_types_to_console()

  def enact(opts),
    do: Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.run(opts)

  def amend_single_record(opts \\ []),
    do: Legl.Countries.Uk.LeglRegister.Amend.single_record(opts)

  def amend(opts \\ []),
    do: Legl.Countries.Uk.LeglRegister.Amend.run(opts)

  def repeal_revoke_single_record(opts \\ []),
    do: RR.single_record(opts)

  def repeal_revoke(opts \\ []),
    do: RR.run(opts)

  def metadata(opts \\ []),
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
