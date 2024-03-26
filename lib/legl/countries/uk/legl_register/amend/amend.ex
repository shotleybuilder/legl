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

  def single_record(opts \\ []) do
    Options.single_record_options(opts)
    |> workflow()
  end

  @doc """
  Run amend 'stand alone' against records returned from Airtable
  Can be used as part of the monthly update process
  """
  def run(opts \\ []) do
    Options.set_options(opts)
    |> workflow()
  end

  def workflow(opts) do
    records =
      AT.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)
      |> AT.strip_id_and_createdtime_fields()
      |> AT.make_records_into_legal_register_structs()

    # |> IO.inspect(label: "CURRENT RECORDS:")

    # Results is a 2-item tuple.  New records and records
    results = amendment_bfs({[], records}, opts, 0)

    nrecords = Enum.map(results, fn {nrecord, _records} -> nrecord end)

    # IO.inspect(latest_records, label: "LATEST RECORDS:")

    cond do
      opts.workflow == :update ->
        Legl.Utility.maps_from_structs(nrecords)
        |> Enum.map(&Map.put(&1, :amendments_checked, ~s/#{Date.utc_today()}/))
        |> Legl.Utility.map_filter_out_empty_members()
        |> Patch.patch(opts)

      opts.workflow == :delta ->
        Delta.compare(results)
        # |> IO.inspect()
        |> Legl.Utility.maps_from_structs()
        |> Enum.map(&Map.put(&1, :amendments_checked, ~s/#{Date.utc_today()}/))
        |> Legl.Utility.map_filter_out_empty_members()
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

  @spec workflow(%LegalRegister{}, map()) :: {:ok, %LegalRegister{}}
  def workflow(%LegalRegister{} = record, opts) when is_struct(record) do
    IO.write(" AMENDED BY")

    workflow([record], opts)
    |> List.first()
    |> Map.put(:amendments_checked, ~s/#{Date.utc_today()}/)
    |> (&{:ok, &1}).()
  end

  @spec workflow(list(LegalRegister), map()) :: list(LegalRegister)
  def workflow(records, opts) when is_list(records) do
    results = amendment_bfs({[], records}, opts, 0)

    records =
      case opts.workflow |> Atom.to_string() |> String.contains?("Delta") do
        false ->
          Enum.map(results, fn {nrecord, _records} -> nrecord end)

        true ->
          Delta.compare(results)
      end

    records |> Enum.map(&Map.put(&1, :amendments_checked, ~s/#{Date.utc_today()}/))
  end

  def workflow(record, opts) when is_map(record) do
    workflow([record], opts) |> List.first()
  end

  @doc """
    Breadth first search up to an arbitrary number of layers of the amendments tree
  """
  @spec amendment_bfs(tuple(), map(), integer()) :: list(tuple())
  def amendment_bfs({results, _}, _, @enumeration_limit), do: results

  def amendment_bfs({results, records}, opts, enumeration_limit) do
    #
    IO.puts("\nEnumeration #{enumeration_limit}")

    case Enum.count(records) == 0 do
      true ->
        results

      false ->
        continue? =
          if enumeration_limit < @enumeration_limit,
            do: true,
            else:
              ExPrompt.confirm(
                "There are #{Enum.count(records)} laws in this iteration.  Continue?"
              )

        case continue? do
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

                  {nrecord, amending_laws} = AmendedBy.get_laws_amending_this_law(record)
                  {nrecord, amended_laws} = Amending.get_laws_amended_by_this_law(nrecord)

                  nrecord = Map.put(nrecord, :record_id, record.record_id)

                  {
                    [{nrecord, record} | acc],
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
            if opts.json? == true do
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
            end

            # IO.inspect(nlinks, limit: :infinity)

            amendment_bfs({nresults, amending_laws ++ amended_laws}, opts, enumeration_limit)
        end
    end
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Amend.Patch do
  @api_results_path ~s[lib/legl/countries/uk/legl_register/amend/api_patch_results.json]
  def patch([], _), do: :ok

  def patch(records, opts) do
    IO.write("PATCH bulk - ")

    records = Enum.map(records, &clean(&1))
    IO.write("Records cleaned - ")

    json = Map.put(%{}, "records", records) |> Jason.encode!(pretty: true)
    Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_results_path)
    IO.write("Records saved to json - ")

    if opts.patch? == true,
      do: Legl.Countries.Uk.LeglRegister.PatchRecord.patch(records, opts)
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
    IO.puts(file, Options.amend_fields())
    file
  end

  def records_to_csv([]), do: :ok

  def records_to_csv(records) do
    records
    |> Enum.uniq()
    # |> (&([@amended_fields | &1])).()
    |> Enum.map(fn x -> Enum.join(x, ",") end)
    |> (&[Options.amend_fields() <> "\n" | &1]).()
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
