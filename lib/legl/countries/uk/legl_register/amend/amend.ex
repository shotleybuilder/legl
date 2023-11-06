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

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.Amend.Options
  alias Legl.Countries.Uk.LeglRegister.Amend.Amending
  alias Legl.Countries.Uk.LeglRegister.Amend.AmendedBy
  alias Legl.Countries.Uk.LeglRegister.Amend.Delta
  alias Legl.Countries.Uk.LeglRegister.Amend.Csv
  alias Legl.Countries.Uk.LeglRegister.Amend.Patch

  @type amend :: %__MODULE__{
          Name: String.t(),
          Title_EN: String.t(),
          type_code: String.t(),
          Number: String.t(),
          Year: integer(),
          path: String.t(),
          target: String.t(),
          affect: String.t(),
          applied?: String.t(),
          target_affect_applied?: String.t(),
          note: list(),
          # Count of the number of laws amending this law or
          # Count of the number of laws amended by this law
          affect_count: String.t()
        }

  defstruct ~w[
    Name
    Title_EN
    type_code
    Number
    Year
    path
    target
    affect
    applied?
    target_affect_applied?
    note
    affect_count
  ]a

  @enumeration_limit 1

  @doc """
  Run amend 'stand alone' against records returned from Airtable
  Can be used as part of the monthly update process
  """
  def run(opts \\ []) do
    opts = Options.set_options(opts)

    {:ok, records} = AT.get_records_from_at(opts)

    records = Jason.encode!(records) |> Jason.decode!(keys: :atoms)

    records = AT.strip_id_and_createdtime_fields(records)

    records = AT.make_records_into_legal_register_structs(records)
    # |> IO.inspect(label: "CURRENT RECORDS:")

    records = amendment_bfs({[], records}, opts, 0)

    records =
      Legl.Utility.maps_from_structs(records)
      |> Legl.Utility.map_filter_out_empty_members()

    # IO.inspect(latest_records, label: "LATEST RECORDS:")

    cond do
      opts.workflow == :create ->
        Patch.patch(records, opts)

      opts.workflow == :update ->
        Delta.compare(records)
        # |> IO.inspect()
        |> Patch.patch(opts)
    end

    if opts.csv? do
      Csv.records_to_csv(records)
      File.close(opts.file)
    end
  end

  @doc """
  Workflow is part of a larger process setting all the fields of a legal register record
  """
  def workflow(record, opts) when is_map(record) do
    workflow([record], opts)
  end

  @spec workflow(list(LegalRegister), map()) :: list(LegalRegister)
  def workflow(records, opts) when is_list(records) do
    amendment_bfs({[], records}, opts, 0)
  end

  @doc """
    Breadth first search up to an arbitrary number of layers of the amendments tree
  """
  def amendment_bfs({records, _}, _, @enumeration_limit), do: records

  def amendment_bfs({results, records}, opts, enumeration_limit) do
    #
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

            {nresults, amending_laws, amended_laws} =
              Enum.reduce(records, {results, [], []}, fn
                record, {acc, cum_amending_laws, cum_amended_laws} ->
                  IO.puts(
                    "title-> #{record."Title_EN"} #{record."Year"} #{record.type_code} #{record."Number"}"
                  )

                  {record, amending_laws} = AmendedBy.get_laws_amending_this_law(record)
                  {record, amended_laws} = Amending.get_laws_amended_by_this_law(record)

                  {
                    [record | acc],
                    amending_laws ++ cum_amending_laws,
                    amended_laws ++ cum_amended_laws
                  }
              end)

            amending_laws =
              Legl.Utility.maps_from_structs(amending_laws)
              |> Legl.Utility.map_filter_out_empty_members()

            amended_laws =
              Legl.Utility.maps_from_structs(amended_laws)
              |> Legl.Utility.map_filter_out_empty_members()

            # IO.inspect(amending_laws, limit: :infinity)
            # IO.inspect(amended_laws, limit: :infinity)

            # Remove new records that are already in the BASE
            # amending_laws = filter(amending_laws, opts)

            # amended_laws = filter(amended_laws, opts)

            # Capture details of new laws for the Base in json for later processing
            json_path =
              ~s[lib/legl/countries/uk/legl_register/amend/new_amending_laws_enum#{enumeration_limit - 1}.json]

            Map.put(%{}, "records", amending_laws)
            |> Jason.encode!(pretty: true)
            |> Legl.Utility.save_at_records_to_file(json_path)

            json_path =
              ~s[lib/legl/countries/uk/legl_register/amend/new_amended_laws_enum#{enumeration_limit - 1}.json]

            Map.put(%{}, "records", amended_laws)
            |> Jason.encode!(pretty: true)
            |> Legl.Utility.save_at_records_to_file(json_path)

            # IO.inspect(nlinks, limit: :infinity)

            amendment_bfs({nresults, amending_laws ++ amended_laws}, opts, enumeration_limit)
        end
    end
  end

  defp filter(records, opts) do
    case Legl.Countries.Uk.LeglRegister.Helpers.Create.filter_delta(
           records,
           opts
         ) do
      {:ok, records} ->
        records

      {:error, msg} ->
        IO.puts("ERROR: #{msg}\n")
        records
    end
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Patch do
  @api_results_path ~s[lib/legl/countries/uk/legl_register/amend/api_patch_results.json]
  def patch([], _), do: :ok

  def patch(records, %{patch?: true} = opts) do
    IO.write("PATCH bulk - ")

    records = Enum.map(records, &clean(&1))
    IO.write("Records cleaned - ")

    json = Map.put(%{}, "records", records) |> Jason.encode!(pretty: true)
    Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_results_path)
    IO.write("Records saved to json - ")

    process(records, opts)
  end

  defp process(results, opts) do
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

  def clean(%{record_id: _} = record) when is_map(record) do
    record
    |> Map.drop([
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :record_id
    ])
    |> (&Map.merge(%{id: record.record_id}, %{fields: &1})).()
  end

  def clean(record), do: record
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
    records = Legl.Countries.Uk.LeglRegister.Helpers.Create.filter_delta(records, opts)

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
  alias Legl.Countries.Uk.LeglRegister.Amend.Options
  @at_csv ~s[lib/legl/countries/uk/legl_register/amend/amended_by.csv] |> Path.absname()
  def openCSVfile() do
    {:ok, file} = @at_csv |> File.open([:utf8, :write])
    IO.puts(file, Options.amended_fields())
    file
  end

  def records_to_csv([]), do: :ok

  def records_to_csv(records) do
    records
    |> Enum.uniq()
    # |> (&([@amended_fields | &1])).()
    |> Enum.map(fn x -> Enum.join(x, ",") end)
    |> (&[Options.amended_fields() <> "\n" | &1]).()
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
