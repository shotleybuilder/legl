defmodule Legl.Countries.Uk.AtArticle.Original.Original do
  @moduledoc """
  Functions to return the text of legislation from leg.gov.uk to the
  original.txt file and make it available for further processing
  """

  alias Legl.Countries.Uk.AtArticle.Original.AsMade
  alias Legl.Countries.Uk.AtArticle.Original.Latest

  def run(url) do
    with %HTTPoison.Response{
           status_code: 200,
           body: body,
           headers: headers
         } <- HTTPoison.get!(url, [], follow_redirect: true),
         {:ok, status} <- latest?(headers),
         {:ok, document} <-
           Floki.parse_document(body) do
      #
      case status do
        :as_made -> AsMade.process(document)
        :latest -> Latest.process(document)
      end
    else
      %HTTPoison.Error{reason: error} ->
        IO.puts("#{error}")
    end
  end

  def latest?(headers) do
    {_, content_location} = Enum.find(headers, fn x -> elem(x, 0) == "Content-Location" end)

    case String.contains?(content_location, "made") do
      true ->
        IO.puts("Redirected")
        {:ok, :as_made}

      _ ->
        IO.puts("Latest")
        {:ok, :latest}
    end
  end
end
