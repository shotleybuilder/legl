defmodule Legl.Countries.Uk.UkExtent do

  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Countries.Uk.UkTypeCode
  alias Legl.Countries.Uk.UkAirtable, as: AT

  @at_type ["asc"]
  @at_csv "airtable_extents"
  @at_name "UK_uksi_2004_1959_ALNITCR"

  @fields ~w[
    Name
    Geo_Region
    Geo_Extent
  ] |> Enum.join(",")

  @default_opts %{
      base_name: "UK E",
      t: :uksi,
      view: "EXTENT",
      fields: ["Name", "Title_EN", "leg.gov.uk contents text"]
    }

  def open_file() do
    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write, :read])
    IO.puts(file, @fields)
    file
  end

  @doc """
    Legl.Countries.Uk.UkExtent.single_law
  """
  def single_law(opts \\ []) do

    file = open_file()

    opts = Enum.into(opts, @default_opts)
    opts = Map.merge(opts, %{formula: ~s/{Name}="#{@at_name}"/, file: file})

    with(
      {:ok, recordset} <- AT.get_records_from_at(opts),
      {:ok, msg} <- enumerate_at_records(recordset, opts)
    ) do
      IO.puts(msg)
    end

    File.close(file)

  end

  def run(opts \\ []) when is_list(opts) do

    file = open_file()

    opts = Enum.into(opts, @default_opts) |> Map.put(:file, file)

    case Map.get(%UkTypeCode{}, Map.get(opts, :t)) do

      nil ->
        IO.puts("ERROR with option")

      types when is_list(types) ->

        Enum.each(types, fn type ->
          IO.puts(">>>#{type}")
          opts = Map.put(opts, :type, type)
          full_workflow(opts)
        end)

      type when is_binary(type) ->
        opts = Map.put(opts, :type, type)
        full_workflow(opts)
    end

    File.close(file)

  end

  def full_workflow(opts) do

    opts = Map.put(opts, :formula, ~s/AND({type}="#{opts.type}",{Geo_Extent}=BLANK())/)

    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      IO.inspect(records),
      {:ok, msg} <- enumerate_at_records(records, opts)
    ) do
      IO.puts(msg)
    end
  end

  def enumerate_at_records(records, opts) do
    Enum.each(records, fn x ->
      fields = Map.get(x, "fields")
      name = Map.get(fields, "Name")
      path = Legl.Utility.resource_path(Map.get(fields, "leg.gov.uk contents text"))
      with(
        :ok <- make_csv_workflow(name, path, opts)
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

  def make_csv_workflow(name, url, opts) do
    with(
      {:ok, data} <- get_extent_leg_gov_uk(url),
      {:ok, %{
        geo_extent: extents,
        geo_region: regions
      }} <- extent_transformation(data)
    ) do
      ~s/#{name},#{regions},#{extents}/
      |> (&(IO.puts(opts.file, &1))).()
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
    #change this to String.split on '+' and Enum the list
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
