defmodule Legl.Countries.Uk.UkExtent do

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
        #IO.puts("#{k} #{v}")
        acc <> ~s/#{k}\n#{Enum.join(v, ", ")}\n/
      end)

    %{
      geo_extent: extents,
      geo_region: regions
    }
  end

  def uniq_extent(data) do
    Enum.map(data, fn {_, extent} -> extent end)
    |> Enum.uniq()
    |> Enum.sort_by(&byte_size/1, :desc)
  end

  def sorter(binary) do
    binary
    |> String.graphemes()
    |> Enum.count(& &1 == "+")
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
