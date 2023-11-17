defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke do
  @moduledoc """

    Module checks the amendments table of a piece of legislation for a table row
    that describes the law as having been repealed or revoked.

    Saves the results as a .csv file with the fields given by @fields

    Example

    Legl.Countries.Uk.UkRepealRevoke.run(base_name: "UK S", type_code:
    :nia, field_content: [{"Live?_description", ""}], workflow: :create)

  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.IdField, as: ID
  alias Legl.Airtable.AirtableTitleField, as: Title
  alias Legl.Services.LegislationGovUk.Url

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.Options
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RRDescription
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.Delta

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.Patch

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Csv

  @code_full "❌ Revoked / Repealed / Abolished"
  @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"

  defstruct [
    :Title_EN,
    :target,
    :affect,
    :amending_title,
    :type_code,
    :Number,
    :Year,
    :path
  ]

  @doc """
  Function to update a single Legal Register Table record by Name
  """
  def single_record(opts \\ []) do
    Options.single_record_options(opts)
    |> workflow()
  end

  @doc """
    Run in iex as
     Legl.Countries.Uk.UkRepealRevoke.run()
  """
  def run(opts \\ []) do
    opts
    |> Options.set_options()
    |> workflow()
  end

  # @api_post_results_path ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_post_results.json]

  @spec workflow(map()) :: :ok
  def workflow(opts) do
    records =
      AT.get_records_from_at(opts)
      |> elem(1)
      |> Jason.encode!()
      |> Jason.decode!(keys: :atoms)
      |> AT.strip_id_and_createdtime_fields()
      |> AT.make_records_into_legal_register_structs()

    records = workflow(records, opts)

    # UPDATED LAWS that are REVOKED / REPEALED

    Legl.Utility.maps_from_structs(records)
    |> Enum.map(&Map.put(&1, :"Live?_checked", ~s/#{Date.utc_today()}/))
    |> Legl.Utility.map_filter_out_empty_members()
    # PATCH the results to Airtable if :patch? == true
    |> Patch.patch(opts)

    if opts.csv?, do: Csv.closeFiles(opts)

    :ok
  end

  @spec workflow(%LegalRegister{}, map()) :: {:ok, %LegalRegister{}}
  def workflow(%LegalRegister{} = record, opts) when is_struct(record) do
    IO.puts(" REVOKED BY")

    {:ok,
     record
     |> List.wrap()
     |> workflow(opts)
     |> List.first()}
  end

  @spec workflow(list(), map()) :: list()
  def workflow(records, opts) do
    # {:ok, opts} = Options.set_options(opts)
    {records, revoking} =
      Enum.reduce(records, {[], []}, fn
        record, acc ->
          IO.puts("TITLE_EN: #{record."Title_EN"}")

          case get_revocations(record, opts) do
            {:ok, html} ->
              {latest_record, affecting_laws} = repeals_revocations(record, html, opts)

              latest_record =
                case opts.workflow do
                  :update ->
                    latest_record

                  :delta ->
                    Delta.compare(record, latest_record)
                end

              {[latest_record | elem(acc, 0)], [affecting_laws | elem(acc, 1)]}

            {:error, :no_records} ->
              {[Map.put(record, :Live?, @code_live) | elem(acc, 0)], elem(acc, 1)}
          end

          # We :update when we need a new Live? data and :delta to change_log
      end)

    # Save the new laws to json for later processing
    revoking
    |> List.flatten()
    |> Legl.Utility.save_structs_as_json(
      ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_revoke.json]
    )

    records
  end

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.amendment_parser/1

  @spec get_revocations(%LegalRegister{}, map()) :: {%LegalRegister{}, list() | []}
  def get_revocations(record, _opts) do
    url = Url.content_path(record)
    RecordGeneric.leg_gov_uk_html(url, @client, @parser)
  end

  def repeals_revocations(record, html, opts) do
    # Laws REPEALED or REVOKED by this law
    records = Legl.Countries.Uk.LeglRegister.Amend.Amending.get_affecting(record)

    revoking =
      Legl.Countries.Uk.LeglRegister.Amend.Amending.parse_laws_affected(records)
      |> Enum.filter(fn %{affect: affect} ->
        Regex.match?(~r/(repeal|revoke)/, affect)
      end)
      |> IO.inspect()

    {:ok, stats, _revoking} =
      Legl.Countries.Uk.LeglRegister.Amend.Stats.amendment_stats(revoking) |> IO.inspect()

    # Laws REVOKING or REPEALING this law
    affects = proc_amd_tbl(html)

    # Filter the table of amendments to return ONLY those revoking or repealing
    filtered_affects =
      Enum.filter(affects, fn %{affect: affect} -> Regex.match?(~r/(repeal|revoke)/, affect) end)

    filtered_affects = Enum.sort(filtered_affects, fn %{Year: x}, %{Year: y} -> x < y end)

    filtered_affects =
      Enum.map(
        filtered_affects,
        &Map.put(
          &1,
          :amending_title_and_path,
          ~s[#{&1.amending_title}💚️https://legislation.gov.uk#{&1.path}]
        )
      )

    live_description_field = RRDescription.live_description(filtered_affects, record, opts)

    live_field =
      cond do
        repealed_revoked_in_full?(filtered_affects) ->
          @code_full

        Enum.count(filtered_affects) != 0 ->
          @code_part

        true ->
          @code_live
      end

    revoked_by = revoked_by(filtered_affects)

    # Latest record is built from the record received
    latest_record =
      Kernel.struct(record,
        "Live?_description": live_description_field,
        Live?: live_field,
        Revoking: stats.links,
        "🔺_stats_revoking_laws_count": stats.laws,
        "🔺_stats_revoking_count_per_law": stats.counts,
        "🔺_stats_revoking_count_per_law_detailed": stats.counts_detailed,
        Revoked_by: revoked_by
      )

    {latest_record, new_laws(filtered_affects)}
  end

  @doc """
  Function processes each row of the amendment table html
  Returns a tuple:
  {:ok, title, target, effect, amending_title, path}
  where:
    Target = the part of the law that's amended eg 'reg. 2', 'Act'
    Effect = the type of amendment made eg 'words inserted', 'added'
  """
  def proc_amd_tbl([]), do: []

  def proc_amd_tbl([{"tbody", _, rows}]) do
    Enum.map(rows, fn {_, _, x} -> x end)
    |> Enum.map(&proc_amd_tbl_row(&1))
  end

  def proc_amd_tbl_row(row) do
    Enum.with_index(row, fn cell, index -> {index, cell} end)
    |> Enum.reduce([], fn
      {0, {"td", _, [{_, _, [title]}]}}, acc ->
        [title | acc]

      {1, _cell}, acc ->
        acc

      {2, {"td", _, content}}, acc ->
        # IO.inspect(content, label: "CONTENT: ")

        Enum.map(content, fn
          {"a", [{"href", _}, [v1]], [v2]} -> ~s/#{v1} #{v2}/
          {"a", [{"href", _}], [v]} -> v
          {"a", [{"href", _}], []} -> ""
          [v] -> v
          v when is_binary(v) -> v
        end)
        # |> IO.inspect(label: "AT: ")
        |> Enum.join(" ")
        |> String.trim()
        |> (&[&1 | acc]).()

      {3, {"td", _, [amendment_effect]}}, acc ->
        [amendment_effect | acc]

      {3, {"td", [], []}}, acc ->
        ["" | acc]

      {4, {"td", _, [{_, _, [amending_title]}]}}, acc ->
        [amending_title | acc]

      {5, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
        {type_code, number, year} = Legl.Utility.type_number_year(path)
        year = String.to_integer(year)
        [path, year, number, type_code | acc]

      {6, _cell}, acc ->
        acc

      {7, _cell}, acc ->
        acc

      {8, _cell}, acc ->
        acc

      {id, row}, acc ->
        IO.puts(
          "Unhandled amendment table row\nID #{id}\nCELL #{inspect(row)}\n[#{__MODULE__}.amendments_table_records]\n"
        )

        acc
    end)
    |> Enum.reverse()
    |> (&Enum.zip(
          [
            :Title_EN,
            :target,
            :affect,
            :amending_title,
            :type_code,
            :Number,
            :Year,
            :path
          ],
          &1
        )).()
    |> (&Kernel.struct(__MODULE__, &1)).()

    # |> IO.inspect(label: "DATA TUPLE: ")

    # |> IO.inspect(label: "TABLE ROW TUPLE: ")
  end

  @doc """
  Function filters amendment table rows for entries describing the full revocation / repeal of a law
  """
  @spec repealed_revoked_in_full?(list()) :: boolean()
  def repealed_revoked_in_full?(data) do
    Enum.reduce_while(data, false, fn
      %{target: target, affect: affect}, _acc
      when target in ["Regulations", "Order", "Act"] and affect in ["revoked", "repealed"] ->
        {:halt, true}

      _, acc ->
        {:cont, acc}
    end)
  end

  @spec revoking(list()) :: list()
  def revoking(data) do
    data
    |> Enum.uniq_by(& &1.path)
    |> Enum.reduce(
      [],
      fn %{Title_EN: t, Year: y, Number: n, type_code: tc}, acc ->
        [ID.id(t, tc, y, n) | acc]
      end
    )
    |> Enum.uniq()
  end

  @doc """
  Function builds Name field (ID/key) and saves the result to :revoked_by
  # {"Consumer Protection Act 1987", "s. 45(4)", "repealed",
    "Trade Marks Act 1994💚️https://legislation.gov.uk/id/ukpga/1994/26"}
  """
  @spec revoked_by(list()) :: String.t()
  def revoked_by(rr_data) do
    rr_data
    |> Enum.uniq_by(& &1.path)
    |> Enum.reduce(
      [],
      fn %{amending_title: t, Year: y, Number: n, type_code: tc}, acc ->
        [ID.id(t, tc, y, n) | acc]
      end
    )
    |> Enum.uniq()
    |> Enum.join(",")
  end

  def new_laws(records) do
    records
    |> Enum.map(fn %_{Title_EN: t, Number: n, Year: y, type_code: tc} ->
      name = ID.id(t, tc, y, n)

      Map.new(
        Name: name,
        Title_EN: Title.title_clean(t),
        Number: n,
        type_code: tc,
        Year: y
      )
    end)
    |> Enum.uniq()

    # |> (&{:ok, &1}).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Post do
  def post([], _), do: :ok

  def post(records, opts) do
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
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.NewLaw do
  @moduledoc """
  Module to handle addition of new amending laws into the Base
  1. Checks existence of law (for enumeration 1+)
  2. Filters records based on absence
  3. Posts new record with amendment data to Base
  """
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  def new_law?(records, opts) do
    # Loop through the records and add a new record parameter :url
    # Record has this shape:
    # %{
    #    Name: "UK_uksi_2003_3073_RVRLAR",
    #    Number: "3073",
    #    Title_EN: "Road Vehicles (Registration and Licensing) (Amendment) (No. 4) Regulations",
    #    Year: "2003",
    #    type_code: "uksi"
    # }
    records =
      Enum.map(records, fn record ->
        options = [
          formula: ~s/{Name}="#{Map.get(record, :Name)}"/,
          fields: ["Name", "Number", "Year", "type_class"]
        ]

        {:ok, url} = Url.url(opts.base_id, opts.table_id, options)
        Map.put(record, :url, url)
      end)

    record_exists_filter(records)
  end

  def record_exists_filter(records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            Map.drop(record, [:url])
            |> (&Map.put(%{}, :fields, &1)).()
            |> (&[&1 | acc]).()

          _ ->
            acc
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR #{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Csv do
  # @code_full "❌ Revoked / Repealed / Abolished"
  # @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"

  @at_csv ~s[lib/legl/countries/uk/legl_register/repeal_revoke/repeal_revoke.csv]
          |> Path.absname()
  @rr_new_law ~s[lib/legl/countries/uk/legl_register/repeal_revoke/rr_new_law.csv]
              |> Path.absname()
  def openFiles(opts) do
    with {:ok, file} <- File.open(@at_csv, [:utf8, :write]),
         IO.puts(file, opts.fields_update),
         {:ok, file_new_law} <- File.open(@rr_new_law, [:utf8, :write]),
         IO.puts(file_new_law, opts.fields_new_law) do
      Map.merge(opts, %{file: file, file_new_law: file_new_law})
    end
  end

  def closeFiles(opts) do
    File.close(opts.file)
    File.close(opts.file_new_law)
  end

  def save_to_csv(name, %{"Live?_description": ""}, opts) do
    # no revokes or repeals
    ~s/#{name},#{@code_live}/ |> (&IO.puts(opts.file, &1)).()
  end

  def save_to_csv(name, %{"Live?_description": nil}, opts) do
    # no revokes or repeals
    ~s/#{name},#{@code_live}/ |> (&IO.puts(opts.file, &1)).()
  end

  def save_to_csv(name, r, opts) do
    # part revoke or repeal
    if "" != r."Live?_description" |> to_string() |> String.trim() do
      ~s/#{name},#{r."Live?"},#{r.revoked_by},#{r."Live?_description"}/
      |> (&IO.puts(opts.file, &1)).()
    end

    :ok
  end

  def save_new_law(new_laws, opts) do
    new_laws
    |> IO.inspect()
    |> Enum.uniq()
    |> Enum.each(fn law ->
      IO.puts(opts.file, law)
    end)
  end
end
