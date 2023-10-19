defmodule Legl.Services.LegislationGovUk.Url do
  @moduledoc """
  Helper functions to generate urls for legislation.gov.uk
  """
  @doc """
  The introduction component of the laws on leg.gov.uk
  """
  def introduction_path(type, year, number) do
    "/#{type}/#{year}/#{number}/introduction/made/data.xml"
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

        ~s(https://www.legislation.gov.uk/changes/affected/#{type_code}/#{year}/#{number}?results-count=1000&sort=affecting-year-number&order=descending)

      true ->
        ~s(https://www.legislation.gov.uk/changes/affected/#{type_code}/#{year}/#{number}?results-count=1000&sort=affecting-year-number&order=descending)
    end
  end
end
