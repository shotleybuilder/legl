defmodule Legl.Countries.Uk.UkRevoke do
  @moduledoc """
    This module checks the repealed or revoked status of a
    piece of legislaton by testing for the appending words
    'repealed' or 'revoked' at the end of the title element in
    the .xml
  """
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.RecordGeneric

  @at_type ["uksi"]
  @at_csv "airtable_revocations"
  @at_name "UK_ukpga_1964_40_HA"

  def single_law() do
    csv_header_row()
    formula = ~s/{Name}="#{@at_name}"/
    with(
      {:ok, recordset} <- get_records_from_at("UK E", false, formula),
      IO.inspect(recordset),
      {:ok, msg} <- enumerate_at_records(recordset)
    ) do
      IO.puts(msg)
    else
      {:error, error} ->
        IO.puts("#{error}")
    end
  end

  def full_workflow() do
    csv_header_row()
    Enum.each(@at_type, fn x -> full_workflow(x) end)
  end

  def full_workflow(type) do
    #formula = ~s/AND({type}="#{type}",{Live?}=BLANK())/
    formula = ~s/{type}="#{type}"/
    with(
      {:ok, recordset} <- get_records_from_at("UK E", false, formula),
      {:ok, msg} <- enumerate_at_records(recordset)
    ) do
      IO.puts(msg)
    end
  end

  def get_records_from_at() do
    get_records_from_at("UK E", @at_type, true)
  end
  @doc """
    Legl.Countries.Uk.UkExtent.get_records_from_at("UK E", true)
  """
  def get_records_from_at(base_name, filesave?, formula) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
            view: "REPEALED_REVOKED",
            fields: ["Name", "Title_EN", "leg.gov.uk resources xml"],
            formula: formula
          }
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      IO.puts("Records returned from Airtable")
      if filesave? == true do Legl.Utility.save_at_records_to_file(recordset) end
      if filesave? == false do {:ok, recordset} end
    else
      {:error, error} -> {:error, error}
    end
  end

  def enumerate_at_records(records) do
    Enum.each(records, fn x ->
      fields = Map.get(x, "fields")
      name = Map.get(fields, "Name")
      path = Legl.Utility.resource_path(Map.get(fields, "leg.gov.uk resources xml"))
      with(
        :ok <- make_csv_workflow(name, path)
      ) do
        IO.puts("#{fields["Title_EN"]}")
      else
        {:error, error} ->
          IO.puts("ERROR #{error} with #{fields["Title_EN"]}")
        {:error, :html} ->
          IO.puts(".html from #{fields["Title_EN"]}")
      end
    end)
    {:ok, "metadata properties saved to csv"}
  end

  @fields ~w[
    Name
    Live?
    md_restrict_start_date
    md_dct_valid_date
    Geo_region_check
  ]

  def csv_header_row() do
    Enum.join(@fields, ",")
    |> Legl.Utility.write_to_csv(@at_csv)
  end

  def make_csv_workflow(name, url) do
    with(
     %{
        dct_valid: valid,
        restrict_extent: extent,
        restrict_start_date: date,
        revoked: revoked?,
        title: _title
      } <- get_revocation_leg_gov_uk(url)
    ) do
      ~s/#{name},#{revocation_type(revoked?)},#{date},#{valid},"#{make_geo_region_list(extent)}"/
      |> Legl.Utility.append_to_csv(@at_csv)
      #if valid != date do IO.puts("Dates are different") end
      :ok
    else
      :ok -> :ok
      {:error, error} -> {:error, error}
    end
  end

  def revocation_type(true), do: "❌ Revoked / Repealed / Abolished"
  def revocation_type(false), do: "✔ In force"

  @doc """
    Legl.Countries.Uk.UkRevoke.get_revocation_leg_gov_uk("/ukpga/1964/40/resources/data.xml")
  """
  def get_revocation_leg_gov_uk(url) do
    with(
      {:ok, :xml, data} <- RecordGeneric.revoke(url)
    ) do
      data
    else
      #{:error, 307, _error} ->
      #  adjust_url(url)
      {:error, code, error} -> {:error, "#{code}: #{error}"}
      {:ok, :html} ->
        IO.puts("#{url}")
        {:error, :html}
    end
  end

  def make_geo_region_list(nil), do: ""
  def make_geo_region_list(""), do: ""
  def make_geo_region_list(code) do
    String.split(code, "+")
    |> Enum.reduce([], fn x, acc ->
      case x do
        "E" -> ["England" | acc]
        "W" -> ["Wales" | acc]
        "S" -> ["Scotland" | acc]
        "NI" -> ["Northern Ireland" | acc]
      end
    end)
    |> Legl.Countries.Uk.UkExtent.ordered_regions()
    |> Enum.join(",")
  end

end
