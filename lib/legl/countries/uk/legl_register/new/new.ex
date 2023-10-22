defmodule Legl.Countries.Uk.LeglRegister.New.New do
  @moduledoc """
  Module to obtain new laws from legislation.gov.uk and POST to Airtable

  """
  alias Legl.Countries.Uk.LeglRegister.New.New.Options
  alias Legl.Countries.Uk.LeglRegister.New.New.Airtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.New.New.LegGovUk
  alias Legl.Countries.Uk.LeglRegister.New.New.Filters
  alias Legl.Countries.Uk.LeglRegister.New.New.PublicationDateTable, as: PDT
  alias Legl.Countries.Uk.LeglRegister.Helpers.NewLaw
  alias Legl.Countries.Uk.LeglRegister.New.Create

  @source ~s[lib/legl/countries/uk/legl_register/new/source.json]
  @api_path ~s[lib/legl/countries/uk/legl_register/new/api.json]
  @exc_path ~s[lib/legl/countries/uk/legl_register/new/exc.json]
  @inc_wo_si_path ~s[lib/legl/countries/uk/legl_register/new/inc_wo_si.json]
  @inc_w_si_path ~s[lib/legl/countries/uk/legl_register/new/inc_w_si.json]
  @inc_path ~s[lib/legl/countries/uk/legl_register/new/inc.json]

  @drop_fields ~w[changes_path
    enacting_laws
    enacting_text
    introductory_text
    Name
    text
    urls]a

  @doc """
  Function to set the options, route the workflow to either get records from
  legislation.gov.uk or .json, and POST to Airtable

  Run in the terminal with
  Legl.Countries.Uk.LeglRegister.New.New.run()
  Settings:
    1. OPTIONS base_name has to be set to either "UK E" or "UK S"
  """
  def run(opts \\ []) do
    with(
      {:ok, opts} <- Options.setOptions(opts),
      {:ok, w_si_code, wo_si_code} <-
        cond do
          opts.source == :web ->
            workflow(opts)

          true ->
            %{records: records} = @inc_path |> File.read!() |> Jason.decode!(keys: :atoms)
            records
        end,
      :ok <-
        Enum.each(w_si_code, fn record ->
          case ExPrompt.confirm("SAVE to BASE?: #{record[:Title_EN]} #{record[:"SI Code"]}") do
            true -> save([record], opts)
            _ -> nil
          end
        end),
      :ok <-
        Enum.each(wo_si_code, fn record ->
          case ExPrompt.confirm("SAVE to BASE?: #{record[:Title_EN]}") do
            true -> save([record], opts)
            _ -> nil
          end
        end),

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

  defp save(records, opts) do
    IO.puts("#{Enum.count(records)} to be POSTed to Airtable\n")
    opts = Map.merge(opts, %{drop_fields: @drop_fields, api_path: @api_path})
    Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord.run(records, opts)
  end

  @doc """
  Function to create a new law record for a Legal Register Base
  """
  def workflow(%{source: :web} = opts) do
    with(
      {:ok, records} <- LegGovUk.getNewLaws(opts),
      :ok = Legl.Utility.save_json(records, @source),

      # Filter each Law record based on terms in Title_EN
      {:ok, {inc, exc}} <- Filters.terms_filter(records, opts),
      :ok = IO.puts("# RECORDS: #{Enum.count(records)}"),
      :ok = IO.puts("# EXCLUDED RECORDS: #{Enum.count(exc)}"),
      :ok = Legl.Utility.save_json(exc, @exc_path),

      # Let's stop further workflow if we have filtered out all the records
      :ok <-
        if Enum.count(inc) == 0 do
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
      {:ok, {inc_w_si, inc_wo_si}} <- Filters.si_code_filter({inc_w_si, inc_wo_si}),

      # Filter out laws that are already in the Base
      {:ok, inc_wo_si} <- NewLaw.filterDelta(inc_wo_si, opts),
      {:ok, inc_w_si} <- NewLaw.filterDelta(inc_w_si, opts),

      # Save the results to 3x .json files for manual QA
      :ok = IO.puts("# W/O SI CODE RECORDS: #{Enum.count(inc_wo_si)}"),
      :ok = Legl.Utility.save_json(inc_wo_si, @inc_wo_si_path),
      :ok = IO.puts("# W/ SI CODE RECORDS: #{Enum.count(inc_w_si)}"),
      :ok = Legl.Utility.save_json(inc_w_si, @inc_w_si_path)
    ) do
      # Returns a tuple
      IO.puts("\nPROCESSING LAWS MATCHING Terms and SI Code")
      inc_w_si = complete_new_law_fields(inc_w_si, @inc_w_si_path, opts)
      IO.puts("\nPROCESSING LAWS MATCHING Terms and NO MATCH SI Code")
      inc_wo_si = complete_new_law_fields(inc_wo_si, @inc_wo_si_path, opts)
      {:ok, inc_w_si, inc_wo_si}
    else
      {:no_data, opts} -> {:no_data, opts}
      {:error, msg} -> {:error, msg}
    end
  end

  def workflow(%{source: :both} = opts) do
    %{records: inc_w_si} = @inc_w_si_path |> File.read!() |> Jason.decode!(keys: :atoms)
    %{records: inc_wo_si} = @inc_wo_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    {:ok, _records} =
      Map.merge(inc_w_si, inc_wo_si)
      |> complete_new_law_fields(@inc_path, opts)
  end

  def workflow(%{source: :si_coded} = opts) do
    # Open previously saved records from file
    %{records: records} = @inc_w_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    complete_new_law_fields(records, @inc_path, opts)
  end

  def workflow(%{source: :si_uncoded} = opts) do
    # Open previously saved records from file
    %{records: records} = @inc_wo_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    complete_new_law_fields(records, @inc_path, opts)
  end

  def complete_new_law_fields(records, path, opts) do
    with(
      # Name field
      IO.write("NAME"),
      records = Create.setName(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # type_class field
      IO.write("TYPE CLASS"),
      records = Create.setTypeClass(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Tags field
      IO.write("TAGS"),
      records = Create.setTags(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Metadata fields
      IO.puts("METADATA"),
      records = Create.setMetadata(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Extent fields
      IO.write("EXTENT"),
      records = Create.setExtent(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Enacted by fields
      IO.write("ENACTED BY"),
      records = Create.setEnactedBy(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Amended by fields
      IO.puts("AMENDED BY"),
      records = Create.setAmendedBy(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete"),

      # Revoked by fields
      IO.puts("REVOKED BY"),
      records = Create.setRevokedBy(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("...complete")
    ) do
      records
    end
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.Options do
  alias Legl.Services.Airtable.AtBasesTables

  @default_opts %{
    base_name: "UK S",
    table_name: "Publication Date",
    type_code: [""],
    year: 2023,
    month: nil,
    day: nil,
    # days as a tuple {from, to} eg {10, 23} for days from 10th to 23rd
    days: nil,
    # Where's the data coming from?
    source: :web,
    # Trigger .csv saving?
    csv?: false
  }

  def setOptions(opts) do
    opts = Enum.into(opts, @default_opts)

    opts =
      Map.put(
        opts,
        :base_name,
        case ExPrompt.choose("Choose Base", ["HEALTH & SAFETY", "ENVIRONMENT"]) do
          0 ->
            "UK S"

          1 ->
            "UK E"
        end
      )

    opts =
      Map.put(
        opts,
        :source,
        case ExPrompt.choose("Source Records", [
               "legislation.gov.uk",
               "w/ si code",
               "w/o si code",
               "w/ & w/o si code"
             ]) do
          0 -> :web
          1 -> :si_code
          2 -> :x_si_code
          3 -> :both
        end
      )

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)

    {:ok, {_base_id, pub_table_id}} =
      AtBasesTables.get_base_table_id(opts.base_name, opts.table_name)

    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id, pub_table_id: pub_table_id})

    opts =
      with {:ok, f} <- formula(opts) do
        Map.put(opts, :formula, f)
      else
        {:error, msg} -> {:error, msg}
      end

    IO.puts("OPTIONS: #{inspect(opts)}")
    {:ok, opts}
  end

  defp formula(%{source: :web} = opts) do
    with(
      f = [~s/{Year}="#{opts.year}"/],
      {:ok, f} <-
        if(opts.month != nil,
          do: {:ok, [~s/{Month}="#{opts.month}"/ | f]},
          else: {:error, "Month option required e.g. month: 04"}
        ),
      f = if(opts.day != nil, do: [~s/{Day}="#{opts.day}"/ | f], else: f),
      f = if({from, to} = opts.days, do: [~s/{Day}>="#{from}", {Day}<="#{to}"/ | f])
    ) do
      {:ok, ~s/AND(#{Enum.join(f, ",")})/}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp formula(_), do: {:ok, nil}
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.Airtable do
  alias Legl.Services.Airtable.UkAirtable, as: AT

  def getDates(opts) do
    {:ok, records} = AT.get_records_from_at(opts)
    Jason.encode!(records) |> Jason.decode!(keys: :atoms)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.LegGovUk do
  alias Legl.Services.LegislationGovUk.RecordGeneric, as: LegGovUk
  alias(Legl.Countries.Uk.LeglRegister.Metadata.UkSiCode, as: SI)

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.new_law_parser/1

  def getNewLaws(%{days: {from, to}} = opts) when is_integer(from) and is_integer(to) do
    Enum.reduce(from..to, [], fn day, acc ->
      opts = Map.put(opts, :date, ~s<#{opts.year}-#{opts.month}-#{day}>)

      with({:ok, response} <- getLaws(opts)) do
        Enum.reduce(response, acc, fn law, acc2 ->
          Map.put(law, :publication_date, opts.date)
          |> (&[&1 | acc2]).()
        end)
      else
        {:error, 307} -> acc
        {:error, 404} -> acc
      end
    end)
    |> (&{:ok, &1}).()
  end

  def getLaws(opts) do
    with(
      url = url(opts),
      :ok = IO.puts("\n#{url}\n#{__MODULE__}.getLaws"),
      {:ok, response} <- LegGovUk.leg_gov_uk_html(url, @client, @parser)
    ) do
      {:ok, response}
    else
      {:error, 307, msg, "Other response code"} ->
        IO.puts("CODE: 307 - temporary redirect from leg.gov.uk for #{msg}")
        {:error, 307}

      {:error, 404, msg, _} ->
        IO.puts("CODE: 404 - no records returned from leg.gov.uk for #{msg}")
        {:error, 404}

      {:error, msg} ->
        {:error, msg}
    end
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
            SI.resource_path({law.type_code, Integer.to_string(law[:Year]), law[:Number]}),
          {:ok, si_code} <- SI.get_si_code(url)
        ) do
          case si_code do
            x when x in [nil, "", []] ->
              {ninc, [law | nexc]}

            _ ->
              law = Map.put(law, :"SI Code", si_code)
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

defmodule Legl.Countries.Uk.LeglRegister.New.New.Filters do
  # alias Legl.Countries.Uk.UkSearch.Terms
  alias Legl.Countries.Uk.UkSearch.Terms.HealthSafety, as: HS
  alias Legl.Countries.Uk.UkSearch.Terms.Environment, as: E
  alias Legl.Countries.Uk.UkSearch.Terms.SICodes

  @hs_search_terms HS.hs_search_terms()
  @e_search_terms E.e_search_terms()

  def si_code_filter({inc_w_si, inc_wo_si}) do
    Enum.reduce(inc_w_si, {[], inc_wo_si}, fn
      %{"SI Code": si_codes} = law, {inc, exc} ->
        case si_code_member?(si_codes) do
          true -> {[law | inc], exc}
          _ -> {inc, [law | exc]}
        end

      # Acts and some regs don't have SI Codes
      law, {inc, exc} ->
        {[law | inc], exc}
    end)
    |> (&{:ok, &1}).()
  end

  def si_code_member?(si_code) when is_binary(si_code),
    do: MapSet.member?(SICodes.si_codes(), si_code)

  def si_code_member?(si_codes) when is_list(si_codes) do
    Enum.reduce_while(si_codes, false, fn si_code, _acc ->
      case MapSet.member?(SICodes.si_codes(), si_code) do
        true -> {:halt, true}
        _ -> {:cont, false}
      end
    end)
  end

  def terms_filter(laws, opts) do
    search_terms =
      case opts.base_name do
        "UK S" -> @hs_search_terms
        "UK E" -> @e_search_terms
      end

    Enum.reduce(laws, {[], []}, fn law, {inc, exc} ->
      title = String.downcase(law[:Title_EN])

      match? =
        Enum.reduce_while(search_terms, false, fn {k, n}, _acc ->
          # n = :binary.compile_pattern(v)

          case String.contains?(title, n) do
            true -> {:halt, {true, k}}
            false -> {:cont, false}
          end
        end)

      case match? do
        {true, k} ->
          Map.put(law, :Family, Atom.to_string(k))
          |> (&{[&1 | inc], exc}).()

        false ->
          {inc, [law | exc]}
      end
    end)
    |> (&{:ok, &1}).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.PublicationDateTable do
  @moduledoc """
  Module to PATCH an update to mark all records that have been processed
  Fields: 'Checked?'
  """
  alias Legl.Services.Airtable.Client

  def field_checked?(opts) do
    # set Publication Date table credentials
    opts =
      case opts.base_name do
        "UK S" -> Map.merge(opts, %{pd_base: "appRhQoz94zyVh2LR", pd_table: "tblhclH8AyopZ5t73"})
        "UK E" -> nil
      end

    get_publication_date_table_records(opts)
    |> patch_to_field_checked(opts)
  end

  def get_publication_date_table_records(opts) do
    opts =
      case opts.base_name do
        "UK S" -> Map.merge(opts, %{pd_base: "appRe94r8wBTgGlUs", pd_table: "tbl6sqDsiCFfOkTNk"})
        "UK E" -> nil
      end

    {:ok, url} =
      Legl.Services.Airtable.Url.url(opts.pd_base, opts.pd_table,
        formula: opts.formula,
        fields: ["Name"]
      )

    {:ok, data} = Client.request(:get, url, [])
    %{records: records} = Jason.decode!(data, keys: :atoms)
    records
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
      base: opts.pd_base,
      table: opts.pd_table,
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

  def make_list_of_dates(%{days: {from, to}, month: month, year: year} = _opts)
      when is_integer(from) and is_integer(to) do
    Enum.map(from..to, fn d ->
      # d = if String.length(Integer.to_string(d)) == 2, do: d, else: ~s/0#{d}/
      {:ok, date} = Date.new(year, month, d)
      date
      # ~s/#{year}-#{month}-#{d}/
    end)
  end
end
