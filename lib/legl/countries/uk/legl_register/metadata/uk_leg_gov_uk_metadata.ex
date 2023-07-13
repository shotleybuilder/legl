defmodule Legl.Countries.Uk.UkLegGovUkMetadata do
  @moduledoc """
    This module gets the following properties from legislation.gov.uk
    and creates a .csv file for upload into Airtable
      - description
      - date modified
      - subject tags
      - total # paragraphs
      - # body paragraphs
      - # schedule paragraphs
      - # attachment paragraphs
      - # images

    Shape of the returned record from airtable
    [
      %{"createdTime" => "2023-03-07T12:14:04.000Z",
      "fields" =>
        %{
          "Name" => "UK_ukpga_2000_7_ECA",
          "Title_EN" => "Electronic Communications Act",
          "leg.gov.uk intro text" =>
            "http://www.legislation.gov.uk/ukpga/2000/7/introduction/made/data.xml"
        },
      "id" => "recYPSwJaKoxMFkI6"}
    ]

    Shape of the returned record from legislation.gov.uk

    %Legl.Services.LegislationGovUk.Record{
      metadata: %{
        description: "This Order consolidates the Air Navigation (No. 2) Order 1995, as amended. In addition to some minor drafting amendments the following new provisions are added.",
        images: '3',
        modified: "2017-01-10",
        paras_total: '254',
        paras_body: '134',
        paras_schedule: '120',
        paras_attachment: '0',
        pdf_href: "http://www.legislation.gov.uk/uksi/2000/1562/introduction/made/data.pdf",
        si_code: "CIVIL AVIATION",
        subject: ["public transport", "air transport", "dangerous animal licences",
        "traffic management", "navigation"],
        title: "The Air Navigation Order 2000"
      }
    }

    Workflow

    1. Run get_records_from_at/3 which saves records to airtable.txt
    2. Copy paste into airtable_data.ex
    3. Run enumerate_at_records/1 which saves to airtable_properties.csv

  """
  defstruct [
    :id,
    fields: %{
      Title_EN: "",
      "leg.gov.uk intro text": "",
      md_description: "",
      md_subjects: "",
      md_modified: "",
      md_total_paras: nil,
      md_body_paras: nil,
      md_schedule_paras: nil,
      md_attachment_paras: nil,
      md_images: nil,
      md_error_code: ""
    }
  ]

  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Services.Airtable.AtBasesTables

  @path ~s[lib/legl/countries/uk/legl_register/metadata/metadata_source.json]
  @results_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata_results.json]
  @api_results_path ~s[lib/legl/countries/uk/legl_register/metadata/api_metadata_results.json]
  @csv_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata.csv]

  @at_types ["nisro"]
  @at_csv "airtable_metadata"

  @default_opts %{
    types: @at_types,
    csv: @at_csv,
    base: "UK E",
    table: "UK",
    filesave?: true,
    csv?: true,
    source: :web,
    patch?: true
  }
  @doc """
    Legl.Countries.Uk.UkLegGovUkMetadata.workflow()
  """
  def workflow(opts \\ []) do
    opts = Enum.into(opts, @default_opts)
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})
    IO.inspect(opts, label: "\nOptions: ")
    Enum.each(opts.types, fn type -> workflow(opts, type) end)
  end

  defp workflow(opts, type) do
    with(
      {:ok, recordset} <- get(opts, type),
      {:ok, records} <- get_metadata(recordset)
    ) do
      if opts.filesave? == true do
        json = Map.put(%{}, "records", records) |> Jason.encode!()
        Legl.Utility.save_at_records_to_file(~s/#{json}/, @results_path)
      end

      if opts.csv? == true do
        csv_header_row(@csv_path)

        Enum.each(
          records,
          &make_csv(&1, @csv_path)
        )
      end

      records = clean_records_for_patch(records)

      if opts.patch? == true, do: patch(records, opts)
    else
      {:error, error} ->
        IO.puts("ERROR workflow/2 #{error}")
    end
  end

  defp get(%{source: :web} = opts, type) do
    with(
      params = %{
        base: opts.base_id,
        table: opts.table_id,
        options: %{
          fields: ["Name", "Title_EN", "leg.gov.uk intro text"],
          formula: ~s/{type_code}="#{type}"/
        }
      },
      {:ok, {jsonset, _recordset}} <- Records.get_records({[], []}, params)
    ) do
      if opts.filesave? == true,
        do: Legl.Utility.save_at_records_to_file(~s/#{jsonset}/, @path)

      %{records: records} = Jason.decode!(jsonset, keys: :atoms)

      IO.puts("#{Enum.count(records)} records returned from Airtable")

      {:ok, records}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp get(%{source: :file} = _opts, _) do
    json = @path |> Path.absname() |> File.read!()
    %{records: records} = Jason.decode!(json, keys: :atoms)
    {:ok, records}
  end

  defp get_metadata(records) do
    Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
      path = resource_path(Map.get(fields, :"leg.gov.uk intro text"))

      with({:ok, metadata} <- get_field(path)) do
        IO.puts("#{fields[:Title_EN]}")
        fields = Map.merge(record[:fields], metadata)
        [%{record | fields: fields} | acc]
      else
        {:error, error} ->
          IO.puts("ERROR #{error.md_error_code} with #{fields[:Title_EN]}")
          fields = Map.merge(record[:fields], error)
          [%{record | fields: fields} | acc]
      end
    end)

    # {:ok, "metadata properties saved to csv"}
    |> (&{:ok, &1}).()
  end

  defp resource_path(url) do
    [_, path] = Regex.run(~r"^http:\/\/www.legislation.gov.uk(.*)", url)
    path
    # "#{path}/data.xml"
  end

  defp get_field(url) do
    with({:ok, :xml, metadata} <- Record.legislation(url)) do
      %{
        md_subjects: subject,
        md_total_paras: total,
        md_body_paras: body,
        md_schedule_paras: schedule,
        md_attachment_paras: attachment,
        md_images: images,
        md_modified: modified,
        si_code: si_code
      } = metadata

      # %{fields: fields} = record = struct(%__MODULE__{}, record)

      metadata =
        case subject do
          [] ->
            metadata

          _ ->
            Enum.join(subject, ",")
            |> Legl.Utility.csv_quote_enclosure()
            |> (&Map.put(metadata, :md_subjects, [&1])).()
        end

      # the field is called 'SI Code' in Airtable
      metadata =
        case si_code do
          [] ->
            metadata

          _ ->
            String.split(si_code, ";")
            |> Enum.join(",")
            |> Legl.Utility.csv_quote_enclosure()
            |> (&Map.put(metadata, :"SI Code", &1)).()

            # |> Enum.reduce([], fn si_code, acc ->
            #  Legl.Utility.csv_quote_enclosure(si_code)
            #  |> (&[&1 | acc]).()
            # end)
        end

      [_, year, month, day] = Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, modified)

      xMetadata = %{
        md_modified_csv: "#{day}/#{month}/#{year}",
        md_total_paras: convert_to_i(total),
        md_body_paras: convert_to_i(body),
        md_schedule_paras: convert_to_i(schedule),
        md_attachment_paras: convert_to_i(attachment),
        md_images: convert_to_i(images)
      }

      Map.merge(metadata, xMetadata)
      |> (&{:ok, &1}).()
    else
      {:error, code, error} -> {:error, %{md_error_code: "#{code}: #{error}"}}
      {:ok, :html} -> {:error, %{md_error_code: :html}}
    end
  end

  def convert_to_i(nil), do: nil

  def convert_to_i(value) when is_list(value) do
    to_string(value) |> String.to_integer()
  end

  def convert_to_i(value) when is_binary(value) do
    String.to_integer(value)
  end

  defp clean_records_for_patch(records) do
    # Discard data we don't need to send back to Airtable
    records =
      Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
        Map.drop(fields, [
          :Name,
          :Title_EN,
          :"leg.gov.uk intro text",
          :md_modified_csv,
          :si_code,
          :title,
          :pdf_href
        ])
        |> (&Map.put(record, :fields, &1)).()
        |> (&Map.drop(&1, [:createdTime])).()
        |> (&[&1 | acc]).()
      end)

    # Discard any data w/o values
    Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
      xfield =
        Enum.reduce(fields, %{}, fn {k, v}, xfield ->
          case v do
            "" -> xfield
            [] -> xfield
            [""] -> xfield
            _ -> Map.put(xfield, k, v)
          end
        end)

      Map.put(record, :fields, xfield)
      |> (&[&1 | acc]).()
    end)
  end

  defp patch(results, opts) do
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

    if opts.filesave? == true do
      Legl.Utility.save_at_records_to_file(~s/#{results}/, @api_results_path)
    end

    Enum.each(results, fn result_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(result_subset, headers, params)
    end)
  end

  @fields ~w[
    Name
    md_description
    md_subjects
    md_modified
    md_total_paras
    md_body_paras
    md_schedule_paras
    md_attachment_paras
    md_images
    md_error_code
    "SI\u00a0Code"
  ]

  def csv_header_row(path) do
    Enum.join(@fields, ",")
    |> Legl.Utility.write_to_csv(path)
  end

  @doc """
    .csv has this structure

  """
  def make_csv(
        %{
          fields: %{
            Name: name,
            md_error_code: md_error_code
          }
        } = _md,
        path
      ) do
    ~s/#{name},,,,,,,,,#{md_error_code}/
    |> save_to_csv(path)
  end

  def make_csv(
        %{
          fields: %{
            Name: name,
            md_description: description,
            md_subjects: subjects,
            md_total_paras: total,
            md_body_paras: body,
            md_schedule_paras: schedule,
            md_attachment_paras: attachment,
            md_images: images,
            md_modified_csv: modified,
            "SI Code": si_code
          }
        } = _md,
        path
      ) do
    ~s/#{name},"#{description}",#{subjects},#{modified},#{total},#{body},#{schedule},#{attachment},#{images},,#{si_code}/
    |> save_to_csv(path)
  end

  def save_to_csv(binary, path) do
    {:ok, file} =
      path
      |> Path.absname()
      |> File.open([:utf8, :append])

    IO.puts(file, binary)
    File.close(file)
    :ok
  end
end
