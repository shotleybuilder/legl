defmodule Legl.Countries.Uk.LeglRegister.Helpers do
  def clean_records(records, drop_fields) when is_list(records) do
    # IO.inspect(records, label: "FILTER")
    records = List.flatten(records)

    Enum.map(records, fn
      # Airtable records w/ :id & :fields param
      %{fields: fields} = record ->
        Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
        |> Map.drop(drop_fields)
        |> (&Map.put(record, :fields, &1)).()
        |> Map.drop([:createdTime])

      # Flat records map
      record ->
        Map.filter(record, fn {_k, v} -> v not in [nil, "", []] end)
        |> Map.drop(drop_fields)
        |> (&Map.put(%{}, :fields, &1)).()
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Helpers.Create do
  @moduledoc """
  Module to filter a list of laws based on whether they are a record or not a
  record in the Legal Register Base
    Records parameter should have this shape:
    [
      %{
        Name: "UK_uksi_2003_3073_RVRLAR",
        Number: "3073",
        Title_EN: "Road Vehicles (Registration and Licensing) (Amendment) (No. 4) Regulations",
        Year: "2003",
        type_code: "uksi"
      }
    ]
  """
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  @doc """
  Returns list of atoms of the Legal Register fields to be returned with a call
  to the Airtable API
  """
  @spec fields() :: []
  def fields do
    ~w[
      Number
      type_code
      Year
      Name
      Title_EN
      type_class
      Type
      Tags
      md_subjects
      md_description
      md_restrict_start_date
      md_dct_valid_date
      md_modified
      md_total_paras
      md_body_paras
      md_schedule_paras
      md_attachment_paras
      md_images
      md_change_log
      Geo_Parent
      Geo_Pan_Region
      Geo_Region
      Geo_Extent
      Enacted_by
      Amended_by
      Live?_checked
      Live?
      Live?_description
      Revoked_by
    ]
  end

  @doc """
  Receives a Record map of Number, type_code and Year and options with base_id
  and table_id and returns a boolean true or false

  Function to check presence of law in a Legal Register
  """
  @spec exists?(map(), map()) :: boolean()
  def exists?(record, opts) when is_map(record) do
    {:ok, url} = setUrl(record, opts)

    with {:ok, body} <- Client.request(:get, url, []),
         %{records: records} = Jason.decode!(body, keys: :atoms) do
      case records do
        [] -> false
        _ -> true
      end
    else
      {:ok, _, _} ->
        true

      {:error, reason} ->
        IO.puts("ERROR: #{reason}")
    end
  end

  @doc """
  Receives a Record map of Number, type_code and Year and options with base_id
  and table_id and returns either the returned record or :ok

  Function to provide the start for a create or update process
  """
  @spec get_lr_record(map(), map()) :: {:ok, map()} | :ok
  def get_lr_record(record, opts) when is_map(record) do
    %{Number: number, Year: year, type_code: type_code} = record

    options = [
      formula: ~s/AND({Number}="#{number}", {Year}="#{year}", {type_code}="#{type_code}")/,
      fields: fields()
    ]

    {:ok, url} = Url.url(opts.base_id, opts.table_id, options)

    with {:ok, body} <- Client.request(:get, url, []),
         %{records: records} = Jason.decode!(body, keys: :atoms) do
      {:ok, records}
    else
      {:ok, code, reason} ->
        IO.puts("#{code} #{reason}")

      {:error, reason} ->
        IO.puts("ERROR: #{reason}")
    end
  end

  @doc """
  Function to filter out laws that are present in the Base.
  Laws that are a record in the the Base are removed from the records.
  To create a list of records suitable for a POST request.
  """
  @spec filter_delta([], any()) :: {:ok, []}
  def filter_delta([], _), do: {:ok, []}

  @spec filter_delta(list(), map()) :: {:ok, list()} | {:error, binary()}
  def filter_delta(records, opts) do
    with {:ok, records} <- setUrl(records, opts),
         records <- filter(:delta, records) do
      {:ok, records}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Function to filter out laws that are NOT present in the Base.
  Laws that are NOT in the Base are removed from the list
  To create a list suitable for a PATCH request
  """
  def filterMatch(records, opts) do
    with {:ok, records} <- setUrl(records, opts),
         records <- filter(:match, records) do
      {:ok, records}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def setUrl(record, opts) when is_map(record) do
    %{Number: number, Year: year, type_code: type_code} = record

    options = [
      formula: ~s/AND({Number}="#{number}", {Year}="#{year}", {type_code}="#{type_code}")/,
      fields: ["Name"]
    ]

    with({:ok, url} <- Url.url(opts.base_id, opts.table_id, options)) do
      {:ok, url}
    else
      {:error, msg} ->
        IO.puts("ERROR SETTING URL: #{msg}")
        record
    end
  end

  def setUrl(records, opts) when is_list(records) do
    records =
      Enum.reduce(records, [], fn
        %{Number: number, Year: year, type_code: type_code} = record, acc ->
          options = [
            formula: ~s/AND({Number}="#{number}", {Year}="#{year}", {type_code}="#{type_code}")/,
            fields: ["Name"]
          ]

          with({:ok, url} <- Url.url(opts.base_id, opts.table_id, options)) do
            [Map.put(record, :url, url) | acc]
          else
            {:error, msg} ->
              IO.puts("ERROR: #{msg}")
              [record | acc]
          end

        record, acc ->
          IO.puts("ERROR: Incomplete record.\nCannot check presence in Base.\n#{inspect(record)}")
          [record | acc]
      end)

    case records do
      [] -> {:error, "\nNo record URLs could be set\n#{__MODULE__}.setUrl"}
      _ -> {:ok, records}
    end
  end

  @doc """
  Receives a list of law records and returns a 2 element Tuple.
  The first element are laws NOT in the BASE.
  The second element are laws IN the BASE.
  """
  @spec filter(:both, list(), map()) :: {list(), list()}
  def filter(:both, records, opts) do
    Enum.reduce(records, {[], []}, fn record, {post, patch} ->
      case exists?(record, opts) do
        true ->
          {post, [record | patch]}

        false ->
          {[record | post], patch}
      end
    end)
  end

  defp filter(:delta, records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with :ok = IO.write(~s/BASE check for #{record."Title_EN"}/),
           {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            IO.puts(" - is not in the Base")

            Map.drop(record, [:url])
            |> (&[&1 | acc]).()

          _ ->
            IO.puts(" - is in the Base")
            acc
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR: #{record[:Title_EN]}\n#{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end

  defp filter(:match, records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            acc

          _ ->
            Map.drop(record, [:url])
            |> (&[&1 | acc]).()
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

defmodule Legl.Countries.Uk.LeglRegister.Helpers.PatchNewRecord do
  @moduledoc """
  PATCH records in a Legal Register
  """

  @doc """

  """
  @spec run(map() | list(), map()) :: :ok
  def run([], _), do: {:error, "RECORDS: EMPTY LIST: No data to PATCH"}

  def run(records, %{drop_fields: drop_fields} = opts) when is_list(records) do
    # IO.inspect(records, label: "PATCH")

    with(
      records <- Legl.Countries.Uk.LeglRegister.Helpers.clean_records(records, drop_fields),
      json =
        Map.merge(%{}, %{"records" => records, "typecast" => true}) |> Jason.encode!(pretty: true),
      :ok = Legl.Utility.save_at_records_to_file(json, opts.api_patch_path),
      :ok <- patch(records, opts)
    ) do
      :ok
    end
  end

  def run(record, opts) when is_map(record), do: run([record], opts)

  def patch([], _), do: :ok

  def patch(records, opts) when is_list(records) do
    IO.write("PATCH bulk - ")
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    records =
      Enum.chunk_every(records, 10)
      |> Enum.map(fn set ->
        Map.merge(%{}, %{"records" => set, "typecast" => true})
        |> Jason.encode!()
      end)

    Enum.each(records, fn record_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(record_subset, headers, params)
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord do
  @moduledoc """
  Module to POST new records to the Legal Register

  """
  @doc """
  Receives the map of a new Law for POST to the Legal Register BASE
  """
  @spec run(map() | list(), map()) :: :ok
  def run([], _), do: {:error, "RECORDS: EMPTY LIST: No data to Post"}

  def run(record, opts) when is_map(record), do: run([record], opts)

  def run(records, %{drop_fields: drop_fields} = opts) when is_list(records) do
    with(
      records <- Legl.Countries.Uk.LeglRegister.Helpers.clean_records(records, drop_fields),
      json =
        Map.merge(%{}, %{"records" => records, "typecast" => true}) |> Jason.encode!(pretty: true),
      :ok = Legl.Utility.save_at_records_to_file(json, opts.api_post_path),
      :ok <- post(records, opts)
    ) do
      :ok
    end
  end

  def run(_records, _opts), do: {:error, "OPTS: No :drop_fields list in opts"}

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
        Map.merge(%{}, %{"records" => set, "typecast" => true})
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(records, fn subset ->
      Legl.Services.Airtable.AtPost.post_records(subset, headers, params)
    end)
  end
end
