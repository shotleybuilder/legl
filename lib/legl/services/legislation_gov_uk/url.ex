defmodule Legl.Services.LegislationGovUk.Url do
  @moduledoc """
  Helper functions to generate urls for legislation.gov.uk
  """
  @doc """
  The introduction component of the laws on leg.gov.uk

  """
  alias Legl.Countries.Uk.LeglRegister.Amend.Options

  def introduction_url(record) do
    path = introduction_path(record)
    ~s(http://www.legislation.gov.uk#{path})
  end

  def introduction_path(%{type_code: type_code, Year: year, Number: number}) do
    introduction_path(type_code, year, number)
  end

  def introduction_path(type_code, year, number)
      when is_binary(type_code) and is_integer(year) and is_binary(number) do
    introduction_path(type_code, Integer.to_string(year), number)
  end

  def introduction_path(type_code, year, number)
      when is_binary(type_code) and is_binary(year) and is_binary(number) do
    cond do
      Regex.match?(~r/\//, number) ->
        ~s(/#{type_code}/#{number}/introduction/data.xml)

      true ->
        ~s(/#{type_code}/#{year}/#{number}/introduction/data.xml)
    end
  end

  @spec introduction_path_enact(map()) :: binary()
  def introduction_path_enact(%{type_code: type_code, Year: year, Number: number}) do
    introduction_path_enact(type_code, year, number)
  end

  @spec introduction_path_enact(binary(), integer(), binary()) :: binary()
  def introduction_path_enact(type_code, year, number)
      when is_binary(type_code) and is_integer(year) and is_binary(number) do
    introduction_path_enact(type_code, Integer.to_string(year), number)
  end

  @spec introduction_path_enact(binary(), binary(), binary()) :: binary()
  def introduction_path_enact(type_code, year, number)
      when is_binary(type_code) and is_binary(year) and is_binary(number) do
    cond do
      Regex.match?(~r/\//, number) ->
        ~s(/#{type_code}/#{number}/introduction/made/data.xml)

      true ->
        ~s(/#{type_code}/#{year}/#{number}/introduction/made/data.xml)
    end
  end

  def content_url(record) do
    path = content_path(record)
    ~s(http://www.legislation.gov.uk#{path})
  end

  def content_path(%{Number: number, type_code: type_code, Year: year}) do
    content_path(type_code, year, number)
  end

  def content_path(type_code, year, number)
      when is_binary(type_code) and is_integer(year) and is_binary(number) do
    content_path(type_code, Integer.to_string(year), number)
  end

  def content_path(type_code, year, number)
      when is_binary(type_code) and is_binary(year) and is_binary(number) do
    cond do
      Regex.match?(~r/\//, number) ->
        [_, number] = Regex.run(~r/\/(\d+$)/, number)

        ~s(/changes/affected/#{type_code}/#{year}/#{number}?results-count=1000&sort=affecting-year-number&order=descending)

      true ->
        ~s(/changes/affected/#{type_code}/#{year}/#{number}?results-count=1000&sort=affecting-year-number&order=descending)
    end
  end

  def contents_xml_url(record) do
    path = contents_xml_path(record)
    ~s(http://www.legislation.gov.uk#{path})
  end

  def contents_xml_path(%{Number: number, type_code: type_code, Year: year}) do
    contents_xml_path(type_code, year, number)
  end

  def contents_xml_path(type_code, year, number)
      when is_binary(type_code) and is_integer(year) and is_binary(number) do
    contents_xml_path(type_code, Integer.to_string(year), number)
  end

  def contents_xml_path(type_code, year, number)
      when is_binary(type_code) and is_binary(year) and is_binary(number) do
    cond do
      Regex.match?(~r/\//, number) ->
        ~s(/#{type_code}/#{number}/contents/data.xml)

      true ->
        ~s(/#{type_code}/#{year}/#{number}/contents/data.xml)
    end
  end

  @spec affecting_url(map()) :: binary()
  def affecting_url(record) do
    path = affecting_path(record)
    ~s(http://www.legislation.gov.uk#{path})
  end

  @spec affected_url(map()) :: binary()
  def affected_url(record) do
    path = affected_path(record)
    ~s(http://www.legislation.gov.uk#{path})
  end

  @doc """
  Receives map or tuple of :type_code, :Year, :Number
  Returns Amendments table for the Amending law (also called affecting)
  The laws that have been amended by this law
  X amending y and z
  """
  @spec affecting_path(map() | tuple()) :: binary()
  def affecting_path(param) do
    changes_path({"affecting", Options.results_count()}, param)
  end

  @doc """
  Receives map or tuple of :type_code, :Year, :Number
  Returns Amendments table for the Ammended by law (also called affected)
  The laws that have amended this law.
  X amended by y and z
  """
  @spec affected_path(map() | tuple()) :: binary()
  def affected_path(param) do
    changes_path({"affected", Options.results_count()}, param)
  end

  @spec changes_path(binary(), map()) :: binary()
  defp changes_path({affect, _results_count} = params, %{
         Number: number,
         type_code: type_code,
         Year: year
       })
       when affect in ["affected", "affecting"] do
    changes_path(params, {type_code, year, number})
  end

  @spec changes_path(binary(), tuple()) :: binary()
  defp changes_path(
         {affect, _results_count} = params,
         {type_code, year, number}
       )
       when affect in ["affected", "affecting"] and
              is_binary(type_code) and is_integer(year) and is_binary(number) do
    changes_path(params, {type_code, Integer.to_string(year), number})
  end

  @spec changes_path(binary(), tuple()) :: binary()
  defp changes_path({affect, results_count}, {type_code, year, number})
       when affect in ["affected", "affecting"] and
              is_binary(type_code) and is_binary(year) and is_binary(number) do
    cond do
      Regex.match?(~r/\//, number) ->
        ~s[/changes/#{affect}/#{type_code}/#{year}/#{number}/data.xml?results-count=#{results_count}&&sort=#{affect}-year-number]

      Regex.match?(~r/\/(\d+$)/, number) ->
        [_, n] = Regex.run(~r/\/(\d+$)/, number)

        ~s[/changes/#{affect}/#{type_code}/#{year}/#{n}/data.xml?results-count=#{results_count}&&sort=#{affect}-year-number]

      true ->
        ~s[/changes/#{affect}/#{type_code}/#{year}/#{number}/data.xml?results-count=#{results_count}&&sort=#{affect}-year-number]
    end
  end
end
