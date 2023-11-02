defmodule Legl.Countries.Uk.LeglRegister.Amend do
  @moduledoc """
    iex instructions
    1. Copy Name, Title_EN, type, year, number from AT into original.txt
    2. Legl.Countries.Uk.UkAmendClient.amendment_bfs_client()
    3. csv import from amending.csv

    To run against a single record

    Legl.Countries.Uk.LeglRegister.Amend.UkAmendClient.run(base_name: "UK S",
    name: "UK_uksi_2002_2677_CSHHR", new?: false, filesave?: true, view: "")

    To run and select those records w/o a full set of amending laws use percent?:

    Legl.Countries.Uk.LeglRegister.Amend.UkAmendClient.run(base_name: "UK S",
    sClass: "Occupational / Personal Safety", percent?: true, type_class:
    :regulation, type_code: :uksi, new?: false, filesave?: true, view: "")


  """
  alias Legl.Countries.Uk.LeglRegister.IdField
  alias Legl.Airtable.AirtableTitleField
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Services.LegislationGovUk.Url

  alias Legl.Countries.Uk.LeglRegister.Amend.Delta
  alias Legl.Countries.Uk.LeglRegister.Amend.Csv
  alias Legl.Countries.Uk.LeglRegister.Amend.Patch
  alias Legl.Countries.Uk.LeglRegister.Amend.NewLaw

  @amended_fields_list ~s[
    Name
    Title_EN
    type_code
    Year
    Number
    amendments_checked
    Amended_by
    leg_gov_uk_updates
    stats_self_amending_count
    stats_amending_laws_count
    stats_amendments_count
    stats_amendments_count_per_law
    amended_by_change_log
  ] |> String.split()

  @amended_fields_atoms_list Enum.map(@amended_fields_list, &String.to_atom(&1))

  @amended_fields @amended_fields_list |> Enum.join(",")

  def amended_fields_list(), do: @amended_fields_list
  def amended_fields(), do: @amended_fields

  @default_opts %{
    name: "",
    # workflow options are [:create, :update]
    # :update triggers the update workflow and populates the change log
    workflow: :create,
    base_name: "UK E",
    # type_code as an atom eg :ukpga
    type_code: [""],
    type_class: "",
    sClass: "",
    family: "",
    percent?: false,
    filesave?: false,
    # include/exclude AT records holding today's date
    today?: false,
    # patch? only works with :update workflow
    patch?: false,
    # getting existing field data from Airtable
    view: "VS_CODE_AMENDMENT",
    # saving to csv?
    csv?: false
  }

  @enumeration_limit 2

  @doc """
  Function sets the optional parameters and gets one or more type_class codes
  which are used to get records from the AT Legal Register
  """
  def run(opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})

    with {:ok, type_codes} <- Legl.Countries.Uk.UkTypeCode.type_code(opts.type_code),
         {:ok, type_classes} <- Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class),
         {:ok, sClass} <- Legl.Countries.Uk.SClass.sClass(opts.sClass),
         {:ok, family} <- Legl.Countries.Uk.Family.family(opts.family),
         opts =
           Map.merge(opts, %{
             type_code: type_codes,
             type_class: type_classes,
             sClass: sClass,
             family: family
           }) do
      Enum.each(type_codes, fn type ->
        IO.puts(">>>#{type}")

        fields = fields(opts)
        formula = formula(type, opts)

        opts = Map.put(opts, :fields, fields)
        opts = Map.put(opts, :formula, formula)

        opts = if(opts.csv?, do: Map.put(opts, :file, Csv.openCSVfile()), else: opts)

        IO.puts("AT FIELDS: #{inspect(fields)}")
        IO.puts("AT FORMULA: #{formula}")
        IO.puts("OPTIONS: #{inspect(opts)}")

        workflow(opts)
      end)

      if(opts.csv?, do: File.close(opts.file))
    else
      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  def fields(%{workflow: :create} = _opts),
    do: ["Name", "Title_EN", "type_code", "Year", "Number"]

  def fields(%{workflow: :update} = _opts), do: @amended_fields_list

  def formula(type, %{name: ""} = opts) do
    f =
      cond do
        opts.workflow == :create and opts.today? == true ->
          [~s/OR({amendments_checked}=BLANK(), {amendments_checked}=TODAY())/]

        opts.workflow == :create ->
          [~s/{amendments_checked}=BLANK()/]

        opts.today? == false ->
          [~s/{amendments_checked}!=TODAY()/]

        true ->
          []
      end

    f = if opts.type_code != [""], do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f

    f =
      if opts.percent? != false,
        do: [~s/{% amending law in Base}<"1",{stats_amending_laws_count}>"0"/ | f],
        else: f

    f =
      if opts.family != "",
        do: [~s/{Family}="#{opts.family}"/ | f],
        else: f

    f =
      if opts.sClass != "",
        do: [~s/{sClass}="#{opts.sClass}"/ | f],
        else: f

    ~s/AND(#{Enum.join(f, ",")})/
  end

  def formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end

  def workflow(opts) do
    with(
      {:ok, records} <-
        AT.get_records_from_at(opts),
      records =
        Jason.encode!(records)
        |> Jason.decode!(keys: :atoms)
      # |> IO.inspect(label: "CURRENT RECORDS:")
    ) do
      results = amendment_bfs({[], paths(records)}, opts, 0)

      # IO.inspect(latest_records, label: "LATEST RECORDS:")

      cond do
        opts.workflow == :create ->
          Patch.patch(results, opts)

        opts.workflow == :update ->
          Delta.compare(results)
          # |> IO.inspect()
          |> Patch.patch(opts)
      end

      if opts.csv?, do: Csv.records_to_csv(results)
    end
  end

  def workflow(records, opts) when is_list(records) do
    results = amendment_bfs({[], paths(records)}, opts, 0)

    if opts.csv?, do: Csv.records_to_csv(results)

    results
  end

  def workflow(record, opts) when is_map(record) do
    # Function to process a single piece of law
    workflow([record], opts)
  end

  @doc """

  """
  def paths(record) when is_map(record), do: paths([record])

  def paths(records) when is_list(records) do
    Enum.map(records, fn
      %{
        Name: _name,
        Number: number,
        Title_EN: _title,
        type_code: type_code,
        Year: year
      } = record ->
        Map.put(record, :changes_path, Url.changes_path(type_code, year, number))
    end)
  end

  def paths(amended_by_laws, nlinks) do
    Enum.reduce(amended_by_laws, nlinks, fn [
                                              name,
                                              _title,
                                              amending_title,
                                              _path,
                                              type,
                                              year,
                                              number,
                                              _applied?
                                            ],
                                            acc ->
      MapSet.put(acc, {name, amending_title, Url.changes_path(type, year, number)})
    end)
  end

  @doc """
    Breadth first search up to an arbitrary number of layers of the amendments tree
    results -> is a list of the Airtable records that get saved as a .csv for upload
    links -> is a list of the links to be followed to get more amendments

    Airtable field names are prefixed 'at_'

    csv row structure
    [
      at_name,
      at_title_en,
      at_type,
      at_year,
      at_number,
      at_amendments_checked,
      at_amended_by,
      at_leg_gov_uk_updates,
      at_stats_self_amending_count,
      at_stats_amending_laws_count,
      at_stats_amendments_count,
      at_stats_amendments_count_per_law
    ]
  """
  def amendment_bfs(data, _, @enumeration_limit), do: data

  def amendment_bfs({results, records}, opts, enumeration_limit) do
    IO.puts("\nEnumeration #{enumeration_limit}")

    case Enum.count(records) == 0 do
      true ->
        results

      false ->
        case ExPrompt.confirm(
               "There are #{Enum.count(records)} laws in this iteration.  Continue?"
             ) or
               @enumeration_limit == 0 do
          false ->
            # IO.inspect(results)
            results

          true ->
            enumeration_limit = enumeration_limit + 1

            if opts.csv?, do: IO.puts(opts.file, "ENUMERATION #{enumeration_limit}")

            {nresults, nrecords} =
              Enum.reduce(records, {results, []}, fn
                record, {nresults, nrecords} ->
                  IO.puts(
                    "title-> #{record[:Title_EN]} #{record[:Year]} #{record[:type_code]} #{record[:Number]}"
                  )

                  # call to legislation.gov.uk to get the amendments
                  {:ok, stats, amended_by_laws} = Record.amendments_table(record[:changes_path])
                  # |> IO.inspect(label: "response")

                  # IO.inspect(amended_by_laws)

                  # enumerate the amendments of the law to get the 'Amended_By'
                  # field's comma seperated string of ids save into the results list

                  case amended_by_laws do
                    [] ->
                      amendment_fields = %{
                        amendments_checked: ~s/#{Date.utc_today()}/,
                        Amended_by: "",
                        leg_gov_uk_updates: "",
                        stats_self_amending_count: 0,
                        stats_amending_laws_count: 0,
                        stats_amendments_count: 0,
                        stats_amendments_count_per_law: ""
                      }

                      record = Map.merge(record, amendment_fields)

                      if opts.csv?, do: Enum.join(record, ",") |> (&IO.puts(opts.file, &1)).()

                      {[record | nresults], nrecords}

                    _ ->
                      amendment_fields = %{
                        amendments_checked: ~s/#{Date.utc_today()}/,
                        Amended_by: at_amended_by(amended_by_laws),
                        leg_gov_uk_updates: at_leg_gov_uk_updates(amended_by_laws),
                        stats_self_amending_count: stats.self,
                        stats_amending_laws_count: count_amending_laws(amended_by_laws),
                        stats_amendments_count: stats.amendments,
                        stats_amendments_count_per_law: stats.counts
                      }

                      record = Map.merge(record, amendment_fields)

                      # here we can process the record for each separate law
                      # Patch.patch([record], opts)
                      if opts.csv?, do: Enum.join(record, ",") |> (&IO.puts(opts.file, &1)).()

                      nresults = [record | nresults]

                      nrecords =
                        Enum.reduce(amended_by_laws, nrecords, fn
                          [
                            _title,
                            amending_title,
                            _path,
                            type_code,
                            year,
                            number,
                            _applied?
                          ],
                          acc ->
                            %{
                              changes_path: Url.changes_path(type_code, year, number),
                              Name: IdField.id(amending_title, type_code, year, number),
                              Number: number,
                              Title_EN: AirtableTitleField.title_clean(amending_title),
                              type_code: type_code,
                              Year: year
                            }
                            |> (&[&1 | acc]).()
                        end)

                      # IO.inspect(nlinks)
                      # IO.inspect(nresults)
                      {nresults, nrecords}
                  end
              end)

            # IO.inspect(nlinks, limit: :infinity)
            # IO.inspect(nresults, limit: :infinity)

            if nrecords != [] do
              # Remove new records (nrecords) that are already in the BASE
              nrecords =
                with(
                  {:ok, nrecords} <-
                    Legl.Countries.Uk.LeglRegister.Helpers.Create.filterDelta(nrecords, opts)
                ) do
                  nrecords
                else
                  {:error, msg} ->
                    IO.puts("ERROR: #{msg}\n")
                    nrecords
                end

              # Let's not process new records (nrecords) that are in nresults
              nrecords =
                Enum.reduce(nrecords, [], fn %{Name: name} = nrecord, acc ->
                  case Enum.any?(nresults, fn %{Name: name_} -> name_ == name end) do
                    true -> acc
                    false -> [nrecord | acc]
                  end
                end)

              # Capture details of new laws for the Base in json for later processing

              json_path =
                ~s[lib/legl/countries/uk/legl_register/amend/newlaws_enumeration#{enumeration_limit - 1}.json]

              Map.put(%{}, "records", nrecords)
              |> Jason.encode!()
              |> Legl.Utility.save_at_records_to_file(json_path)
            end

            # IO.inspect(nlinks, limit: :infinity)

            amendment_bfs({nresults, nrecords}, opts, enumeration_limit)
        end
    end
  end

  @doc """
    Content of the Airtable Amended_By field.
    A comma separated list within quote marks of the Airtable ID field (Name).
    "UK_ukpga_2010_41_abcd,UK_uksi_2013_57_abcd"
  """
  def at_amended_by(amended_by_laws) do
    Enum.map(amended_by_laws, fn [_title, amending_title, _path, type, year, number, _applied?] ->
      IdField.id(amending_title, type, year, number)
    end)
    |> Enum.sort()

    # |> Enum.join(", ")
    # |> Legl.Utility.csv_quote_enclosure()
  end

  @doc """
    Content of the Airtable leg_gov_uk_updates field
    A comma separated list of options that are transformed into multi-select options.
    "Yes, No, See Notes"
  """
  def at_leg_gov_uk_updates(amended_by_laws) do
    Enum.flat_map(amended_by_laws, fn [
                                        _title,
                                        _amending_title,
                                        _path,
                                        _type,
                                        _year,
                                        _number,
                                        applied?
                                      ] ->
      applied?
    end)
    |> Enum.uniq()
    |> Enum.join(",")

    # |> Legl.Utility.csv_quote_enclosure()
  end

  defmodule AmendmentStats do
    defstruct [:self, :laws, :amendments, :counts]
  end

  def pre_uniq_summary_amendment_stats(records) do
    stats =
      count_amendments(records)
      |> (&%{%AmendmentStats{} | amendments: &1}).()

    stats =
      count_self_amendments(records)
      |> (&%{stats | self: &1}).()

    stats =
      amendment_ids(records)
      |> count_amendments_for_each_law(records)
      |> (&%{stats | counts: &1}).()

    counts = at_stats_amendments_count_per_law(stats)

    %{stats | counts: counts}
  end

  @doc """
    <name> <count>
    <anme> <count>
  """
  def at_stats_amendments_count_per_law(nil), do: "no amendments"

  def at_stats_amendments_count_per_law(%{counts: []} = _stats), do: "no amendments"

  def at_stats_amendments_count_per_law(stats) do
    # IO.inspect(stats, label: "at_stats_amendments_count_per_law")

    # counts =
    Enum.map(stats.counts, fn {linked_record_name, count} ->
      "#{linked_record_name} - #{count}"
    end)
    |> Enum.sort()
    |> Enum.join("💚️")

    # Legl.Utility.csv_quote_enclosure(counts)
  end

  def amendment_ids(records) do
    uniq_by_amending_title(records)
    |> Enum.map(fn [_, amending_title, _, type, year, number, _] ->
      IdField.id(amending_title, type, year, number)
    end)
  end

  def count_self_amendments(records) do
    Enum.reduce(records, 0, fn [title, amending_title, _, _, _, _, _], acc ->
      if title == amending_title do
        acc + 1
      else
        acc
      end
    end)
  end

  def count_amendments(records) do
    Enum.count(records)
  end

  def count_amending_laws(records) do
    uniq_by_amending_title(records)
    |> Enum.count()
  end

  def count_amendments_for_each_law(ids, records) do
    counts =
      group_by_amending_title(records)
      |> Enum.map(fn x ->
        Enum.count(x)
      end)

    Enum.zip(ids, counts)
    # sort descending using the value of count
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  def uniq_by_amending_title(records) do
    Enum.uniq_by(
      records,
      fn [_title, amending_title, _path, _type, _year, _number, _applied?] -> amending_title end
    )
  end

  def group_by_amending_title(records) do
    # create a list of the uniq titles in the records
    uniq_titles = uniq_by_amending_title(records)

    Enum.map(uniq_titles, fn [_title, amending_title, _path, _type, _year, _number, _applied?] ->
      Enum.reduce(records, [], fn [
                                    _title,
                                    amending_title2,
                                    _path,
                                    _type,
                                    _year,
                                    _number,
                                    _applied?
                                  ] = x,
                                  acc ->
        if amending_title == amending_title2 do
          [x | acc]
        else
          acc
        end
      end)
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Patch do
  @api_results_path ~s[lib/legl/countries/uk/legl_register/amend/api_patch_results.json]
  def patch([], _), do: :ok

  def patch(records, opts) do
    IO.write("PATCH bulk - ")
    records = clean_records_for_patch(records, opts)

    json = Map.put(%{}, "records", records) |> Jason.encode!()
    Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_results_path)

    process(records, opts)
  end

  defp process(results, %{patch?: true} = opts) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    results =
      Enum.chunk_every(results, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.put(%{}, "records", set)
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(results, fn result_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(result_subset, headers, params)
    end)
  end

  defp process(_, _), do: :ok

  # defp clean_records_for_patch(records, %{workflow: :create} = _opts), do: records

  defp clean_records_for_patch(records, _opts) do
    Enum.map(records, fn record ->
      # IO.inspect(record)

      clean(record)
    end)
  end

  defp clean(%{fields: %{Amended_by: amended_by} = fields} = record) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code
    ])
    |> Map.put(:Amended_by, Enum.join(amended_by, ", "))
    |> (&Map.put(record, :fields, &1)).()
  end

  defp clean(record), do: record
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Post do
  @api_results_path ~s[lib/legl/countries/uk/legl_register/amend/api_post_results.json]
  def post([], _), do: :ok

  def post(records, opts) do
    IO.write("POST record - ")
    records = clean_records_for_post(records)

    json = Map.put(%{}, "records", records) |> Jason.encode!()
    Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_results_path)

    process(records, opts)
  end

  defp process(records, opts) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    records =
      Enum.chunk_every(records, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.put(%{}, "records", set)
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(records, fn subset ->
      Legl.Services.Airtable.AtPost.post_records(subset, headers, params)
    end)
  end

  defp clean_records_for_post(records) do
    Enum.map(records, fn %{fields: fields} = _record ->
      fields =
        Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
        |> Map.drop([:Name])
        |> (&Map.put(&1, :Year, String.to_integer(Map.get(&1, :Year)))).()

      case Map.get(fields, :Amended_by) do
        nil ->
          Map.put(%{}, :fields, fields)

        value ->
          Enum.join(value, ", ")
          |> (&Map.replace(fields, :Amended_by, &1)).()
          |> (&Map.put(%{}, :fields, &1)).()
      end
    end)

    # |> IO.inspect(label: "CLEAN: ")
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Delta do
  @moduledoc """
  Module compares the content of the following fields against the latest data @leg.gov.uk
  stats_amendments_count
  stats_amending_laws_count
  stats_amendments_count_per_law

  Generates a amended_by_change_log field to capture the differences
  """
  alias Legl.Countries.Uk.LeglRegister.Amend

  @field_paddings %{
    :Amended_by => 10,
    :leg_gov_uk_updates => 10,
    :stats_self_amending_count => 10,
    :amended_by_change_log => 10,
    :stats_amendments_count => 10,
    :stats_amending_laws_count => 8,
    :stats_amendments_count_per_law => 6
  }
  # TODO stats_amendments_count_per_law needs to find the changes within the list
  @compare_fields ~w[
    Amended_by
    leg_gov_uk_updates
    stats_amendments_count
    stats_amending_laws_count
    stats_self_amending_count
    ] |> Enum.map(&String.to_atom(&1))

  def compare(records) do
    records
    # |> IO.inspect(label: "data for compare")
    |> Enum.map(fn {current, latest} ->
      current = %{current | fields: Map.put_new(current.fields, :amended_by_change_log, "")}
      latest = %{latest | fields: Map.put_new(latest.fields, :amended_by_change_log, "")}
      {current, latest}
    end)
    |> Enum.reduce([], fn {current, latest}, acc ->
      latest_amended_by_change_log = compare_fields(current.fields, latest.fields)
      date = ~s/#{Date.utc_today()}/
      # if there is a change to the amended_by_change_log then keep latest record
      case compare_amended_by_change_log(
             current.fields.amended_by_change_log,
             latest_amended_by_change_log
           ) do
        nil ->
          current
          |> Map.drop([:createdTime, :fields])
          |> Map.put(:fields, %{amendments_checked: date})
          |> (&[&1 | acc]).()

        _ ->
          fields = %{
            latest.fields
            | amended_by_change_log: latest_amended_by_change_log,
              amendments_checked: date
          }

          [%{latest | fields: fields} | acc]
      end
    end)

    # |> IO.inspect()
  end

  def compare_fields(current_fields, latest_fields) do
    Enum.reduce(@compare_fields, [], fn field, acc ->
      current = Map.get(current_fields, field)
      latest = Map.get(latest_fields, field)

      cond do
        # find the Delta between the lists
        field == :Amended_by ->
          current =
            cond do
              is_binary(current) ->
                String.split(current, ",")
                |> Enum.map(&String.trim(&1))
                |> Enum.sort()

              current == nil ->
                []

              true ->
                current
                |> Enum.sort()
            end

          latest = Enum.sort(latest)

          # IO.puts("CURRENT:\n#{inspect(current)}\nLATEST:\n#{inspect(latest)}")
          # IO.puts("DIFF: #{inspect(latest -- current)}")

          case latest -- current do
            [] ->
              acc

            values ->
              IO.puts(
                "NAME: #{current_fields."Title_EN"} #{current_fields."Year"}\nDIFF: #{inspect(values, limit: :infinity)}"
              )

              values
              |> Enum.sort()
              |> Enum.join("📌")
              |> (&Keyword.put(acc, field, &1)).()
          end

        true ->
          case changed?(current, latest) do
            false ->
              acc

            value ->
              Keyword.put(acc, field, value)
          end
      end
    end)
    |> amended_by_change_log()
    |> (&Kernel.<>(current_fields.amended_by_change_log, &1)).()
    |> String.trim_leading("📌")
  end

  def compare_amended_by_change_log(current, current), do: nil

  def compare_amended_by_change_log(_current, latest), do: latest

  defp amended_by_change_log([]), do: ""

  defp amended_by_change_log(changes) do
    # IO.inspect(changes)
    # Returns the metadata changes as a formated multi-line string
    date = Date.utc_today()
    date = ~s(#{date.day}/#{date.month}/#{date.year})

    Enum.reduce(changes, ~s/📌#{date}📌/, fn {k, v}, acc ->
      # width = 80 - string_width(k)
      width = Map.get(@field_paddings, k)
      k = ~s/#{k}#{Enum.map(1..width, fn _ -> "." end) |> Enum.join()}/
      # k = String.pad_trailing(~s/#{k}/, width, ".")
      ~s/#{acc}#{k}#{v}📌/
    end)
    |> String.trim_trailing("📌")
  end

  defp changed?(current, latest) when current in [nil, "", []] and latest not in [nil, "", []] do
    case current != latest do
      false ->
        false

      true ->
        ~s/New value/
    end
  end

  defp changed?(_, latest) when latest in [nil, "", []], do: false

  defp changed?(current, latest) when is_list(current) and is_list(latest) do
    case current != latest do
      false ->
        false

      true ->
        ~s/#{Enum.join(current, ", ")} -> #{Enum.join(latest, ", ")}/
    end
  end

  defp changed?(current, current), do: false

  defp changed?(current, latest), do: "#{current} -> #{latest}"
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.NewLaw do
  @moduledoc """
  Module to handle addition of new amending laws into the Base
  1. Checks existence of law (for enumeration 1+)
  2. Filters records based on absence
  3. Posts new record with amendment data to Base
  """
  alias Legl.Countries.Uk.LeglRegister.Amend.Post

  def new_law?(records, opts) do
    records = Legl.Countries.Uk.LeglRegister.Helpers.Create.filterDelta(records, opts)

    Enum.each(records, fn record ->
      case ExPrompt.confirm("Save this law to the Base? #{record[Title_EN]}\n#{inspect(record)}") do
        false ->
          :ok

        true ->
          case opts.family do
            "" ->
              Post.post([record], opts)

            _ ->
              case ExPrompt.confirm("Assign this Family? #{opts.family}") do
                false ->
                  Post.post([record], opts)

                true ->
                  [Map.put(record, :Family, opts.family) | []]
                  |> Post.post(opts)
              end
          end
      end
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Csv do
  alias Legl.Countries.Uk.LeglRegister.Amend
  @at_csv ~s[lib/legl/countries/uk/legl_register/amend/amended_by.csv] |> Path.absname()
  def openCSVfile() do
    {:ok, file} = @at_csv |> File.open([:utf8, :write])
    IO.puts(file, Amend.amended_fields())
    file
  end

  def records_to_csv([]), do: :ok

  def records_to_csv(records) do
    records
    |> Enum.uniq()
    # |> (&([@amended_fields | &1])).()
    |> Enum.map(fn x -> Enum.join(x, ",") end)
    |> (&[Amend.amended_fields() <> "\n" | &1]).()
    |> Enum.join("\n")
    |> save_to_csv()
  end

  def save_to_csv(binary) do
    "lib/amending.csv"
    |> Path.absname()
    |> File.write(binary)

    :ok
  end
end
