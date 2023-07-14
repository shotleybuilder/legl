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
end
