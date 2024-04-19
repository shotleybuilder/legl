defmodule Legl.Services.Supabase.UrlRest do
  @moduledoc """
  This module provides functions for generating Supabase URLs with various query parameters.

  ## Examples

      iex> Legl.Services.Supabase.UrlRest.url(%{table: "users", select: "id,name", limit: 10})
      "/users?select=id,name&limit=10"

  """
  def url(opts) do
    url =
      []
      |> name_url(opts)
      |> sql_url(opts)
      |> select_url(opts)
      |> limit_url(opts)
      |> offset_url(opts)
      |> order_url(opts)

    url =
      url
      |> Enum.reverse()
      |> Enum.join("&")

    case url do
      "" -> table_url("", opts)
      _ -> table_url("?" <> url, opts)
    end
  end

  defp table_url(url, %{supabase_table: table}) when is_binary(table) do
    "rest/v1/" <> table <> url
  end

  defp table_url(url, _), do: url

  defp name_url(url, %{name: name}) when is_list(name) do
    ["name=in.(#{Enum.join(name, ",")})" | url]
  end

  defp name_url(url, %{name: name}) do
    ["name=eq.#{name}" | url]
  end

  defp name_url(url, _), do: url

  defp sql_url(url, %{sql: sql}) do
    ["#{sql}" | url]
  end

  defp sql_url(url, _), do: url

  # VERTICAL (COLUMN) FILTERS

  defp select_url(url, %{select: select}) when is_list(select) do
    ["select=" <> Enum.join(select, ",") | url]
  end

  defp select_url(url, %{select: select}) do
    ["select=#{select}" | url]
  end

  defp select_url(url, _), do: url

  defp limit_url(url, %{limit: limit}) do
    ["limit=#{limit}" | url]
  end

  defp limit_url(url, _), do: url

  defp offset_url(url, %{offset: offset}) do
    ["offset=#{offset}" | url]
  end

  defp offset_url(url, _), do: url

  defp order_url(url, %{order: order}) do
    ["order=#{order}" | url]
  end

  defp order_url(url, _), do: url
end
