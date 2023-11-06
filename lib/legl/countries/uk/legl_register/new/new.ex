defmodule Legl.Countries.Uk.LeglRegister.New.New do
  @moduledoc """
  Module to obtain new laws from legislation.gov.uk and POST to Airtable

  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  alias Legl.Countries.Uk.LeglRegister.New.Options
  alias Legl.Countries.Uk.LeglRegister.New.New.Airtable
  alias Legl.Countries.Uk.LeglRegister.New.New.LegGovUk
  alias Legl.Countries.Uk.LeglRegister.New.Filters
  alias Legl.Countries.Uk.LeglRegister.New.New.PublicationDateTable, as: PDT

  alias Legl.Countries.Uk.LeglRegister.Helpers.Create, as: Helper

  alias Legl.Countries.Uk.LeglRegister.New.Create

  @source ~s[lib/legl/countries/uk/legl_register/new/source.json]

  # @api_path ~s[lib/legl/countries/uk/legl_register/new/api.json]
  @api_patch_path ~s[lib/legl/countries/uk/legl_register/new/api_patch_results.json]
  @api_post_path ~s[lib/legl/countries/uk/legl_register/new/api_post_results.json]

  @exc_path ~s[lib/legl/countries/uk/legl_register/new/exc.json]
  @inc_wo_si_path ~s[lib/legl/countries/uk/legl_register/new/inc_wo_si.json]
  @inc_w_si_path ~s[lib/legl/countries/uk/legl_register/new/inc_w_si.json]
  @inc_path ~s[lib/legl/countries/uk/legl_register/new/inc.json]

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

  @doc """
  Function to create or update the Legal Register record for a SINGLE law.
  """
  def create(opts \\ [csv?: false, mute?: true]) do
    opts =
      Enum.into(opts, %{})
      |> Options.base_name()
      |> Options.base_table_id()
      |> Options.type_code()
      |> Options.number()
      |> Options.year()
      |> Map.merge(%{
        drop_fields: @drop_fields,
        api_patch_path: @api_patch_path,
        api_post_path: @api_post_path
      })

    record = %{Number: opts.number, type_code: opts.type_code, Year: String.to_integer(opts.year)}

    record =
      case Helper.exists?(record, opts) do
        false ->
          record = update_empty_law_fields(record, @inc_path, opts)

          case ExPrompt.confirm("Save #{record."Title_EN"}?") do
            true ->
              Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord.run(record, opts)

            false ->
              :ok
          end

        true ->
          {:ok, records} = Helper.get_lr_record(record, opts)

          IO.puts("Record Exists and will be PATCHED\n")

          Enum.map(records, fn %{fields: fields} = record ->
            update_empty_law_fields(fields, @inc_path, opts)
            |> (&Map.put(record, :fields, &1)).()
          end)
          |> Legl.Countries.Uk.LeglRegister.Helpers.PatchNewRecord.run(opts)
      end

    record
  end

  @doc """
  Function to PATCH or POST to Airtable bare new law records These records might
  have the minimal :type_code, :Number, :Year and all other fields need to be
  populated
  """
  def create_from_bare_file(opts \\ [csv?: false, mute?: true]) do
    opts =
      Enum.into(opts, %{})
      |> Options.base_name()
      |> Options.base_table_id()
      |> Options.source()
      |> Map.merge(%{
        api_patch_path: @api_patch_path,
        api_post_path: @api_post_path
      })

    %{records: records} =
      cond do
        # Process laws saved in .json having processed amending or amended laws
        {:amend, path} = opts.source ->
          path |> File.read!() |> Jason.decode!(keys: :atoms)
      end

    {:ok, w_si_code, wo_si_code, exc} =
      Enum.map(records, &Kernel.struct(%LR{}, &1))
      |> workflow(opts)

    save({w_si_code, wo_si_code, exc}, opts)
  end

  @doc """
  Function to PATCH or POST to Airtable fully formed new law records stored in
  "inc.json"

  Receives list of options

  Returns :ok after successful post

  Run as UK.create_from_file()
  """
  def create_from_file(opts \\ [csv?: false, mute?: true]) do
    opts =
      Enum.into(opts, %{})
      |> Options.base_name()
      |> Options.base_table_id()
      |> Map.merge(%{
        drop_fields: @drop_fields,
        api_patch_path: @api_patch_path,
        api_post_path: @api_post_path
      })

    %{records: records} = Legl.Utility.open_and_parse_json_file(@inc_path)

    case Helper.filter(:both, records, opts) do
      {[], update} ->
        Legl.Countries.Uk.LeglRegister.Helpers.PatchNewRecord.run(update, opts)

      {new, []} ->
        Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord.run(new, opts)

      {new, update} ->
        Legl.Countries.Uk.LeglRegister.Helpers.PatchNewRecord.run(update, opts)
        Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord.run(new, opts)
    end
  end

  @doc """
  Function to set the options, route the workflow to either get records from
  legislation.gov.uk or .json, and POST to Airtable

  Run in the terminal with

  UK.creates()
  Legl.Countries.Uk.LeglRegister.New.New.run()

  """
  def creates(opts \\ []) do
    with(
      {:ok, opts} <- Options.setOptions(opts),
      {:ok, w_si_code, wo_si_code, exc} <-
        cond do
          opts.source == :web ->
            workflow(opts)

          true ->
            %{records: records} = @inc_path |> File.read!() |> Jason.decode!(keys: :atoms)
            records
        end,
      # IO.inspect(exc),
      :ok = save({w_si_code, wo_si_code, exc}, opts),

      # Check off in the Publication Date table to keep a tab of what's been done
      :ok <- PDT.field_checked?(opts)
    ) do
      :ok
    else
      {:no_data, opts} ->
        IO.puts("Terms filter didn't find any laws. QA records in 'exc.json'\n")
        PDT.field_checked?(opts)

      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  @doc """
  Function to save laws in 'inc_w_si.json' and 'inc_wo_si.json' that have had
  all fields completed
  """
  @spec save_from_full_file(list()) :: :ok
  def save_from_full_file(opts \\ []) do
    opts =
      Enum.into(opts, %{})
      |> Options.base_name()
      |> Options.base_table_id()
      |> Options.source()
      |> Map.merge(%{
        api_patch_path: @api_patch_path,
        api_post_path: @api_post_path
      })

    paths =
      case opts.source do
        :si_code ->
          [@inc_w_si_path]

        :x_si_code ->
          [@inc_wo_si_path]

        :both ->
          [@inc_w_si_path, @inc_wo_si_path]

        _ ->
          IO.puts("ERROR: wrong source option chosen")
          []
      end

    records =
      Enum.reduce(paths, [], fn
        path, acc ->
          Legl.Utility.open_and_parse_json_file(path)
          |> Map.get(:records)
          |> (&[&1 | acc]).()
      end)
      |> List.flatten()

    Enum.each(records, &IO.puts("#{&1."Title_EN"} #{&1."Year"}"))

    Enum.each(records, fn
      %{Title_EN: title, si_code: si_code} = record when si_code != nil ->
        case ExPrompt.confirm("SAVE to BASE?: #{title} #{record."Year"} #{si_code}") do
          true -> save([record], opts)
          _ -> nil
        end

      %{Title_EN: title} = record ->
        case ExPrompt.confirm("SAVE to BASE?: #{title}") do
          true -> save([record], opts)
          _ -> nil
        end
    end)
  end

  def save({w_si_code, wo_si_code, exc}, opts) do
    with(
      :ok <-
        Enum.each(w_si_code, fn record ->
          case ExPrompt.confirm("SAVE to BASE?: #{record."Title_EN"} #{record.si_code}") do
            true -> save([record], opts)
            _ -> nil
          end
        end),
      :ok <-
        Enum.each(wo_si_code, fn record ->
          case ExPrompt.confirm("SAVE to BASE?: #{record."Title_EN"}") do
            true -> save([record], opts)
            _ -> nil
          end
        end),
      :ok <- save_exc(exc, opts)
    ) do
      :ok
    else
      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  def save(records, opts) do
    records =
      Legl.Utility.maps_from_structs(records)
      |> Legl.Utility.map_filter_out_empty_members()

    IO.puts("#{Enum.count(records)} to be POSTed to Airtable\n")

    opts = Map.merge(opts, %{drop_fields: @drop_fields, api_post_path: @api_post_path})
    Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord.run(records, opts)
  end

  @doc """
   Function to save to Airtable bare laws stored in exc.json
  """
  def save_bare_excluded(opts \\ [csv?: false, mute?: true]) do
    opts =
      Enum.into(opts, %{})
      |> Options.base_name()
      |> Options.base_table_id()
      |> Map.merge(%{
        api_patch_path: @api_patch_path,
        api_post_path: @api_post_path
      })

    %{records: records} = @exc_path |> File.read!() |> Jason.decode!(keys: :atoms)

    save_exc(records, opts)
  end

  defp save_exc(records, opts) do
    case ExPrompt.get("Enter ID number for any excluded laws to process and save: ") do
      "" ->
        IO.puts("EXIT")
        :ok

      id ->
        # IO.inspect(records, label: "EXC RECORDS: ")

        Map.get(records, :"#{id}")
        |> (&Kernel.struct(%LR{}, &1)).()
        |> (&[&1 | []]).()
        |> IO.inspect(label: "RECORD: ")
        |> complete_new_law_fields(@inc_path, opts)
        |> save(opts)

        save_exc(records, opts)
    end
  end

  @doc """
  Function to iterate results from legislation.gov.uk and match against
  type_code, Number and Year
  iex -> Legl.Countries.Uk.LeglRegister.New.New.find_publication_date()
  """
  def find_publication_date(opts \\ []) do
    opts =
      Enum.into(opts, %{})
      |> Options.base_name()
      |> Options.base_table_id()
      |> Options.type_code()
      |> Options.year()
      |> Options.month()
      |> Options.days()
      |> Options.number()

    {from, to} = opts.days

    Enum.reduce_while(from..to, [], fn day, acc ->
      with({:ok, records} <- LegGovUk.getNewLaws({day, day}, opts)) do
        case Enum.reduce_while(records, acc, fn
               %{type_code: type_code, Number: number, Year: year} = record, acc ->
                 IO.puts(
                   "#{number} #{opts.number}, #{type_code} #{opts.type_code}, #{year} #{opts.year}"
                 )

                 case number == opts.number and type_code == opts.type_code and
                        year == String.to_integer(opts.year) do
                   true -> {:halt, [record | acc]}
                   false -> {:cont, acc}
                 end
             end) do
          [] ->
            {:cont, acc}

          match ->
            # IO.inspect(match)
            {:halt, [match | acc]}
        end
      else
        {:error, msg} ->
          IO.puts("ERROR: #{msg}")
          {:cont, acc}
      end
    end)
  end

  @doc """
  Function to create a new law record for a Legal Register Base

  Source can
  """
  def workflow(%{source: :web} = opts) do
    with(
      {:ok, records} <- LegGovUk.getNewLaws(opts.days, opts),
      :ok = Legl.Utility.save_json(records, @source)
    ) do
      workflow(records, opts)
    else
      {:no_data, opts} -> {:no_data, opts}
      {:error, msg} -> {:error, msg}
    end
  end

  def workflow(records, opts) when is_list(records) do
    with(
      :ok = IO.puts("# PRE_FILTERED RECORDS: #{Enum.count(records)}"),
      # Filter each Law record based on terms in Title_EN
      {:ok, {inc, exc}} <- Filters.terms_filter(records, opts),
      :ok = IO.puts("Terms inside Title Filter"),
      :ok = IO.puts("# INCLUDED RECORDS: #{Enum.count(inc)}"),
      :ok = IO.puts("# EXCLUDED RECORDS: #{Enum.count(exc)}"),
      # IO.inspect(inc, label: "inc"),
      # IO.inspect(exc, label: "exc"),
      # Save Included records to file
      :ok =
        Legl.Utility.maps_from_structs(inc)
        |> Legl.Utility.save_json(@inc_path),
      # Save an indexed Excluded records .json
      exc =
        Legl.Utility.maps_from_structs(exc)
        |> index_exc(),
      :ok = Legl.Utility.save_json(exc, @exc_path),

      # Let's stop further workflow if we have filtered out all the records
      :ok <-
        if Enum.count(inc) == 0 and Enum.count(exc) == 0 do
          {:no_data, opts}
        else
          :ok
        end,

      # Add the SI Code(s) to each Law record
      # Those w/o SI Code 'inc_wo_si' list
      {:ok, {inc_w_si, inc_wo_si}} <- LegGovUk.get_si_code(inc),

      # Split Law records based on presence of an SI Code from our set
      # We end up with 3 sets:
      # 1. inc_w_si -> w/ SI Code and Term match
      # 2. inc_wo_si -> w/ only Term match
      # 3. ex -> neither SI Code or Term match
      {:ok, {inc_w_si, inc_wo_si}} <-
        Filters.si_code_filter({inc_w_si, inc_wo_si}),

      # Filter out laws that are already in the Base
      {:ok, inc_wo_si} <- Helper.filter_delta(inc_wo_si, opts),
      {:ok, inc_w_si} <- Helper.filter_delta(inc_w_si, opts),
      inc_w_si_count = Enum.count(inc_w_si),
      inc_wo_si_count = Enum.count(inc_wo_si),

      # Save the results to 2x .json files for manual QA
      :ok = IO.puts("# W/O SI CODE RECORDS: #{inc_w_si_count}"),
      :ok =
        Legl.Utility.maps_from_structs(inc_wo_si)
        |> Legl.Utility.save_json(@inc_wo_si_path),
      :ok = IO.puts("# W/ SI CODE RECORDS: #{inc_wo_si_count}"),
      :ok =
        Legl.Utility.maps_from_structs(inc_w_si)
        |> Legl.Utility.save_json(@inc_w_si_path)
    ) do
      # Returns a tuple
      inc_w_si =
        case inc_w_si_count do
          0 ->
            []

          _ ->
            IO.puts("\nPROCESSING LAWS MATCHING Terms and SI Code\n")
            complete_new_law_fields(inc_w_si, @inc_w_si_path, opts)
        end

      inc_wo_si =
        case inc_wo_si_count do
          0 ->
            []

          _ ->
            IO.puts("\nPROCESSING LAWS MATCHING Terms and NO MATCH SI Code\n")
            complete_new_law_fields(inc_wo_si, @inc_wo_si_path, opts)
        end

      {:ok, inc_w_si, inc_wo_si, exc}
    else
      {:no_data, opts} -> {:no_data, opts}
      {:error, msg} -> {:error, msg}
    end
  end

  def complete(%{source: :both} = opts) do
    %{records: inc_w_si} = @inc_w_si_path |> File.read!() |> Jason.decode!(keys: :atoms)
    %{records: inc_wo_si} = @inc_wo_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    {:ok, _records} =
      Map.merge(inc_w_si, inc_wo_si)
      |> complete_new_law_fields(@inc_path, opts)
  end

  def complete(%{source: :si_coded} = opts) do
    # Open previously saved records from file
    %{records: records} = @inc_w_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    complete_new_law_fields(records, @inc_path, opts)
  end

  def complete(%{source: :si_uncoded} = opts) do
    # Open previously saved records from file
    %{records: records} = @inc_wo_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    complete_new_law_fields(records, @inc_path, opts)
  end

  @doc """
  Receives a law Record with at least :Number, :type_code and :Year fields,
  a path to save the record as json, and opts and returns a Record for PATCH or POST

  Enacted_by, Amended_by, Revoked_by are overwritten if they exist.
  """
  @spec update_empty_law_fields(map(), binary(), map()) :: map()
  def update_empty_law_fields(record, path, opts) when is_map(record) do
    records = [record]

    with(
      # Metadata fields
      IO.write("METADATA"),
      records = Create.set_metadata(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # type_class field
      IO.write("TYPE CLASS"),
      records = Create.set_type_class(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Type field
      IO.write("TYPE"),
      records = Create.set_type(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Tags field
      IO.write("TAGS"),
      records = Create.set_tags(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Name field
      IO.write("NAME"),
      records = Create.set_name(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Extent fields
      IO.write("EXTENT"),
      records = Create.set_extent(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Enacted by fields
      IO.puts("ENACTED BY"),
      records = Create.set_enacted_by(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Amended by fields
      IO.puts("AMENDED BY"),
      records = Create.set_amended_by(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Revoked by fields
      IO.puts("REVOKED BY"),
      records = Create.set_revoked_by(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete")
    ) do
      # Take the record out of the list to return map
      List.first(records)
    end
  end

  def complete_new_law_fields(records, path, opts) do
    with(
      # Year field
      IO.write("YEAR"),
      records = Create.set_year(records),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Metadata fields
      IO.write("METADATA"),
      records = Create.set_metadata(records),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Publication Date field
      if Map.has_key?(opts, :record_ids) do
        IO.write("PUBLICATION DATE")
        records = Create.setPublicationDateLink(records, opts)
        :ok = Legl.Utility.save_structs_as_json(records, path)
        IO.puts("...complete")
      end,

      # Name field
      IO.write("NAME"),
      records = Create.set_name(records),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # type_class field
      IO.write("TYPE CLASS"),
      records = Create.set_type_class(records),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Type field
      IO.write("TYPE"),
      records = Create.set_type(records),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Tags field
      IO.write("TAGS"),
      records = Create.set_tags(records),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Extent fields
      IO.write("EXTENT"),
      records = Create.set_extent(records),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Enacted by fields
      IO.puts("ENACTED BY"),
      records = Create.set_enacted_by(records, opts),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Amended by fields
      IO.puts("AMENDED BY"),
      records = Create.set_amended_by(records, opts),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete"),

      # Revoked by fields
      IO.puts("REVOKED BY"),
      records = Create.set_revoked_by(records, opts),
      :ok = Legl.Utility.save_structs_as_json(records, path),
      IO.puts("...complete")
    ) do
      records
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
