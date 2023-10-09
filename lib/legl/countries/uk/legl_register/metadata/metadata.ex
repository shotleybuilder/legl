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
      md_total_paras: nil,
      md_body_paras: nil,
      md_schedule_paras: nil,
      md_attachment_paras: nil,
      md_images: nil,
      md_error_code: ""
    }
  ]

  @get_fields ~w[
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
    md_change_log
  ]

  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Services.Airtable.AtBasesTables

  alias Legl.Countries.Uk.Metadata.Delta
  alias Legl.Countries.Uk.Metadata.Csv
  alias Legl.Countries.Uk.LeglRegister.Metadata.Patch

  @source_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata_source.json]
  @raw_results_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata_raw_results.json]
  @results_path ~s[lib/legl/countries/uk/legl_register/metadata/metadata_results.json]

  @default_opts %{
    type_code: nil,
    type_class: nil,
    base_name: "UK E",
    table: "UK",
    # source of Airtable records
    source: :web,
    # source of legislation-gov-uk records
    md: :web,
    workflow: nil,
    family: nil,
    filesave?: true,
    csv?: true,
    patch?: true,
    patch_as_you_go?: false
  }
  @doc """
    Legl.Countries.Uk.UkLegGovUkMetadata.workflow()
  """
  def run(opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    with {:ok, type_codes} <- Legl.Countries.Uk.UkTypeCode.type_code(opts.type_code),
         {:ok, type_classes} <- Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class),
         {:ok, family} <- Legl.Countries.Uk.Family.family(opts.family),
         opts =
           Map.merge(opts, %{type_code: type_codes, type_class: type_classes, family: family}),
         {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name),
         opts = Map.merge(opts, %{base_id: base_id, table_id: table_id}),
         opts = fields(opts) do
      if opts.workflow != nil do
        Enum.each(
          type_codes,
          fn type ->
            opts = formula(opts, type)

            opts
            |> IO.inspect(label: "\nOptions: ")
            |> workflow()
          end
        )
      end
    end
  end

  defp fields(%{source: :web, workflow: :update} = opts) do
    Map.merge(opts, %{
      fields: ["Title_EN", "leg.gov.uk intro text"] ++ @get_fields
    })
  end

  defp fields(%{source: :web} = opts) do
    Map.merge(opts, %{
      fields: ["Name", "Title_EN", "leg.gov.uk intro text"]
    })
  end

  defp fields(opts), do: opts

  defp formula(%{source: :web, workflow: :update} = opts, type) do
    # date = Date.utc_today()
    # date = ~s(#{date.day}/#{date.month}/#{date.year})
    # date = ~s/#{Date.utc_today()}/

    Map.merge(opts, %{
      # formula: ~s/AND({type_code}="#{type}", {Family}="#{opts.family}", {md_checked}!="#{date}")/
      formula: ~s/AND({type_code}="#{type}", {Family}="#{opts.family}", {md_checked}!=TODAY())/
    })
  end

  defp formula(%{source: :web} = opts, type) do
    Map.merge(opts, %{formula: ~s/AND({type_code}="#{type}", {md_modified}=BLANK())/})
  end

  defp formula(opts, _type), do: opts

  defp workflow(%{md: :file} = opts) do
    # when legislation.gov.uk records have been saved to file
    {:ok, records} = get_metadata(opts)
    Patch.patch(records, opts)
  end

  defp workflow(opts) do
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

  defp get(%{source: :web} = opts) do
    with(
      params = %{
        base: opts.base_id,
        table: opts.table_id,
        options: %{
          fields: opts.fields,
          formula: opts.formula
        }
      },
      {:ok, {jsonset, _recordset}} <- Records.get_records({[], []}, params)
    ) do
      if opts.filesave? == true,
        do: Legl.Utility.save_at_records_to_file(~s/#{jsonset}/, @source_path)

      %{records: records} = Jason.decode!(jsonset, keys: :atoms)
      # IO.inspect(records)
      IO.puts("#{Enum.count(records)} records returned from Airtable")

      add_empty_fields(records)
      |> (&{:ok, &1}).()
    else
      {:error, error} -> {:error, error}
    end
  end

  defp get(%{source: :file} = _opts) do
    json = @source_path |> Path.absname() |> File.read!()
    %{records: records} = Jason.decode!(json, keys: :atoms)

    add_empty_fields(records)
    |> (&{:ok, &1}).()
  end

  defp add_empty_fields(records) do
    # Airtable doesn't return empty fields.  md_change_log starts life empty
    Enum.reduce(records, [], fn record, acc ->
      fields =
        Map.put_new(record.fields, :md_change_log, "")
        |> Map.put_new(:md_subjects, [])

      [%{record | fields: fields} | acc]
    end)
  end

  defp get_metadata(%{current_records: current_records, md: :web} = opts) do
    Enum.reduce(current_records, [], fn %{fields: current_fields} = record, acc ->
      path = resource_path(current_fields)

      with({:ok, metadata} <- get_latest_metadata(path)) do
        IO.puts("#{current_fields[:Title_EN]}")

        metadata =
          case opts.workflow == :update do
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

  defp get_metadata(%{md: :file} = _opts) do
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

  defp get_latest_metadata(path) do
    with({:ok, :xml, metadata} <- Record.legislation(path)) do
      # save the data returned from leg.gov.uk w/o transformation
      json = Map.put(%{}, "records", metadata) |> Jason.encode!()
      Legl.Utility.append_records_to_file(~s/#{json}/, @raw_results_path)

      %{
        # subject shape ["foo", "bar", ...]
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

      # the field is called 'SI Code' in Airtable
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
            |> Enum.map(&String.replace(&1, ",WALES", ""))
            |> (&Map.put(metadata, :"SI Code", &1)).()
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
  @api_results_path ~s[lib/legl/countries/uk/legl_register/metadata/api_metadata_results.json]

  def patch(records, %{patch?: false, patch_as_you_go?: true} = opts) do
    IO.write("PATCH payg - ")
    records = clean_records_for_patch(records)
    process(records, opts)
  end

  def patch(records, %{patch?: true, patch_as_you_go?: false} = opts) do
    IO.write("PATCH bulk - ")
    records = clean_records_for_patch(records)

    json = Map.put(%{}, "records", records) |> Jason.encode!()
    Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_results_path)

    process(records, opts)
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
  ] |> Enum.map(&String.to_atom(&1))

  def compare_fields(current_fields, latest_fields) do
    Enum.reduce(@compare_fields, [], fn field, acc ->
      current = Map.get(current_fields, field)
      latest = Map.get(latest_fields, field)

      case changed?(current, latest) do
        false ->
          acc

        value ->
          Keyword.put(acc, field, value)
      end
    end)
    |> md_change_log()
    |> (&Kernel.<>(current_fields.md_change_log, &1)).()
    |> String.trim_leading("📌")
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

  defp md_change_log([]), do: ""

  defp md_change_log(changes) do
    IO.inspect(changes)
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

  @letter_widths %{
    :a => 4,
    :b => 4,
    :c => 4,
    :d => 4,
    :e => 4,
    :f => 3,
    :g => 4,
    :h => 4,
    :i => 3,
    :j => 2,
    :k => 2,
    :l => 1,
    :m => 6,
    :n => 4,
    :o => 4,
    :p => 4,
    :q => 4,
    :r => 3,
    :s => 4,
    :t => 3,
    :u => 4,
    :v => 3,
    :w => 6,
    :x => 4,
    :y => 4,
    :z => 4,
    :_ => 3
  }

  defp string_width(value) do
    value = ~s/#{value}/

    value
    |> String.split("", trim: true)
    |> Enum.reduce(0, fn letter, acc ->
      acc + Map.get(@letter_widths, String.to_atom(letter))
    end)

    # |> (&Kernel.+(&1, String.length(value))).()
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
             "SI Code": si_code,
             md_change_log: md_change_log
           }
         } = _md
       ) do
    ~s/#{name},#{Legl.Utility.todays_date()},"#{description}",#{subjects},#{modified},#{total},#{body},#{schedule},#{attachment},#{images},,"#{si_code}"","#{md_change_log}"/
  end
end
