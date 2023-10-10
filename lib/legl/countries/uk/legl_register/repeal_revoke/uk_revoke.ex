defmodule Legl.Countries.Uk.UkRevoke do
  @moduledoc """
    This module checks the repealed or revoked status of a
    piece of legislaton by testing for the appending words
    'repealed' or 'revoked' at the end of the title element in
    the .xml
  """

  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Services.LegislationGovUk.RecordGeneric

  @at_type %{
    ukpga: ["ukpga"],
    uksi: ["uksi"],
    ni: ["nia", "apni", "nisi", "nisr", "nisro"],
    s: ["asp", "ssi"],
    uk: ["ukpga", "uksi"],
    w: ["anaw", "mwa", "wsi"],
    o: ["ukcm", "ukla", "asc", "ukmo", "apgb", "aep"]
  }
  @at_csv "airtable_revocations"
  @code_full "❌ Revoked / Repealed / Abolished"
  @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"
  @at_name "UK_ukpga_1964_40_HA"
  @at_url_field "leg.gov.uk resources xml"

  @fields ~w[
    Name
    Live?
    md_restrict_start_date
    md_dct_valid_date
    Geo_region_check
  ] |> Enum.join(",")

  def open_file() do
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, @fields)
    file
  end

  def single_law() do
    file = open_file()

    opts = [formula: ~s/{Name}="#{@at_name}"/]
    full_workflow(file, opts)

    File.close(file)
  end

  @doc """
    Legl.Countries.Uk.UkRevoke.run(opt)
    where opt is an atom :ukpga, :uksi, :ni, :s, :uk, :w, :o
  """
  def run(t) when is_atom(t) do
    case Map.get(@at_type, t) do
      nil -> IO.puts("ERROR with option")
      types -> run(types)
    end
  end

  def run(types) when is_list(types) do
    file = open_file()

    Enum.each(types, fn type ->
      IO.puts(">>>#{type}")
      opts = [formula: ~s/AND({type_code}="#{type}",{Live?}="#{@code_live}")/]
      full_workflow(file, opts)
    end)

    File.close(file)
  end

  @default_opts %{
    base_name: "UK S",
    fields: ["Name", "Title_EN", "leg.gov.uk resources xml"],
    view: "VS_CODE_REPEALED_REVOKED"
  }

  def full_workflow(file, opts \\ []) do
    # formula = ~s/AND({type_code}="#{type}",{Live?}=BLANK())/
    # formula = ~s/{type_code}="#{type}"/

    opts = Enum.into(opts, @default_opts)

    func = &__MODULE__.make_csv_workflow/3

    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      # IO.inspect(records),
      {:ok, msg} <- AT.enumerate_at_records({file, records}, @at_url_field, func)
    ) do
      IO.puts(msg)
    end
  end

  def create_path(name) do
    case Legl.Utility.split_name(name) do
      {type, year, number} ->
        ~s[/#{type}/#{year}/#{number}/resources/data.xml]

      {type, number} ->
        ~s[/#{type}/#{number}/resources/data.xml]
    end
  end

  def make_csv_workflow(file, name, url) do
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
      |> (&IO.puts(file, &1)).()
    else
      :ok -> :ok
      {:error, error} -> {:error, error}
    end
  end

  def revocation_type(true), do: @code_full
  def revocation_type(false), do: @code_live

  @doc """
    Legl.Countries.Uk.UkRevoke.get_revocation_leg_gov_uk("/ukpga/1964/40/resources/data.xml")
  """
  def get_revocation_leg_gov_uk(url) do
    with({:ok, :xml, data} <- RecordGeneric.revoke(url)) do
      data
    else
      # {:error, 307, _error} ->
      #  adjust_url(url)
      {:error, code, error} ->
        {:error, "#{code}: #{error}"}

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
