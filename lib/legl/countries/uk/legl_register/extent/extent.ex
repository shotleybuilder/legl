defmodule Legl.Countries.Uk.LeglRegister.Extent do
  @moduledoc """
  Functions to get region information from legislation.gov.uk and save to Airtable

  There is a accessor Function in uk.ex.  Call like this:

  UK.extent(base_name: "UK S", type_class: :regulation, type_code: :ssi)

  Single record ->

  UK.extent(base_name: "UK S", name: "UK_uksi_2014_1639_ASEWSR", new?: false, filesave?: true)
  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR
  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.LegislationGovUk.Url

  @at_csv ~s[lib/legl/countries/uk/legl_register/extent/extent.csv]
          |> Path.absname()

  @fields_update ~w[
    Name
    Geo_Region
    Geo_Extent
  ] |> Enum.join(",")

  # new? returns Airtable records with a blank 'Geo_Extent' field
  @default_opts %{
    name: "",
    new?: true,
    base_name: "UK EHS",
    type_code: [""],
    type_class: "",
    sClass: "",
    fields_update: @fields_update,
    view: "VS_CODE_EXTENT",
    fields: ["Name", "Title_EN", "leg.gov.uk contents text"]
  }

  @doc """
  Function to set the Extent fields: 'Geo_Pan_Region', 'Geo_Region' and 'Geo_Extent'
  in the Legal Register Table

  Contents xml path has this shape
    .../type_code/year/number/contents/data.xml

  Extent uses the RestrictExtent xml attribute
    e.g. RestrictExtent="E+W"

  """
  @spec set_extent(LR.legal_register()) :: {:ok, LR.legal_register()}
  def set_extent(%LR{Number: number, type_code: type_code, Year: year} = record, opts)
      when is_binary(number) and is_binary(type_code) and is_integer(year) do
    IO.write(" EXTENT")

    with(
      path = Url.contents_xml_path(record),
      {:ok, data} <- get_extent_leg_gov_uk(path),
      :ok = print_extent_get(record, data, opts),
      {:ok,
       %{
         geo_extent: geo_extent,
         geo_region: geo_region
       }} <- extent_transformation(data),
      geo_pan_region = geo_pan_region(geo_region)
    ) do
      {:ok,
       Kernel.struct(
         record,
         %{
           Geo_Parent: "United Kingdom",
           Geo_Pan_Region: geo_pan_region,
           Geo_Region: geo_region,
           Geo_Extent: geo_extent
         }
       )}

      # |> IO.inspect(label: "EXTENT: ")
    else
      {:no_data, _} ->
        IO.puts(
          "\nNO DATA: No Extent data returned from legislation.gov.uk\n #{__MODULE__}.set_extent/1"
        )

        {:ok, record}

      {:error, msg} ->
        IO.puts(
          "\nERROR: #{msg}\nProcessing Extents for:\n#{inspect(record."Title_EN")}\n #{__MODULE__}.set_extent/1"
        )

        {:ok, record}
    end
  end

  def print_extent_get(r, data, %{workflow: :Extent}) do
    data = data |> clean_data() |> uniq_extent()
    IO.puts(~s/\n#{r."Title_EN"} #{r."Year"} #{r."Number"} \n#{inspect(data)}/)
  end

  def print_extent_get(_, _, _), do: :ok

  def set_extent(%LR{Year: year} = record)
      when is_binary(year) do
    Map.put(record, :Year, String.to_integer(year))
    |> set_extent()
  end

  def set_extent(_), do: {:error, "ERROR: Number, type-code or Year is not set"}

  @doc """

  """
  def get_extent_leg_gov_uk(%LR{Number: _, type_code: _, Year: _} = record) do
    Url.contents_xml_path(record)
    |> get_extent_leg_gov_uk()
  end

  def get_extent_leg_gov_uk(url) when is_binary(url) do
    with({:ok, :xml, data} <- RecordGeneric.extent(url)) do
      {:ok, data}
    else
      {:no_data, []} ->
        {:no_data, []}

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

  def run(opts \\ []) when is_list(opts) do
    opts = Enum.into(opts, @default_opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)

    with {:ok, type_codes} <- Legl.Countries.Uk.LeglRegister.TypeCode.type_code(opts.type_code),
         {:ok, type_class} <-
           Legl.Countries.Uk.LeglRegister.TypeClass.type_class(opts.type_class),
         {:ok, sClass} <- Legl.Countries.Uk.LeglRegister.SClass.sClass(opts.sClass),
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

  @spec extent_transformation(list()) :: :ok | {:ok, map()}
  def extent_transformation([{}]), do: :ok

  def extent_transformation(data) do
    clean_data = clean_data(data)
    uniq_extent = uniq_extent(clean_data)

    {:ok,
     %{
       # geo_extent is a string of legal clauses sorted by extent
       geo_extent: geo_extent(clean_data, uniq_extent),
       # geo_region is one of more of the nations of the UK
       geo_region: uniq_extent |> geo_region() |> ordered_regions()
     }}
  end

  def clean_data(data) do
    Enum.reduce(data, [], fn
      {}, acc -> acc
      {_extents}, acc -> acc
      {provisions, "(E+W)"}, acc -> [{provisions, "E+W"} | acc]
      {provisions, "EW"}, acc -> [{provisions, "E+W"} | acc]
      {provisions, "EWS"}, acc -> [{provisions, "E+W+S"} | acc]
      {provisions, extent}, acc -> [{provisions, extent} | acc]
    end)
  end

  @doc """
  Function to return all the unique extent codes

  Examples,
    "E+W+S+NI"
  """
  @spec uniq_extent(list()) :: list(binary())
  def uniq_extent(data) do
    Enum.reduce(data, [], fn
      {_, extent}, acc -> [extent | acc]
      {}, acc -> acc
      {_extent}, acc -> acc
    end)
    |> Enum.uniq()
    |> Enum.sort_by(&byte_size/1, :desc)
  end

  def geo_extent(_data, [uniq_extent]) do
    uniq_extent = emoji_flags(uniq_extent)
    ~s/#{uniq_extent}💚️All provisions/
  end

  def geo_extent(data, uniq_extent) do
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
    # Enum.map(extents, fn {k, v} -> {k, Enum.reverse(v)} end)
    extents =
      Enum.map(extents, fn {k, v} -> {k, v} end)
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
        _ -> acc
      end
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
    |> (&(&1 <> " " <> k)).()
  end

  def create_map(uniq_extent) do
    Enum.reduce(uniq_extent, %{}, fn x, acc ->
      Map.put(acc, x, [])
    end)
  end

  def geo_region(extents) do
    # change this to String.split on '+' and Enum the list

    Enum.reduce(extents, [], fn x, acc ->
      case x do
        "E+W+S+NI" -> ["England", "Wales", "Scotland", "Northern Ireland" | acc]
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
        _ -> acc
      end
    end)
    |> Enum.uniq()
  end

  def ordered_regions(["England", "Wales", "Scotland", "Northern Ireland"] = regions), do: regions
  def ordered_regions(["England", "Wales"] = regions), do: regions
  def ordered_regions(["England"] = regions), do: regions
  def ordered_regions(["Wales"] = regions), do: regions
  def ordered_regions(["Scotland"] = regions), do: regions
  def ordered_regions(["Northern Ireland"] = regions), do: regions

  def ordered_regions(regions) do
    Enum.reduce(regions, [], fn
      "England", acc ->
        [{:a, "England"} | acc]

      "Wales", acc ->
        [{:c, "Wales"} | acc]

      "Scotland", acc ->
        [{:c, "Scotland"} | acc]

      "Northern Ireland", acc ->
        [{:d, "Northern Ireland"} | acc]
    end)
    |> List.keysort(0)
    |> Enum.reduce([], fn {_k, v}, acc ->
      case v do
        "" -> acc
        _ -> [v | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp geo_pan_region(""), do: ""

  defp geo_pan_region(geo_region) do
    regions_list =
      geo_region
      # String.split(geo_region, ",")
      |> Enum.map(&String.trim(&1))
      |> Enum.sort()

    cond do
      ["England", "Northern Ireland", "Scotland", "Wales"] == regions_list -> "UK"
      ["England", "Scotland", "Wales"] == regions_list -> "GB"
      ["England", "Wales"] == regions_list -> "E+W"
      ["England", "Scotland"] == regions_list -> "E+S"
      ["England"] == regions_list -> "E"
      ["Wales"] == regions_list -> "W"
      ["Scotland"] == regions_list -> "S"
      ["Northern Ireland"] == regions_list -> "NI"
      true -> ""
    end
  end
end
