defmodule Legl.Countries.Uk.AtArticle.Original.Original do
  @moduledoc """
  Functions to return the text of legislation from leg.gov.uk to the
  original.txt file and make it available for further processing
  """

  alias Legl.Countries.Uk.AtArticle.Original.AsMade
  alias Legl.Countries.Uk.AtArticle.Original.Latest
  # The original downloaded from leg.gov.uk
  @original ~s[lib/legl/data_files/html/original.html] |> Path.absname()
  @ex ~s[lib/legl/data_files/ex/original.ex] |> Path.absname()

  @default_opts %{
    saveBody?: false
  }

  def run(url, opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    with %HTTPoison.Response{
           status_code: 200,
           body: body,
           headers: headers
         } <- HTTPoison.get!(url, [], follow_redirect: true),
         {:ok, status} <- latest?(headers),
         {:ok, document} <-
           Floki.parse_document(body) do
      # Write body to file
      if opts.saveBody? do
        File.write(@original, body)
        IO.puts("Original .html saved to file")
      end

      # Write the parsed html to file
      case File.write(@ex, inspect(document, limit: :infinity)) do
        :ok -> IO.puts("Parsed html saved to file")
        _ -> IO.puts("Error saving parsed html")
      end

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
        IO.puts("As Made")
        {:ok, :as_made}

      _ ->
        IO.puts("Latest")
        {:ok, :latest}
    end
  end
end
