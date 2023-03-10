defmodule Legl.Countries.Uk.UkExtent do

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.RecordGeneric

  @at_type ["mwa"]
  @at_csv "airtable_extents"
  @doc """
    Legl.Countries.Uk.UkExtent.full_workflow
  """
  def full_workflow() do
    csv_header_row()
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
    Legl.Countries.Uk.UkExtent.get_records_from_at("UK E", "ukpga", true)
  """
  def get_records_from_at(base_name, type, filesave?) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
            view: "EXTENT",
            fields: ["Name", "Title_EN", "leg.gov.uk contents text"],
            formula: ~s/{type}="#{type}"/
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
      path = Legl.Utility.resource_path(Map.get(fields, "leg.gov.uk contents text"))
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
    #|> (&{:ok, &1}).()
  end

  @fields ~w[
    Name
    Geo_Region
    Geo_Extent
  ]

  def csv_header_row() do
    Enum.join(@fields, ",")
    |> Legl.Utility.append_to_csv(@at_csv)
  end

  def make_csv_workflow(name, url) do
    with(
      {:ok, data} <- get_extent_leg_gov_uk(url),
      {:ok, %{
        geo_extent: extents,
        geo_region: regions
      }} <- extent_transformation(data)
    ) do
      ~s/#{name},#{regions},#{extents}/
      |> Legl.Utility.append_to_csv(@at_csv)
      :ok
    else
      {:error, error} -> {:error, error}
    end
  end

  def get_extent_leg_gov_uk(url) do
    with(
      {:ok, :xml, %{extents: data}} <- RecordGeneric.extent(url),
      #
      IO.inspect(data)
    ) do
      {:ok, data}
    else
      {:error, code, error} -> {:error, "#{code}: #{error}"}
      {:ok, :html} -> {:error, :html}
    end
  end

  def extent_transformation(data) do

    #get the unique extent
    uniq_extent = uniq_extent(data)

    #use extent as the keys to a map where each section amends
    extents = create_map(uniq_extent) #|> IO.inspect

    regions = regions(uniq_extent)

    extents =
    Enum.reduce(data, extents,
      fn {content, extent}, acc ->
        #IO.inspect(acc)
        [content | acc["#{extent}"]]
        |> (&(%{acc | "#{extent}" => &1})).()
    end)
    #sort the map
    extents =
      Enum.map(extents, fn {k, v} -> {k, Enum.reverse(v)} end) #|> IO.inspect
      |> Enum.sort_by(&(elem(&1, 0)) |> byte_size(), :desc)
      #|> IO.inspect

    #make the string
    extents =
      Enum.reduce(extents, "", fn {k, v}, acc ->
        acc <> ~s/#{k}💚️#{Enum.join(v, ", ")}💚️/
      end)
      #remove the trailing heart
      |> (&(Regex.replace(~r/💚️$/, &1, ""))).()
    {:ok,
      %{
        geo_extent: ~s/\"#{extents}\"/,
        geo_region: regions
      }
    }
  end

  def uniq_extent(data) do
    Enum.map(data, fn {_, extent} -> extent end)
    |> Enum.uniq()
    |> Enum.sort_by(&byte_size/1, :desc)
  end

  def create_map(uniq_extent) do
    Enum.reduce(uniq_extent, %{}, fn x, acc ->
      Map.put(acc, x, [])
    end)

  end

  def regions(extents) do
    regions =
      Enum.reduce(extents, [], fn x, acc ->
        case x do
          "E+W+S+NI" -> ["England", "Scotland", "Wales", "Northern Ireland" | acc]
          "E+W+S" -> ["England", "Wales", "Scotland" | acc]
          "E+W+NI" -> ["England", "Wales", "Northern Ireland" | acc]
          "E+S+NI" -> ["England", "Scotland", "Northern Ireland" | acc]
          "W+S+NI" -> ["Wales", "Scotland", "Northern Ireland" | acc]
          "E+W" -> ["England", "Wales" | acc]
          "E+S" -> ["England", "Scotland" | acc]
          "E+NI" -> ["England", "Northern Ireland" | acc]
          "W+S" -> ["Wales", "Scotland" | acc]
          "W+NI" -> ["Wales", "Northern Ireland" | acc]
          "S+NI" -> ["Scotland", "Northern Ireland" | acc]
          "E" -> ["England" | acc]
          "W" -> ["Wales" | acc]
          "S" -> ["Scotland" | acc]
          "NI" -> ["Northern Ireland" | acc]
        end
      end)
      |> Enum.uniq()

    ordered_regions = []
    ordered_regions =
      if "Northern Ireland" in regions do ["Northern Ireland" | ordered_regions] end
    ordered_regions =
      if "Scotland" in regions do ["Scotland" | ordered_regions] end
    ordered_regions =
      if "Wales" in regions do ["Wales" | ordered_regions] end
    ordered_regions =
      if "England" in regions do ["England" | ordered_regions] end

    ~s/\"#{Enum.join(ordered_regions, ",")}\"/
  end

end
