defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy do
  @moduledoc """
  Run as
  Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.run([t: type_code, base_name: "UK S"])
  """
  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Clean
  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Post
  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Patch
  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Options
  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.NewLaw
  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Csv
  alias Legl.Services.Airtable.UkAirtable, as: AT

  @source_path ~s[lib/legl/countries/uk/legl_register/enact/enacted_source.json]
  @enacting_path ~s[lib/legl/countries/uk/legl_register/enact/enacting.json]

  @doc """
    opts has this shape

    %{base_name: "UK S", fields: ["Name",
    "Title_EN", "type_code", "Year", "Number", "Enabled by"], files:
    {#PID<0.418.0>, #PID<0.419.0>}, sTypeClass: "Order", sTypeCode: "nisr",
    type_class: :order, type_code: :nisr, view: "Enabled_by"}

  """
  def run(opts \\ []) when is_list(opts) do
    with(
      {:ok, opts} <- Options.setOptions(opts),
      opts <- if(opts.csv?, do: Csv.openFiles(opts), else: opts),
      :ok <- enumerate_type_codes(opts),
      :ok <- if(opts.csv?, do: Csv.closeFiles(opts), else: :ok)
    ) do
      :ok
    end
  end

  def enumerate_type_codes(opts) do
    Enum.each(opts.type_codes, fn type_code ->
      # Formula is different for each type_code
      formula = Options.formula(type_code, opts)
      opts = Map.put(opts, :formula, formula)

      IO.puts("TYPE_CODE: #{type_code}. FORMULA: #{formula}")

      workflow(opts)
    end)
  end

  @api_patch_results_path ~s[lib/legl/countries/uk/legl_register/enact/api_patch_results.json]
  @api_post_results_path ~s[lib/legl/countries/uk/legl_register/enact/api_post_results.json]

  def workflow(opts) do
    with {:ok, at_records} <- AT.get_records_from_at(opts),
         at_records = Jason.encode!(at_records) |> Jason.decode!(keys: :atoms),
         :ok <- filesave(at_records, @source_path, opts),
         {:ok, results, enacting_laws_list} <-
           Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_enacting_laws(at_records, opts),
         :ok <- filesave(results, @enacting_path, opts),
         :ok <- post_new_laws(enacting_laws_list, opts),
         :ok <- enacted_by_laws(results, opts) do
      if opts.csv?, do: Csv.save_new_laws_to_csv(results, opts)

      :ok
    else
      {:error, error} ->
        IO.puts("#{error}")

      %{"message" => msg, "type" => type} ->
        IO.puts("ERROR #{type} msg: #{msg}")
    end
  end

  @api_post_results_path ~s[lib/legl/countries/uk/legl_register/enact/api_post_results.json]

  @doc """
  Receives a list of Enacting Laws and optionally POSTs to the Legal Register
  BASE if they are not present
  """
  @spec post_new_laws(list(), map()) :: :ok
  def post_new_laws([], _) do
    IO.puts(~s<\nZero (0) ENACTING LAWS\n>)
  end

  def post_new_laws(results, opts) do
    #
    # NEW LAWS FOR THE BASE

    IO.puts(~s<\n#{Enum.count(results)} ENACTING LAWS\n>)
    Enum.each(results, fn law -> IO.puts(law[:Title_EN]) end)

    # Filter revoking / repealing laws against those already stored in Base
    new_laws =
      results
      |> NewLaw.new_law?(opts)

    IO.puts(~s<\n#{Enum.count(new_laws)} LAWS MISSING FROM LEGAL REGISTER\n>)

    Enum.each(new_laws, fn
      %{fields: fields} = _law -> IO.puts("#{fields[:Title_EN]}")
    end)

    new_laws =
      Enum.reduce(new_laws, [], fn law, acc ->
        if ExPrompt.confirm("\nSave #{law.fields[:Title_EN]} to BASE?\n"),
          do: [law | acc],
          else: acc
      end)

    new_laws = Clean.clean_records_for_post(new_laws, opts)

    IO.inspect(new_laws, label: "NEW LAWS: ")

    # store the cleaned results to file for QA
    json =
      new_laws
      |> (&Map.put(%{}, "records", [&1])).()
      |> Jason.encode!()

    Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_post_results_path)

    if ExPrompt.confirm("\nPOST New Laws?"), do: Post.post(new_laws, opts)
  end

  @api_patch_results_path ~s[lib/legl/countries/uk/legl_register/enact/api_patch_results.json]

  defp enacted_by_laws(results, opts) do
    # ENACTING LAWS

    # Filter out any records where there are no enacting laws
    results =
      Enum.filter(results, fn
        %{fields: %{enacting_laws: enacting_laws}} -> enacting_laws != []
        %{enacting_laws: enacting_laws} -> enacting_laws != []
      end)

    # results =
    #  Enum.reduce(results, [], fn law, acc ->
    #    enacted_by = Enum.join(law.fields[:Enacted_by])
    #
    #       [
    #        %{id: law.id, fields: %{Name: law.fields[:Name], Enacted_by: enacted_by}}
    #       | acc
    #    ]
    # end)

    # IO.inspect(results, label: "FILTERED RESULTS: ")

    # clean the results so they are suitable for a PATCH call to Airtable
    case results do
      [] ->
        IO.puts("No Enacting Laws have been identified")
        :ok

      _ ->
        if opts.csv? == true, do: Csv.save_enacted_by_to_csv(results, opts)

        results = Clean.clean_records(results)

        if ExPrompt.confirm("\nView Cleaned Patch Results?"),
          do: IO.inspect(results, label: "CLEAN RESULTS: ")

        # store the cleaned results to file for QA
        json =
          results
          |> (&Map.put(%{}, "records", &1)).()
          |> Jason.encode!()

        Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_patch_results_path)

        # PATCH the results to Airtable if :patch? == true
        if opts.patch?, do: Patch.patch(results, opts), else: IO.puts("Set opts.patch? == true")
    end
  end

  defp filesave(records, _, %{filesave: false} = _opts), do: records

  defp filesave(records, path, %{filesave: true} = _opts) do
    json = Map.put(%{}, "records", records) |> Jason.encode!(pretty: true)
    Legl.Utility.save_at_records_to_file(~s/#{json}/, path)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Options do
  alias Legl.Countries.Uk.UkTypeClass, as: TypeClass
  alias Legl.Countries.Uk.UkTypeCode, as: TypeCode
  alias alias Legl.Services.Airtable.AtBasesTables

  @default_opts %{
    # a new value for the Enacted_by field ie the cells are blank
    new?: true,
    # target single record Enacted_by field by providing the Name (key/ID)
    name: "",
    # set this as an option or get an error!
    base_name: "UK E",
    type_code: [""],
    type_class: nil,
    year: nil,
    fields: ["Name", "Title_EN", "type_code", "Year", "Number", "Enacted_by"],
    view: "",
    csv?: false,
    post?: true,
    patch?: true,
    filesave: true
  }
  def setOptions(opts) do
    opts = Enum.into(opts, @default_opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})

    with {:ok, type_codes} <- TypeCode.type_code(opts.type_code),
         {:ok, type_classes} <- TypeClass.type_class(opts.type_class) do
      Map.merge(
        opts,
        %{
          type_class: type_classes,
          type_codes: type_codes
        }
      )
      |> (&{:ok, &1}).()
    else
      {:error, error} ->
        IO.puts("ERROR: #{error}")
    end
  end

  def formula(type, %{name: ""} = opts) do
    f = if opts.new?, do: [~s/{Enacted_by}=BLANK()/], else: []
    f = if type != "", do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f
    f = if opts.year != nil, do: [~s/{Year}="#{opts.year}"/ | f], else: f
    # f = if opts.view != "", do: [~s/view="#{opts.view}"/ | f], else: f
    ~s/AND(#{Enum.join(f, ",")})/
  end

  def formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Clean do
  def clean_records_for_post(records, _opts) do
    Enum.map(records, fn %{fields: fields} = _record ->
      Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
      |> Map.drop([:Name])
      |> Map.put(:Year, String.to_integer(fields[:Year]))
      |> (&Map.put(%{}, :fields, &1)).()
    end)
  end

  def clean_records(records) when is_list(records) do
    Enum.map(records, fn %{id: id, fields: %{Enacted_by: enabled_by} = _fields} = _record ->
      %{id: id, fields: %{Enacted_by: enabled_by}}
    end)
  end

  def clean_records(records) when is_list(records) do
    Enum.map(records, fn %{fields: fields} = record ->
      Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
      |> clean()
      |> (&Map.put(record, :fields, &1)).()
      |> Map.drop([:createdTime])
    end)
  end

  defp clean(%{Enacted_by: []} = fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :Enacted_by,
      :path,
      :amending_title,
      :enacting_laws,
      :enacting_text,
      :introductory_text,
      :text,
      :urls
    ])
  end

  defp clean(%{Enacted_by: _revoked_by} = fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :path,
      :amending_title,
      :enacting_laws,
      :enacting_text,
      :introductory_text,
      :text,
      :urls
    ])

    # |> Map.put(:Revoked_by, Enum.join(revoked_by, ", "))
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Post do
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

defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Patch do
  def patch([], _), do: :ok

  def patch(record, opts) when is_map(record) do
    IO.write("PATCH single record - ")

    json =
      record
      |> (&Map.put(%{}, "records", &1)).()
      |> Jason.encode!()

    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    Legl.Services.Airtable.AtPatch.patch_records(json, headers, params)
  end

  def patch(records, opts) when is_list(records) do
    IO.write("PATCH bulk - ")
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
end

defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.NewLaw do
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

  defp record_exists_filter(records) do
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

defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.Csv do
  @csv_new_law ~s[lib/legl/countries/uk/legl_register/enact/new_law.csv] |> Path.absname()
  @csv_enacted_by ~s[lib/legl/countries/uk/legl_register/enact/enacting.csv] |> Path.absname()
  def openFiles(opts) do
    {:ok, csv_new_law} = File.open(@csv_new_law, [:utf8, :append, :read])
    File.write(@csv_new_law, "Name,Title_EN,type_code,Year,Number\n")

    # path = @enacted_by_csv |> Path.absname()
    {:ok, csv_enacted_by} = File.open(@csv_enacted_by, [:utf8, :append, :read])
    File.write(@csv_enacted_by, "Name,Enacted_by\n")

    Map.merge(opts, %{csv_enacted_by: csv_enacted_by, csv_new_law: csv_new_law})
  end

  def closeFiles(opts) do
    File.close(opts.csv_enacted_by)
    File.close(opts.csv_new_law)
  end

  def save_enacted_by_to_csv(results, opts) do
    Enum.each(results, fn
      %{fields: %{Name: name, Enacted_by: enacted_by}} = _result ->
        enacted_by =
          enacted_by
          # |> Enum.join(",")
          |> Legl.Utility.csv_quote_enclosure()

        IO.puts(opts.csv_enacted_by, "#{name},#{enacted_by}")
    end)
  end

  def save_new_laws_to_csv(results, opts) do
    Enum.reduce(results, [], fn %{enacting_laws: eLaws} = _result, acc ->
      acc ++ eLaws
    end)
    |> Enum.uniq_by(&{&1[Name]})
    |> new_laws()
    |> Enum.each(&IO.puts(opts.csv_new_law, &1))
  end

  defp new_laws(enacting_laws) do
    Enum.reduce(enacting_laws, [], fn law, acc ->
      %{Name: id, Number: number, Title_EN: title, type_code: type, Year: year} = law

      # we have to quote enclose in case title contains commas and quotes
      title =
        Legl.Airtable.AirtableTitleField.title_clean(title)
        |> Legl.Utility.csv_quote_enclosure()

      [~s/#{id},#{title},#{type},#{year},#{number}/ | acc]
    end)
  end
end
