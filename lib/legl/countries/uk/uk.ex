defmodule UK do
  @moduledoc """
  Parsing text copied from the plain view at [legislation.gov.uk](https://legislation.gov.uk)
  """

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

  @lrt [
    "LRT: UPDATE Single Law using 'Name'": {Update, :api_update_single_name},
    "LRT: UPDATE Law's using a List of 'Names'": {Update, :api_update_list_of_names},
    "LRT: UPDATE using an AT View": {Update, :api_update_single_view},
    "LRT: UPDATE": {Update, :api_update, [[csv?: false]]},
    "POST or PATCH Single Law using :type_code, :number, :year":
      {CreateFromInput, :api_create_update_single_record, [[patch?: true, csv?: false]]},
    "POST or PATCH List of csv 'Name's":
      {CreateFromInput, :api_create_update_list_of_records, [[csv?: false]]},
    "***NEW PUBLISHED LAWS WORKFLOW***": nil,
    "GET Newly Published Laws from gov.uk": {New, :api_get_newly_published_laws},
    "CATEGORISE New Laws from File": {CreateFromFile, :api_read_new_laws_and_categorise},
    "CREATE New Laws from File": {CreateFromFile, :api_create_newly_published_laws},
    "Newly Published Laws from gov.uk": {New, :api_create_newly_published_laws},
    "Newly Published Laws from File":
      {CreateFromFile, :api_create_newly_published_laws,
       [
         [
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
      {FindNewLaw, :amending, [[filesave?: true]]},
    "DIFF Amending - amended by laws that aren't in the Base VIEW: '% DIFF Amending' 'EARM Amending & Revoking'":
      {FindNewLaw, :new_amended_law, [[filesave?: true]]},
    "***HELPER FUNCTIONS***": nil,
    "Print Dutyholder to Terminal":
      {Legl.Countries.Uk.Article.Taxa.Actor.ActorLib, :print_dutyholders_to_console},
    "Print Duty Type to the Terminal":
      {Legl.Countries.Uk.Article.Taxa.DutyTypeTaxa.DutyType, :print_duty_types_to_console},
    "Compare Lists": {Legl.Utility, &Legl.Utility.delta_lists/0}
  ]
  @spec lrt(list()) :: any()
  def lrt(opts \\ []) do
    IO.puts(~s/LRT Menu from [#{__MODULE__}].lrt/)

    case Keyword.has_key?(opts, :selection) do
      true -> api(@lrt, Keyword.get(opts, :selection), opts)
      _ -> api(@lrt, opts)
    end
  end

  # LEGAL ARTICLES TABLE

  @lat [
    Parse: {Legl.Countries.Uk.LeglArticle.Article, :api_article},
    "MENU: Taxa": {:taxa}
  ]
  @doc """
  Function to select workflows for Legal Articles Tables

  """
  @spec taxa(list()) :: any()
  def lat(opts \\ []) do
    IO.puts(~s/\nLAT Menu from [#{__MODULE__}].lat/)
    opts = Enum.into(opts, %{})

    case opts do
      %{lat_selection: n} -> api(@lat, n, opts)
      _ -> api(@lat, opts)
    end
  end

  @taxa [
    Update_Single_Law: {Taxa, :api_update_lat_taxa},
    Update_Laws: {Taxa, :api_update_multi_lat_taxa},
    Update_Law_from_Gov: {Taxa, :api_update_lat_taxa_from_gov},
    Test: {:test}
  ]

  @doc """
  Function to select the LRT Taxa workflow

  Sending the option opts param :taxa_selection selects programmatically
  """
  @spec taxa(list()) :: any()
  def taxa(opts \\ []) do
    IO.puts(~s/\nTAXA Menu from [#{__MODULE__}].taxa/)
    opts = Enum.into(opts, %{})

    case opts do
      %{taxa_selection: n} -> api(@taxa, n, opts)
      _ -> api(@taxa, opts)
    end
  end

  def test(opts), do: opts

  # PRIVATE FUNCTIONS

  defp api(menu, n, opts) when is_integer(n) do
    selection =
      Enum.map(menu, fn {_k, v} -> v end)
      |> Enum.with_index()
      |> Enum.into(%{}, fn {k, v} -> {v, k} end)
      |> Map.get(n)

    run_function(selection, opts)
  end

  @spec api(list(), map()) :: any()
  defp api(menu, opts) do
    case ExPrompt.choose("Spongl API", Enum.map(menu, fn {k, _} -> k end)) do
      -1 ->
        :ok

      n ->
        selection =
          Enum.map(menu, fn {_k, v} -> v end)
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)
          |> Map.get(n)

        run_function(selection, opts)
    end
  end

  defp run_function(selection, opts) do
    case selection do
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

      {_, function} when is_function(function) ->
        function.()
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

  def airtable_default_opts, do: @airtable_default_opts

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

    schema = Legl.Airtable.Schema.schema(opts.type)

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
