defmodule Legl.Countries.Uk.LeglRegister.New.New do
  @moduledoc """
  Module to obtain new laws from legislation.gov.uk and POST to Airtable
  API
  api_create - create a single new law record in a LEGAL REGISTER TABLE

  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  # alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.CRUD.Options
  alias Legl.Countries.Uk.LeglRegister.New.New.Airtable
  alias Legl.Countries.Uk.LeglRegister.New.New.LegGovUk
  alias Legl.Countries.Uk.LeglRegister.New.Filters
  # alias Legl.Countries.Uk.LeglRegister.New.New.PublicationDateTable, as: PDT
  alias Legl.Countries.Uk.Metadata, as: MD
  alias Legl.Countries.Uk.Metadata
  alias Legl.Countries.Uk.LeglRegister.Extent
  alias Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.IdField
  alias Legl.Countries.Uk.LeglRegister.PublicationDate
  alias Legl.Countries.Uk.LeglRegister.Tags
  alias Legl.Countries.Uk.LeglRegister.TypeClass
  alias Legl.Countries.Uk.LeglRegister.Year

  # @api_path ~s[lib/legl/countries/uk/legl_register/new/api.json]
  @source ~s[lib/legl/countries/uk/legl_register/crud/api_source.json]
  @newlaws ~s[lib/legl/countries/uk/legl_register/crud/api_new_laws.json]
  @api_patch_path ~s[lib/legl/countries/uk/legl_register/crud/api_patch_results.json]
  @api_post_path ~s[lib/legl/countries/uk/legl_register/crud/api_post_results.json]
  @exc_path ~s[lib/legl/countries/uk/legl_register/crud/api_exc.json]
  @inc_wo_si_path ~s[lib/legl/countries/uk/legl_register/crud/api_inc_wo_si.json]
  @inc_w_si_path ~s[lib/legl/countries/uk/legl_register/crud/api_inc_w_si.json]
  @inc_path ~s[lib/legl/countries/uk/legl_register/crud/api_inc.json]

  @drop_fields ~w[affecting_path
    affected_path
    enacting_laws
    enacting_text
    introductory_text
    amending_title
    Name
    text
    path
    urls]a

  @type opts() :: keyword()
  @type bare_record() :: %{type_code: String.t(), Number: String.t(), Year: Integer}

  @doc """
  Function to get newly published laws from legislation.gov.uk

  Saves returned records to lib/legl/countries/uk/legl_register/crud/api_new_laws.json

  Run 'UK.api' and select "GET Newly Published Laws from gov.uk"

  """
  def api_get_newly_published_laws(opts \\ []) do
    opts =
      Enum.into(opts, Options.default_opts())
      |> Options.legal_register_base_id_table_id()
      |> Options.month()
      |> Options.day_groups()
      |> Options.formula()

    # |> PDT.get()

    with(
      {:ok, records} <- LegGovUk.getNewLaws(opts.days, opts),
      records <-
        records
        |> Filters.title_filter()
        |> Enum.map(&Metadata.get_latest_metadata(&1))
    ) do
      records =
        records
        |> Enum.reduce(
          [],
          fn
            {:ok, record}, acc -> [record | acc]
            _, acc -> acc
          end
        )
        |> Enum.reverse()

      Legl.Utility.save_json(records, @newlaws)

      IO.puts("\n#{Enum.count(records)} records saved to .json")
    else
      {:no_data, opts} -> {:no_data, opts}
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Function to get newly published laws from legislation.gov.uk

  Saves returned records to lib/legl/countries/uk/legl_register/crud/api_source.json

  Run 'UK.api' and select "Newly Published Laws from gov.uk"

  Options
    Base name;
  """
  def api_create_newly_published_laws(opts \\ []) do
    opts =
      Enum.into(opts, Options.default_opts())
      |> LRO.base_name()
      |> Options.legal_register_base_id_table_id()
      # |> Options.source()
      |> Options.month()
      |> Options.day_groups()
      |> Options.formula()

    # |> PDT.get()

    # Get the records from gov.uk
    # Save as .json to @source
    # Convert to the LegalRegister struct
    records =
      with(
        {:ok, records} <- LegGovUk.getNewLaws(opts.days, opts),
        :ok = Legl.Utility.save_json(records, @source)
      ) do
        Enum.map(records, &Kernel.struct(%LegalRegister{}, &1))
      else
        {:no_data, opts} -> {:no_data, opts}
        {:error, msg} -> {:error, msg}
      end

    process_newly_published_laws(records, opts)
  end

  @spec process_newly_published_laws(list(), opts()) :: :ok
  def process_newly_published_laws(records, opts) do
    with(
      {:ok, {w_si_code, wo_si_code, exc}} <-
        categoriser(records, opts)
        |> elem(1)
        |> populate_newly_published_law(opts),

      # IO.inspect(exc),
      :ok = save({w_si_code, wo_si_code, exc}, opts)

      # Check off in the Publication Date table to keep a tab of what's been done
      # :ok <- PDT.field_checked?(opts)
    ) do
      :ok
    else
      {:no_data, _opts} ->
        IO.puts("Terms filter didn't find any laws. QA records in 'exc.json'\n")

      # PDT.field_checked?(opts)

      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  @spec categoriser(list(), opts()) :: {:ok, tuple()}
  def categoriser(records, _opts) when is_list(records) do
    with(
      # Filter each Law record based on terms in Title_EN
      {:ok, {inc, exc}} <- Filters.terms_filter(records),

      # Let's stop further workflow if we have filtered out all the records
      # Add the SI Code(s) to each Law record
      # Those w/o SI Code 'inc_wo_si' list

      # {:ok, {inc_w_si, inc_wo_si}} <- LegGovUk.get_si_code(inc),

      # Split Law records based on presence of an SI Code from our set
      # We end up with 3 sets:
      # 1. inc_w_si -> w/ SI Code and Term match
      # 2. inc_wo_si -> w/ only Term match
      # 3. ex -> neither SI Code or Term match
      {:ok, {inc_w_si, inc_wo_si}} <- Filters.si_code_filter(inc)

      # Filter out laws that are already in the Base
      # {:ok, inc_wo_si} <- Helper.filter_delta(inc_wo_si, opts),
      # {:ok, inc_w_si} <- Helper.filter_delta(inc_w_si, opts),
    ) do
      {:ok, inc: inc, inc_w_si: inc_w_si, inc_wo_si: inc_wo_si, exc: exc}
    else
      {:no_data, opts} -> {:no_data, opts}
      {:error, msg} -> {:error, msg}
    end
  end

  def count_categorised({name, records}) do
    count = Enum.count(records)

    case name do
      :inc -> IO.puts("# INC RECORDS: #{count}")
      :inc_w_si -> IO.puts("# W SI CODE RECORDS: #{count}")
      :inc_wo_si -> IO.puts("# W/O SI CODE RECORDS: #{count}")
      :exc -> IO.puts("# EXC RECORDS: #{count}")
    end
  end

  def save_categorised_to_file({name, records}) do
    records = Legl.Utility.maps_from_structs(records)

    case name do
      :exc ->
        records
        |> index_exc()
        |> Legl.Utility.save_json(@exc_path)

      :inc ->
        Legl.Utility.save_json(records, @inc_path)

      :inc_w_si ->
        Legl.Utility.save_json(records, @inc_w_si_path)

      :inc_wo_si ->
        Legl.Utility.save_json(records, @inc_wo_si_path)
    end
  end

  def api_create(records, opts) do
    create(records, opts)
  end

  defp create(records, opts) when is_list(records) do
    Enum.each(
      records,
      fn record ->
        create(record, opts)
      end
    )
  end

  defp create(record, opts) do
    case ExPrompt.confirm(~s/Process #{record."Title_EN"}?/) do
      true ->
        exists? = Legl.Countries.Uk.LeglRegister.Helpers.Create.exists?(record, opts)
        create(record, opts, exists?)

      false ->
        :ok
    end
  end

  defp create(_record, _opts, true), do: :ok

  defp create(record, opts, false) do
    record =
      Enum.reduce(opts.create_workflow, record, fn f, acc ->
        {:ok, record} =
          case :erlang.fun_info(f)[:arity] do
            1 -> f.(acc)
            2 -> f.(acc, opts)
          end

        record
      end)

    post? = if opts.post?, do: true, else: ExPrompt.confirm("\Post #{record."Title_EN"}?")

    case post? do
      true ->
        Legl.Countries.Uk.LeglRegister.PostRecord.post_single_record(record, opts, false)

      false ->
        :ok
    end
  end

  @spec populate_newly_published_law(tuple(), opts()) :: {:ok, tuple()}
  def populate_newly_published_law({inc_w_si, inc_wo_si, exc}, opts) do
    IO.puts("\nPROCESSING LAWS MATCHING Terms and SI Code\n")

    Enum.each(inc_w_si, fn record ->
      record
      |> Year.set_year()
      |> PublicationDate.set_publication_date_link(opts)
      |> elem(1)
      |> update_empty_law_fields(opts)
      |> elem(1)
      |> save(opts)
    end)

    IO.puts("\nPROCESSING LAWS MATCHING Terms and NO MATCH SI Code\n")

    Enum.each(inc_wo_si, fn record ->
      record
      |> Year.set_year()
      |> PublicationDate.set_publication_date_link(opts)
      |> elem(1)
      |> update_empty_law_fields(opts)
      |> elem(1)
      |> save(opts)
    end)

    save_exc(exc, opts)
  end

  @doc """
  Receives a law Record with metadata set and returns a Record for PATCH or POST

  Enacted_by, Amended_by, Revoked_by are overwritten if they exist.
  """
  @spec update_empty_law_fields_w_metadata(%LegalRegister{}, map()) ::
          {:ok, %LegalRegister{}} | {:error}
  def update_empty_law_fields_w_metadata(record, opts)
      when is_map(record) do
    with(
      {:ok, record} <- Year.set_year(record),
      {:ok, record} <- TypeClass.set_type_class(record),
      {:ok, record} <- TypeClass.set_type(record),
      {:ok, record} <- Tags.set_tags(record),
      {:ok, record} <- IdField.lrt_acronym(record),
      {:ok, record} <- Extent.set_extent(record),
      {:ok, record} <- GetEnactedBy.get_enacting_laws(record, opts),
      {:ok, record} <- Amend.workflow(record, opts)
      # {:ok, record} <- RR.workflow(record, opts)
    ) do
      {:ok, record}
    else
      error ->
        IO.puts("ERROR: #{inspect(error)}\n [#{__MODULE__}.update_empty_law_fields_w_metadata/2]")
        {:error}
    end
  end

  @doc """
  Receives a law Record with at least :Number, :type_code and :Year fields,
  a path to save the record as json, and opts and returns a Record for PATCH or POST

  Enacted_by, Amended_by, Revoked_by are overwritten if they exist.
  """
  @spec update_empty_law_fields(%LegalRegister{}, map()) :: {:ok, %LegalRegister{}} | {:error}
  def update_empty_law_fields(record, opts)
      when is_map(record) do
    with(
      {:ok, record} <- MD.get_latest_metadata(record),
      {:ok, record} <- TypeClass.set_type_class(record),
      {:ok, record} <- TypeClass.set_type(record),
      {:ok, record} <- Tags.set_tags(record),
      {:ok, record} <- IdField.lrt_acronym(record),
      {:ok, record} <- Extent.set_extent(record),
      {:ok, record} <- GetEnactedBy.get_enacting_laws(record, opts),
      {:ok, record} <- Amend.workflow(record, opts)
      # {:ok, record} <- RR.workflow(record, opts)
    ) do
      {:ok, record}
    else
      error ->
        IO.puts("ERROR: #{inspect(error)}\n [#{__MODULE__}.update_empty_law_fields/2]")
        {:error}
    end
  end

  def save(record, opts) when is_map(record) do
    record =
      Legl.Utility.map_from_struct(record)
      |> Legl.Utility.map_filter_out_empty_members()

    opts = Map.merge(opts, %{drop_fields: @drop_fields, api_post_path: @api_post_path})
    Legl.Countries.Uk.LeglRegister.PostRecord.run(record, opts)
  end

  def save(records, opts) when is_list(records) do
    records =
      Legl.Utility.maps_from_structs(records)
      |> Legl.Utility.map_filter_out_empty_members()

    IO.puts("#{Enum.count(records)} to be POSTed to Airtable\n")

    opts = Map.merge(opts, %{drop_fields: @drop_fields, api_post_path: @api_post_path})
    Legl.Countries.Uk.LeglRegister.PostRecord.run(records, opts)
  end

  @doc """
   Function to save to Airtable bare laws stored in exc.json
  """
  def save_bare_excluded(opts \\ [csv?: false, mute?: true]) do
    opts =
      Enum.into(opts, %{})
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> Map.merge(%{
        api_patch_path: @api_patch_path,
        api_post_path: @api_post_path
      })

    %{records: records} = @exc_path |> File.read!() |> Jason.decode!(keys: :atoms)

    save_exc(records, opts)
  end

  def save_exc(records, opts) do
    case ExPrompt.get("Enter ID number for any excluded laws to process and save: ") do
      "" ->
        IO.puts("EXIT")
        :ok

      id ->
        # IO.inspect(records, label: "EXC RECORDS: ")

        Map.get(records, :"#{id}")
        |> (&Kernel.struct(%LegalRegister{}, &1)).()
        |> update_empty_law_fields(opts)
        |> elem(1)
        |> save(opts)

        save_exc(records, opts)
    end
  end

  @doc """
  Function to map the excluded laws with an index number.
  The index can be used to process inidividual laws manually if needed
  """
  def index_exc(records) do
    # Enum.with_index(records, fn ele, i -> Map.put(%{}, i, ele) end)
    {records, _} =
      Enum.reduce(records, {%{}, 0}, fn record, {acc, counter} ->
        key = :"#{counter + 1}"
        {Map.put(acc, key, record), counter + 1}
      end)

    records
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.Airtable do
  alias Legl.Services.Airtable.Client

  @doc """
  Publication Date table ID is held by the opts param ':pub_table_id'
  """
  def get_publication_date_table_records(opts) do
    {:ok, url} =
      Legl.Services.Airtable.Url.url(opts.base_id, opts.pub_table_id,
        formula: opts.formula,
        fields: ["Name"]
      )

    {:ok, data} = Client.request(:get, url, [])
    %{records: records} = Jason.decode!(data, keys: :atoms)
    records
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.LegGovUk do
  alias Legl.Services.LegislationGovUk.RecordGeneric, as: LegGovUk
  alias(Legl.Countries.Uk.LeglRegister.Metadata.UkSiCode, as: SI)

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.new_law_parser/1

  def getNewLaws({from, to}, opts) when is_integer(from) and is_integer(to) do
    Enum.reduce(from..to, [], fn day, acc ->
      # Transfrom single number dates eg 1 -> "01"
      day =
        if String.length(Integer.to_string(day)) == 1 do
          ~s/0#{day}/
        else
          day
        end

      month =
        if String.length(Integer.to_string(opts.month)) == 1 do
          ~s/0#{opts.month}/
        else
          ~s/#{opts.month}/
        end

      opts = Map.put(opts, :date, ~s<#{opts.year}-#{month}-#{day}>)

      with(
        url = url(opts),
        :ok = IO.puts("\n#{url}\n [#{__MODULE__}.getLaws]"),
        {:ok, response} <- LegGovUk.leg_gov_uk_html(url, @client, @parser)
      ) do
        Enum.reduce(response, acc, fn law, acc2 ->
          Map.put(law, :publication_date, opts.date)
          |> (&[&1 | acc2]).()
        end)
      else
        {:error, _} -> acc
      end
    end)
    |> (&{:ok, &1}).()
  end

  def url(opts) do
    f = if opts.type_code != [""], do: [~s</new/#{opts.type_code}/>], else: [~s</new/all/>]

    [opts.date | f]
    |> Enum.reverse()
    |> Enum.join()
  end

  def get_si_code(inc) do
    Enum.reduce(inc, {[], []}, fn
      %{type_code: type_code} = law, {ninc, nexc}
      when type_code not in ["ukpga", "asp", "anaw", "apni"] ->
        with(
          {:ok, url} <-
            SI.resource_path({law.type_code, law."Year", law."Number"}),
          {:ok, si_code} <- SI.get_si_code(url)
        ) do
          case si_code do
            x when x in [nil, "", []] ->
              {ninc, [law | nexc]}

            _ ->
              # Deal with country names in SI Codes
              si_code = SI.si_code(si_code)
              law = Map.put(law, :si_code, si_code)

              {[law | ninc], nexc}
          end
        else
          {:none, msg} ->
            IO.puts(msg)
            {ninc, [law | nexc]}
        end

      # Acts do not have SI Codes
      law, {ninc, nexc} ->
        {ninc, [law | nexc]}
    end)
    |> (&{:ok, &1}).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.PublicationDateTable do
  @moduledoc """
  Module to PATCH an update to mark all records that have been processed
  Fields: 'Checked?'
  """
  alias Legl.Countries.Uk.LeglRegister.New.New.Airtable

  def get(opts) do
    Airtable.get_publication_date_table_records(opts)
    |> make_map_of_record_ids(opts)
  end

  @doc """
  Function to create a map with dates as key and record_ids as value
  %{"date" => "record_id"}
  """
  def make_map_of_record_ids(records, opts) do
    Enum.reduce(records, %{}, fn %{id: id, fields: %{Name: date}}, acc ->
      Map.put(acc, date, id)
    end)
    |> (&Map.put(opts, :record_ids, &1)).()
  end

  def make_list_of_dates(%{days: {from, to}, month: month, year: year} = _opts)
      when is_integer(from) and is_integer(to) do
    Enum.map(from..to, fn d ->
      # d = if String.length(Integer.to_string(d)) == 2, do: d, else: ~s/0#{d}/
      {:ok, date} = Date.new(year, month, d)
      date
      # ~s/#{year}-#{month}-#{d}/
    end)
  end

  def field_checked?(opts) do
    # set Publication Date table credentials
    Airtable.get_publication_date_table_records(opts)
    |> patch_to_field_checked(opts)
  end

  def patch_to_field_checked(records, opts) do
    records =
      Enum.map(records, fn record ->
        %{
          id: record.id,
          fields: %{
            Checked?: true
          }
        }
      end)

    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.pub_table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    results =
      Enum.chunk_every(records, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.put(%{}, "records", set)
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(results, fn result_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(result_subset, headers, params)
    end)
  end
end
