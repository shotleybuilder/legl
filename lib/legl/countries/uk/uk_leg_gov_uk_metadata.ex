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

  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Services.Airtable.AtBasesTables

  @at_type ["nisro"]
  @at_csv "airtable_metadata"

  def full_workflow() do
    Enum.each(@at_type, fn x -> full_workflow(x) end)
  end

  def full_workflow(type) do
    with(
      {:ok, recordset} <- get_records_from_at("UK E", type, false),
      {:ok, msg} <- enumerate_at_records(recordset)
    ) do
      IO.puts(msg)
    end
  end

  @doc """
    Accessor prepopulated with parameters
  """
  def get_records_from_at() do
    get_records_from_at("UK E", @at_type, true)
  end

  @doc """
    Legl.Countries.Uk.UkLegGovUkProperties.get_records_from_at("UK E", "ukpga", true)
  """
  def get_records_from_at(base_name, type, filesave?) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
            view: "LGUK_PROPERTIES",
            fields: ["Name", "Title_EN", "leg.gov.uk intro text"],
            formula: ~s/{type}="#{type}"/
          }
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      IO.puts("Records returned from Airtable")
      if filesave? == true do save_at_to_file(recordset) end
      if filesave? == false do {:ok, recordset} end
    else
      {:error, error} -> {:error, error}
    end
  end

  def save_at_to_file(records) when is_list(records) do
    {:ok, file} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.open([:read, :utf8, :write])
    IO.puts(file, inspect(records, limit: :infinity))
    File.close(file)
    :ok
  end

  #
  # Getting and saving data from legislation.gov.uk
  #

  @doc """
    Accessor that pulls the records previously saved to airtable_data.ex
    iex ->
    Legl.Countries.Uk.UkLegGovUkMetadata.enumerate_at_records()
  """
  def enumerate_at_records() do
    Airtable.at_data()
    |> enumerate_at_records()
  end

  def enumerate_at_records(records) do
    csv_header_row()
    Enum.each(records, fn x ->
      fields = Map.get(x, "fields")
      path = resource_path(Map.get(fields, "leg.gov.uk intro text"))
      #IO.inspect(path)
      with(
        {:ok, record} <- get_properties_from_legislation_gov_uk(path)
        #IO.inspect(record)
      ) do
        fields = Map.merge(x["fields"], record)
        record = %{x | "fields" => fields}
        make_csv(record, @at_csv)
        IO.puts("#{fields["Title_EN"]}")
      else
        {:error, error} ->
          IO.puts("ERROR #{error} with #{fields["Title_EN"]}")
        {:error, :html} ->
          IO.puts(".html from #{fields["Title_EN"]}")
      end
    end)
    {:ok, "metadata properties saved to csv"}
    #|> (&{:ok, &1}).()
  end

  def resource_path(url) do
    [_, path] = Regex.run(~r"^http:\/\/www.legislation.gov.uk(.*)", url)
    path
    #"#{path}/data.xml"
  end

  def get_properties_from_legislation_gov_uk(url) do

    with(
      {:ok, :xml, %{metadata: md}} <- Record.legislation(url)
    ) do
      %{
        md_subjects: subject,
        md_total_paras: total,
        md_body_paras: body,
        md_schedule_paras: schedule,
        md_attachment_paras: attachment,
        md_images: images,
        md_modified: modified
      } = md
      subject =
        Enum.join(subject, ",")
        |> Legl.Utility.csv_quote_enclosure()
      [_, year, month, day] =
        Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, modified)
      modified =
        "#{day}/#{month}/#{year}"
      Map.merge(md,
        %{
          md_subjects: subject,
          md_total_paras: convert_to_i(total),
          md_body_paras: convert_to_i(body),
          md_schedule_paras: convert_to_i(schedule),
          md_attachment_paras: convert_to_i(attachment),
          md_images: convert_to_i(images),
          md_modified: modified
        })
    #|> IO.inspect()
      |> (&{:ok, &1}).()
    else
      {:error, code, error} -> {:error, "#{code}: #{error}"}
      {:ok, :html} -> {:error, :html}
    end

  end

  def convert_to_i(nil), do: nil
  def convert_to_i(value) when is_list(value) do
    to_string(value) |> String.to_integer()
  end
  def convert_to_i(value) when is_binary(value) do
    String.to_integer(value)
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
  ]

  def csv_header_row() do
    Enum.join(@fields, ",")
    |> save_to_csv(@at_csv)
  end
  @doc """
    .csv has this structure

  """
  def make_csv(
    %{"fields" =>
      %{
        "Name" => name,
        md_description: description,
        md_subjects: subjects,
        md_total_paras: total,
        md_body_paras: body,
        md_schedule_paras: schedule,
        md_attachment_paras: attachment,
        md_images: images,
        md_modified: modified
      }
    } = _md, filename)
  do
    ~s/#{name},"#{description}",#{subjects},#{modified},#{total},#{body},#{schedule},#{attachment},#{images}/
    |> save_to_csv(filename)
  end

  def save_to_csv(binary, filename) do
    {:ok, file} =
      "lib/#{filename}.csv"
      |> Path.absname()
      |> File.open([:utf8, :append])
    IO.puts(file, binary)
    File.close(file)
    :ok
  end
end
