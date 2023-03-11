defmodule Legl.Countries.Uk.UkExtent do

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.RecordGeneric

  @at_type ["asc"]
  @at_csv "airtable_extents"
  @at_name "UK_uksi_2004_1959_ALNITCR"
  @doc """
    Legl.Countries.Uk.UkExtent.full_workflow
  """
  def full_workflow() do
    csv_header_row()
    Enum.each(@at_type, fn x -> full_workflow(x) end)
  end
  @doc """
    Legl.Countries.Uk.UkExtent.single_law
  """
  def single_law() do
    csv_header_row()
    formula = ~s/{Name}="#{@at_name}"/
    with(
      {:ok, recordset} <- get_records_from_at("UK E", false, formula),
      {:ok, msg} <- enumerate_at_records(recordset)
    ) do
      IO.puts(msg)
    end
  end

  def full_workflow(type) do
    formula = ~s/AND({type}="#{type}",{Geo_Extent}=BLANK())/
    with(
      {:ok, recordset} <- get_records_from_at("UK E", false, formula),
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
  def get_records_from_at(base_name, filesave?, formula) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
            view: "EXTENT",
            fields: ["Name", "Title_EN", "leg.gov.uk contents text"],
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
    |> Legl.Utility.write_to_csv(@at_csv)
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
      :ok -> :ok
      {:error, error} -> {:error, error}
    end
  end

  def get_extent_leg_gov_uk(url) do
    with(
      {:ok, :xml, %{extents: data}} <- RecordGeneric.extent(url)
    ) do
      {:ok, data}
    else
      {:error, 307, _error} ->
        adjust_url(url)
      {:error, code, error} -> {:error, "#{code}: #{error}"}
      {:ok, :html} ->
        IO.puts("#{url}")
        {:error, :html}
    end
  end

  def adjust_url(url) do
    url =
      case Regex.match?(~r/made/, url) do
        true ->
          Regex.replace(~r/made/, url, "enacted")
        _ ->
          Regex.replace(~r/contents/, url, "contents/made")
      end
    get_extent_leg_gov_uk(url)
  end

  def extent_transformation([{}]), do: :ok
  def extent_transformation(data) do
    #IO.inspect(data, limit: :infinity)
    #get the unique extent
    data = clean_data(data)
    IO.inspect(data, limit: :infinity)

    uniq_extent = uniq_extent(data)

    regions = regions(uniq_extent)

    extents = extents(data, uniq_extent)

    {:ok,
      %{
        geo_extent: ~s/\"#{extents}\"/,
        geo_region: regions
      }
    }
  end

  def clean_data(data) do
    Enum.reduce(data, [],
      fn
        {}, acc -> acc
        {_extents}, acc -> acc
        {provisions, "(E+W)"}, acc -> [{provisions, "E+W"} | acc]
        {provisions, "EW"}, acc -> [{provisions, "E+W"} | acc]
        {provisions, extent}, acc ->  [{provisions, extent} | acc]
    end)
  end

  def extents(_data, [uniq_extent]) do
    uniq_extent = emoji_flags(uniq_extent)
    ~s/#{uniq_extent}💚️All provisions/
  end

  def extents(data, uniq_extent) do
    #use extent as the keys to a map where each section amends
    extents = create_map(uniq_extent) #|> IO.inspect
    #IO.inspect(data, limit: :infinity)
    extents =
      Enum.reduce(data, extents,
        fn
          {content, extent}, acc ->
            #IO.inspect(acc)
            [content | acc["#{extent}"]]
            |> (&(%{acc | "#{extent}" => &1})).()
          {}, acc -> acc
          {_extents}, acc -> acc
      end)

    #sort the map
    extents =
      Enum.map(extents, fn {k, v} -> {k, Enum.reverse(v)} end) #|> IO.inspect
      |> Enum.sort_by(&(elem(&1, 0)) |> byte_size(), :desc)
      #|> IO.inspect

    #make the string
    Enum.reduce(extents, "", fn {k, v}, acc ->
      #IO.inspect(k)
      k = emoji_flags(k)
      acc <> ~s/#{k}💚️#{Enum.join(v, ", ")}💚️/
    end)
    #remove the trailing heart
    |> (&(Regex.replace(~r/💚️$/, &1, ""))).()
  end

  def emoji_flags("E+W+S+NI" = k), do: Legl.uk_flag_emoji()<>" "<>k
  def emoji_flags(k) do
    enacts = String.split(k, "+")
    Enum.reduce(enacts, [], fn x, acc ->
      case x do
        "E" -> [Legl.england_flag_emoji() | acc]
        "W" -> [Legl.wales_flag_emoji() | acc]
        "S" -> [Legl.scotland_flag_emoji() | acc]
        "NI" -> [Legl.northern_ireland_flag_emoji() | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
    |> (&(&1<>" "<>k)).()
  end

  def uniq_extent(data) do
    Enum.reduce(data, [],
      fn
        {_, extent}, acc -> [extent | acc]
        {}, acc -> acc
        {_extent}, acc -> acc
    end)
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

    ordered_regions = ordered_regions(regions)

    ~s/\"#{Enum.join(ordered_regions, ",")}\"/
  end

  def ordered_regions(regions) do
    Enum.reduce(regions, {"", "", "", ""}, fn x, acc ->
      case x do
        "England" -> Tuple.insert_at(acc, 0, x)
        "Wales" -> Tuple.insert_at(acc, 1, x)
        "Scotland" -> Tuple.insert_at(acc, 2, x)
        "Northern Ireland" -> Tuple.insert_at(acc, 3, x)
      end
    end)
    |> Tuple.to_list()
    |> Enum.reduce([], fn x, acc ->
      case x do
        "" -> acc
        _ -> [x | acc]
      end
    end)
    |> Enum.reverse()
  end

end
