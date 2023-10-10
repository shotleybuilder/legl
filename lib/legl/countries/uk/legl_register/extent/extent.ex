defmodule Legl.Countries.Uk.LeglRegister.Extent do
  @moduledoc """
  Functions to get region information from legislation.gov.uk and save to Airtable

  There is a accessor Function in uk.ex.  Call like this:

  UK.extent(base_name: "UK S", type_class: :regulation, type_code: :ssi)

  Single record ->

  UK.extent(base_name: "UK S", name: "UK_uksi_2014_1639_ASEWSR", new?: false, filesave?: true)
  """
  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Services.Airtable.AtBasesTables

  @at_type ["asc"]
  @at_csv ~s[lib/legl/countries/uk/legl_register/extent/extent.csv]
          |> Path.absname()
  @at_name "UK_uksi_2004_1959_ALNITCR"

  @fields_update ~w[
    Name
    Geo_Region
    Geo_Extent
  ] |> Enum.join(",")

  # new? returns Airtable records with a blank 'Geo_Extent' field
  @default_opts %{
    name: "",
    new?: true,
    base_name: "UK E",
    type_code: [""],
    type_class: "",
    sClass: "",
    fields_update: @fields_update,
    view: "VS_CODE_EXTENT",
    fields: ["Name", "Title_EN", "leg.gov.uk contents text"]
  }

  def run(opts \\ []) when is_list(opts) do
    opts = Enum.into(opts, @default_opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)

    with {:ok, type_codes} <- Legl.Countries.Uk.UkTypeCode.type_code(opts.type_code),
         {:ok, type_class} <- Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class),
         {:ok, sClass} <- Legl.Countries.Uk.SClass.sClass(opts.sClass),
         {:ok, file} <- @at_csv |> File.open([:utf8, :write]) do
      #
      IO.puts(file, opts.fields_update)

      Enum.each(type_codes, fn type ->
        IO.puts(">>>#{type}")

        opts =
          Map.merge(
            opts,
            %{
              base_id: base_id,
              table_id: table_id,
              file: file,
              type_code: type_codes,
              type_class: type_class,
              sClass: sClass
            }
          )

        opts = Map.put(opts, :formula, formula(type, opts))

        IO.puts("OPTIONS: #{inspect(opts)}")

        workflow(opts)
      end)

      File.close(file)
    else
      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  defp formula(type, %{name: ""} = opts) do
    f = if opts.new?, do: [~s/{Geo_Extent}=BLANK()/], else: []
    f = if opts.type_code != [""], do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f
    f = if opts.sClass != "", do: [~s/{sClass}="#{opts.sClass}"/ | f], else: f
    ~s/AND(#{Enum.join(f, ",")})/
  end

  defp formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end

  def workflow(opts) do
    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      IO.puts("#{Enum.count(records)} returned from Airtable"),
      {:ok, msg} <- enumerate_at_records(records, opts)
    ) do
      IO.puts(msg)
    end
  end

  def enumerate_at_records(records, opts) do
    Enum.each(records, fn x ->
      fields = Map.get(x, "fields")
      name = Map.get(fields, "Name")
      {:ok, path} = Legl.Utility.resource_path(Map.get(fields, "leg.gov.uk contents text"))

      with(:ok <- make_csv_workflow(name, path, opts)) do
        IO.puts("#{fields["Title_EN"]}")
      else
        {:error, error} ->
          IO.puts("ERROR #{error} with #{fields["Title_EN"]}")

        {:error, :html} ->
          IO.puts(".html from #{fields["Title_EN"]}")
      end
    end)

    {:ok, "metadata properties saved to csv"}
    # |> (&{:ok, &1}).()
  end

  # @fields_update ~w[
  #  Name
  #  Geo_Region
  #  Geo_Extent
  # ]

  def make_csv_workflow(name, url, opts) do
    with(
      {:ok, data} <- get_extent_leg_gov_uk(url),
      {:ok,
       %{
         geo_extent: extents,
         geo_region: regions
       }} <- extent_transformation(data)
    ) do
      ~s/#{name},#{regions},#{extents}/
      |> (&IO.puts(opts.file, &1)).()

      :ok
    else
      :ok -> :ok
      {:error, error} -> {:error, error}
    end
  end

  def get_extent_leg_gov_uk(url) do
    with({:ok, :xml, %{extents: data}} <- RecordGeneric.extent(url)) do
      {:ok, data}
    else
      {:error, 307, _error} ->
        adjust_url(url)

      {:error, code, error} ->
        {:error, "#{code}: #{error}"}

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
    # IO.inspect(data, limit: :infinity)
    # get the unique extent
    data = clean_data(data)
    # IO.inspect(data, limit: :infinity)

    uniq_extent = uniq_extent(data)

    regions = regions(uniq_extent)

    extents = extents(data, uniq_extent)

    {:ok,
     %{
       geo_extent: ~s/\"#{extents}\"/,
       geo_region: regions
     }}
  end

  def clean_data(data) do
    Enum.reduce(data, [], fn
      {}, acc -> acc
      {_extents}, acc -> acc
      {provisions, "(E+W)"}, acc -> [{provisions, "E+W"} | acc]
      {provisions, "EW"}, acc -> [{provisions, "E+W"} | acc]
      {provisions, extent}, acc -> [{provisions, extent} | acc]
    end)
  end

  def extents(_data, [uniq_extent]) do
    uniq_extent = emoji_flags(uniq_extent)
    ~s/#{uniq_extent}💚️All provisions/
  end

  def extents(data, uniq_extent) do
    # use extent as the keys to a map where each section amends
    # |> IO.inspect
    extents = create_map(uniq_extent)
    # IO.inspect(data, limit: :infinity)
    extents =
      Enum.reduce(data, extents, fn
        {content, extent}, acc ->
          # IO.inspect(acc)
          [content | acc["#{extent}"]]
          |> (&%{acc | "#{extent}" => &1}).()

        {}, acc ->
          acc

        {_extents}, acc ->
          acc
      end)

    # sort the map
    # |> IO.inspect
    extents =
      Enum.map(extents, fn {k, v} -> {k, Enum.reverse(v)} end)
      |> Enum.sort_by(&(elem(&1, 0) |> byte_size()), :desc)

    # |> IO.inspect

    # make the string
    Enum.reduce(extents, "", fn {k, v}, acc ->
      # IO.inspect(k)
      k = emoji_flags(k)
      acc <> ~s/#{k}💚️#{Enum.join(v, ", ")}💚️/
    end)
    # remove the trailing heart
    |> (&Regex.replace(~r/💚️$/, &1, "")).()
  end

  def emoji_flags("E+W+S+NI" = k), do: Legl.uk_flag_emoji() <> " " <> k

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
    |> (&(&1 <> " " <> k)).()
  end

  def uniq_extent(data) do
    Enum.reduce(data, [], fn
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
    # change this to String.split on '+' and Enum the list
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
