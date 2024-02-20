defmodule Legl.Countries.Uk.Metadata do
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

    Shape of the returned record from Airtable for a new record
    [
      %{
        createdTime: "2023-03-07T12:14:04.000Z",
        fields:
          %{
            Name: "UK_ukpga_2000_7_ECA",
            Title_EN: "Electronic Communications Act",
            "leg.gov.uk intro text":
              "http://www.legislation.gov.uk/ukpga/2000/7/introduction/made/data.xml"
          },
        id: "recYPSwJaKoxMFkI6"
      }
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
      md_made_date: "",
      md_coming_into_force_date: "",
      md_total_paras: nil,
      md_body_paras: nil,
      md_schedule_paras: nil,
      md_attachment_paras: nil,
      md_images: nil,
      md_error_code: ""
    }
  ]

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Services.LegislationGovUk.Url
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Services.LegislationGovUk.RecordGeneric, as: Record

  alias Legl.Countries.Uk.Metadata.Delta
  alias Legl.Countries.Uk.Metadata.Csv
  alias Legl.Countries.Uk.LeglRegister.Metadata.Patch
  alias Legl.Countries.Uk.LeglRegister.Metadata.Options

  @source_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata_source.json]
  @results_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata_results.json]

  @doc """

  """
  def run(opts \\ []) do
    Options.set_options(opts)
    |> workflow()
  end

  defp workflow(%{leg_gov_uk_source: :file} = opts) do
    # when legislation.gov.uk records have been saved to file
    {:ok, records} = get_metadata(opts)
    Patch.patch(records, opts)
  end

  @spec workflow(map()) :: :ok
  defp workflow(%{workflow: :update} = opts) do
    get(opts)
    |> AT.strip_id_and_createdtime_fields()
    |> AT.make_records_into_legal_register_structs()
    |> Enum.map(&get_latest_metadata(&1))
    |> Legl.Utility.maps_from_structs()
    |> Legl.Utility.map_filter_out_empty_members()
    |> Legl.Utility.save_structs_as_json_returning(@results_path, opts)
    |> Enum.each(&Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(&1, opts))
  end

  defp workflow(%{workflow: :delta} = opts) do
    with(
      {:ok, recordset} <- get(opts),
      opts = Map.put(opts, :current_records, recordset),
      if opts.csv? == true do
        Csv.csv_header_row()
      end,
      {:ok, records} <- get_metadata(opts)
    ) do
      if opts.filesave? == true do
        json = Map.put(%{}, "records", records) |> Jason.encode!()
        Legl.Utility.save_at_records_to_file(~s/#{json}/, @results_path)
      end

      Patch.patch(records, opts)
    else
      {:error, error} ->
        IO.puts("ERROR workflow/2 #{error}")
    end
  end

  defp get(%{source: :file} = _opts) do
    json = @source_path |> Path.absname() |> File.read!()

    %{records: records} =
      Jason.decode!(json, keys: :atoms)
      |> (&{:ok, &1}).()

    records
  end

  defp get(%{at_source: :web} = opts) do
    AT.get_records_from_at(opts)
    |> elem(1)
    |> Jason.encode!()
    |> Jason.decode!(keys: :atoms)
  end

  defp get_metadata(%{current_records: current_records, leg_gov_uk_source: :web} = opts) do
    Enum.reduce(current_records, [], fn %{fields: current_fields} = record, acc ->
      path = resource_path(current_fields)

      with({:ok, metadata} <- get_latest_metadata(path)) do
        IO.puts("#{current_fields[:Title_EN]}")

        metadata =
          case opts.workflow == :delta do
            true ->
              md_change_log = Delta.compare_fields(current_fields, metadata)
              Map.put(metadata, :md_change_log, md_change_log)

            false ->
              metadata
          end

        fields = Map.merge(record[:fields], metadata)
        record = %{record | fields: fields}

        # save to .csv within the loop in case there is a problem halfway
        # through processing a long list of laws
        if opts.csv? == true do
          Csv.csv(record)
        end

        Patch.patch([record], opts)

        [record | acc]
      else
        {:error, error} ->
          IO.puts("ERROR #{error.md_error_code} with #{current_fields[:Title_EN]}")
          fields = Map.merge(record[:fields], error)
          [%{record | fields: fields} | acc]
      end
    end)

    # {:ok, "metadata properties saved to csv"}
    |> (&{:ok, &1}).()
  end

  defp get_metadata(%{leg_gov_uk_source: :file} = _opts) do
    json = @results_path |> Path.absname() |> File.read!()
    %{records: records} = Jason.decode!(json, keys: :atoms)
    {:ok, records}
  end

  defp resource_path(fields) do
    url = Map.get(fields, :"leg.gov.uk intro text")
    [_, path] = Regex.run(~r"^http:\/\/www.legislation.gov.uk(.*)", url)
    path
    # "#{path}/data.xml"
  end

  @doc """
  API for metadata

  Receives the path to the law's Intro web content

  Returns the metadata map
  """
  @spec get_latest_metadata(struct(), map()) :: {:ok, struct()}
  @spec get_latest_metadata(map(), map()) :: {:ok, map()}
  @spec get_latest_metadata(binary()) :: {:ok, map()}
  def get_latest_metadata(record, opts \\ %{workflow: :update})

  def get_latest_metadata(%LegalRegister{} = record, opts)
      when is_struct(record) do
    IO.write(" METADATA")
    url = Url.introduction_path(record)
    {:ok, metadata} = get_latest_metadata(url)

    md_change_log =
      case opts.workflow |> Atom.to_string() |> String.contains?("Delta") do
        true ->
          Delta.compare_fields(record, metadata)

        false ->
          ""
      end

    record =
      if record."Title_EN" == "",
        do: Map.put(record, :Title_EN, metadata."Title_EN"),
        else: record

    metadata =
      metadata
      |> Map.put(:md_change_log, md_change_log)
      |> Map.drop([:pdf_href, :md_modified_csv, :md_subjects_csv, :title])
      |> Map.put(:md_checked, ~s/#{Date.utc_today()}/)

    {:ok, Kernel.struct(record, metadata)}
  rescue
    e ->
      IO.puts(
        ~s/\nERROR: #{record."Title_EN"} #{record.type_code} #{record."Number"} #{record."Year"}\n#{inspect(e)}\n#{__MODULE__}.get_latest_metadata\n/
      )

      {:ok, record}
  end

  def get_latest_metadata(record, _) when is_map(record) do
    IO.write(" METADATA -> map")
    url = Url.introduction_path(record)
    {:ok, metadata} = get_latest_metadata(url)
    metadata = Map.drop(metadata, [:pdf_href, :md_modified_csv, :md_subjects_csv])
    {:ok, Map.merge(record, metadata)}
  rescue
    _ -> {:error}
  end

  def get_latest_metadata(path, _) when is_binary(path) do
    with({:ok, :xml, metadata} <- Record.metadata(path)) do
      # save the data returned from leg.gov.uk w/o transformation
      # json = Map.put(%{}, "records", metadata) |> Jason.encode!()
      # Legl.Utility.append_records_to_file(~s/#{json}/, @raw_results_path)

      # IO.inspect(metadata)

      %{
        # subject shape ["foo", "bar", ...]
        md_subjects: subject,
        md_total_paras: total,
        md_body_paras: body,
        md_schedule_paras: schedule,
        md_attachment_paras: attachment,
        md_images: images,
        md_modified: modified,
        # md_made_date: made,
        # md_coming_into_force_date: force,
        # md_restrict_start_date,
        si_code: si_code,
        Title_EN: title
      } = metadata

      metadata =
        Legl.Airtable.AirtableTitleField.title_clean(title)
        |> (&Map.put(metadata, :Title_EN, &1)).()

      metadata =
        case subject do
          [] ->
            metadata

          _ ->
            subject
            |> Enum.map(&String.replace(&1, ", england and wales", ""))
            |> Enum.map(&String.replace(&1, ", england", ""))
            |> (&Map.put(metadata, :md_subjects, &1)).()
        end

      # :md_subjects_csv either [] or [\""foo,bar,baz"\"]
      metadata =
        case metadata.md_subjects do
          [] ->
            Map.put(metadata, :md_subjects_csv, [])

          subject ->
            subject
            |> Enum.join(",")
            |> Legl.Utility.csv_quote_enclosure()
            |> (&Map.put(metadata, :md_subjects_csv, [&1])).()
        end

      # the field is called 'si_code' in Airtable
      metadata =
        case si_code do
          [] ->
            metadata

          _ ->
            String.split(si_code, ";")
            |> Enum.map(&String.upcase(&1))
            |> Enum.map(&String.replace(&1, ", ENGLAND AND WALES", ""))
            |> Enum.map(&String.replace(&1, ", ENGLAND & WALES", ""))
            |> Enum.map(&String.replace(&1, ", WALES", ""))
            |> Enum.map(&String.replace(&1, ", ENGLAND", ""))
            |> Enum.map(&String.replace(&1, ", SCOTLAND", ""))
            |> Enum.map(&String.replace(&1, ", NORTHERN IRELAND", ""))
            |> Enum.map(&String.replace(&1, ", WALES", ""))
            |> Enum.join(",")
            |> (&Map.put(metadata, :si_code, &1)).()
        end

      [_, year, month, day] = Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, modified)

      xMetadata = %{
        md_modified_csv: "#{day}/#{month}/#{year}",
        md_total_paras: convert_to_i(total),
        md_body_paras: convert_to_i(body),
        md_schedule_paras: convert_to_i(schedule),
        md_attachment_paras: convert_to_i(attachment),
        md_images: convert_to_i(images),
        SICode: [metadata.si_code]
      }

      {:ok, Map.merge(metadata, xMetadata)}
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
end

defmodule Legl.Countries.Uk.LeglRegister.Metadata.Patch do
  @moduledoc """
  """
  alias Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord

  @api_results_path ~s[lib/legl/countries/uk/legl_register/metadata/api_metadata_results.json]

  def patch(records, %{patch?: false, patch_as_you_go?: true} = opts) do
    IO.write("PATCH payg - ")
    records = clean_records_for_patch(records)
    PatchRecord.patch(records, opts)
  end

  def patch(records, %{patch?: true, patch_as_you_go?: false} = opts) do
    IO.write("PATCH bulk - ")
    records = clean_records_for_patch(records)

    json = Map.put(%{}, "records", records) |> Jason.encode!()
    Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_results_path)

    PatchRecord.patch(records, opts)
  end

  def patch(_, _), do: :ok

  defp clean_records_for_patch(records) do
    # Discard data we don't need to send back to Airtable
    records =
      Enum.reduce(records, [], fn %{fields: fields} = record, acc ->
        Map.drop(fields, [
          :Name,
          :Title_EN,
          :"leg.gov.uk intro text",
          :md_modified_csv,
          :md_subjects_csv,
          :si_code,
          :title,
          :pdf_href
        ])
        # add today's date for the check
        |> Map.put(:md_checked, ~s/#{Date.utc_today()}/)
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
end

defmodule Legl.Countries.Uk.Metadata.Delta do
  @field_paddings %{
    :md_description => 20,
    :md_subjects => 24,
    :md_modified => 23,
    :md_total_paras => 18,
    :md_body_paras => 18,
    :md_schedule_paras => 11,
    :md_attachment_paras => 6,
    :md_images => 26
  }

  @compare_fields ~w[
    md_description
    md_subjects
    md_modified
    md_total_paras
    md_body_paras
    md_schedule_paras
    md_attachment_paras
    md_images
  ]a

  def compare_fields(current_fields, latest_fields) do
    IO.write(" DELTA_MD")

    this_log =
      Enum.reduce(@compare_fields, [], fn field, acc ->
        current = Map.get(current_fields, field)
        latest = Map.get(latest_fields, field)

        cond do
          field == "md_description" ->
            if String.jaro_distance(current, latest) > 0.8,
              do: acc,
              else:
                Keyword.put(
                  acc,
                  field,
                  ~s/#{Enum.join(current, ", ")} -> #{Enum.join(latest, ", ")}/
                )

          true ->
            case changed?(current, latest) do
              false ->
                acc

              value ->
                Keyword.put(acc, field, value)
            end
        end
      end)
      |> md_change_log()

    case Map.get(current_fields, :md_change_log) do
      nil -> this_log
      "" -> this_log
      value -> ~s/#{value}\n#{this_log}/
    end
  end

  defp changed?(current, latest) when current in [nil, "", []] and latest not in [nil, "", []],
    do: false

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

  defp md_change_log([]), do: ""

  defp md_change_log(changes) do
    # IO.inspect(changes)
    # Returns the metadata changes as a formated multi-line string
    date = Date.utc_today()
    date = ~s(#{date.day}/#{date.month}/#{date.year})

    Enum.reduce(changes, ~s/#{date}\n/, fn {k, v}, acc ->
      # width = 80 - string_width(k)
      width = Map.get(@field_paddings, k)
      k = ~s/#{k}#{Enum.map(1..width, fn _ -> "." end) |> Enum.join()}/
      # k = String.pad_trailing(~s/#{k}/, width, ".")
      ~s/#{acc}#{k}#{v}\n/
    end)
    |> String.trim_trailing("\n")
  end
end

defmodule Legl.Countries.Uk.Metadata.Csv do
  @moduledoc """
    .csv has this structure

  """
  @csv_fields ~w[
      Name
      md_checked
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
      md_change_log
    ]

  @csv_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata.csv]

  def csv_header_row() do
    Enum.join(@csv_fields, ",")
    |> Legl.Utility.write_to_csv(@csv_path)
  end

  def csv(record) do
    {:ok, file} =
      @csv_path
      |> Path.absname()
      |> File.open([:utf8, :append])

    make_csv(record)
    |> (&IO.puts(file, &1)).()

    File.close(file)
  end

  defp make_csv(
         %{
           fields: %{
             Name: name,
             md_error_code: md_error_code
           }
         } = _md
       ) do
    ~s/#{name},,,,,,,,,,#{md_error_code}/
  end

  defp make_csv(
         %{
           fields: %{
             Name: name,
             md_change_log: ""
           }
         } = _md
       ) do
    ~s/#{name},#{Legl.Utility.todays_date()}/
  end

  defp make_csv(
         %{
           fields: %{
             Name: name,
             md_description: description,
             md_subjects_csv: subjects,
             md_total_paras: total,
             md_body_paras: body,
             md_schedule_paras: schedule,
             md_attachment_paras: attachment,
             md_images: images,
             md_modified_csv: modified,
             si_code: si_code,
             md_change_log: md_change_log
           }
         } = _md
       ) do
    ~s/#{name},#{Legl.Utility.todays_date()},"#{description}",#{subjects},#{modified},#{total},#{body},#{schedule},#{attachment},#{images},,"#{si_code}"","#{md_change_log}"/
  end
end
