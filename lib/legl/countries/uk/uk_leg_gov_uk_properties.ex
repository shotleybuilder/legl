defmodule Legl.Countries.Uk.UkLegGovUkProperties do
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

  """

  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.Record
  alias Legl.Services.Airtable.AtBasesTables

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
      if filesave? == true do save_to_file(recordset) end
      #make_csv(recordset, "airtable_properties")
    else
      {:error, error} -> {:error, error}
    end
  end

  def enumerate_at_records(records) do
    Enum.map(records, fn x ->
      fields = Map.get(x, "fields")
      path = resource_path(Map.get(fields, "leg.gov.uk intro text"))
      with(
        {:ok, record} <- get_properties_from_legislation_gov_uk(path)
      ) do
        record
      else
        {:error, error} -> {:error, error}
      end
    end)
    |> (&{:ok, &1}).()
  end

  def resource_path(url) do
    [_, path] = Regex.run(~r"^http:\/\/www.legislation.gov.uk(.*)", url)
    "#{path}/data.xml"
  end

  def get_properties_from_legislation_gov_uk(url) do

    with(
      {:ok, :xml, %{metadata: md}} <- Record.legislation(url)
    ) do
      #IO.inspect(md)
      %{
        subject: subject,
        paras_total: total,
        paras_body: body,
        paras_schedule: schedule,
        paras_attachment: attachment,
        images: images,
        modified: modified
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
          subject: subject,
          paras_total: to_string(total) |> String.to_integer(),
          paras_body: to_string(body) |> String.to_integer(),
          paras_schedule: to_string(schedule) |> String.to_integer(),
          paras_attachment: to_string(attachment) |> String.to_integer(),
          images: to_string(images) |> String.to_integer(),
          modified: modified
        })
    |> IO.inspect()
    else
      {:error, code, error} -> {:error, "#{code}: #{error}"}
    end

  end

  def save_to_file(records) when is_list(records) do
    {:ok, file} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.open([:read, :utf8, :write])
    IO.puts(file, inspect(records, limit: :infinity))
    File.close(file)
    :ok
  end

  @doc """
    .csv has this structure
    "Name","Title_EN","SI Code"
  """
  def make_csv(records, filename) do
    csv_list =
      Enum.join(["Name,", "leg.gov.uk intro text"])
      |> (&[&1 | []]).()

      Enum.reduce(records, csv_list,
        fn
          %{"Name" => name, "leg.gov.uk intro text" => path}, acc ->
            [Enum.join([name, path], ",") | acc]
          %{"fields" => %{"Name" => name, "leg.gov.uk intro text" => path}}, acc ->
          [Enum.join([name, path], ",") | acc]
      end)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> save_to_csv("lib/#{filename}.csv")

  end

  def save_to_csv(binary, filename) do
    line_count = binary |> String.graphemes |> Enum.count(& &1 == "\n")
    filename
    |> Path.absname()
    |> File.write(binary)
    {:ok, line_count}
  end
end
