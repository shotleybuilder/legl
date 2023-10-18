defmodule Legl.Countries.Uk.UkHelpers do
  @moduledoc """
  Module to hold simple functions common across the UK parser
  """

  @doc """
  Function to split path "/type_code/year/number/..."
  """
  def split_path(path) do
    case Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d+)\//, path) do
      [_, type_code, year, number] ->
        {:ok, type_code, year, number}

      _ ->
        {:error, path}
    end
  end

  @doc """
  Function to split title in the legislation.gov.uk feed
  e.g.
  "SI 2023/1079 - The Forestry (Felling of Trees) (Amendment) (Wales) Regulations 2023"
  """
  def split_title(title) do
    case Regex.run(~r/[ ]-[ ](.*)$/, title) do
      [_, title] ->
        title

      _ ->
        # {:error, ~s[Could not parse this title: #{title}\n#{__MODULE__}.split_title/1]}
        title
    end
  end
end
