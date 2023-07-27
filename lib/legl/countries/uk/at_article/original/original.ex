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
  @txt ~s[lib/legl/data_files/txt/original.txt] |> Path.absname()

  @default_opts %{
    saveBody?: true
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
        File.write(@original, Floki.raw_html(document, pretty: true))
        IO.puts("Original .html saved to file")
      end

      # Write the parsed html to file
      case File.write(@ex, inspect(document, limit: :infinity)) do
        :ok -> IO.puts("Parsed html saved to file")
        _ -> IO.puts("Error saving parsed html")
      end

      text =
        case status do
          :as_made -> AsMade.process(document)
          :latest -> Latest.process(document)
        end

      # post-process and save text
      text = post_process(text)
      File.write(@txt, text)
    else
      %HTTPoison.Error{reason: error} ->
        IO.puts("#{error}")
    end
  end

  defp latest?(headers) do
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

  defp post_process(text) do
    IO.write("post_process/1")

    text =
      text
      # rm <<194, 160>> and replace with space
      |> (&Regex.replace(~r/[ ]+/m, &1, " ")).()
      # rm space before period and other punc marks at end of line
      |> (&Regex.replace(~r/[ ]+([\.\];])$/m, &1, "\\g{1}")).()
      # replace carriage returns
      |> (&Regex.replace(~r/\r/m, &1, "\n")).()
      |> (&Regex.replace(~r/\n{2,}/m, &1, "\n")).()
      # rm spaces new lines around parenthatised numbers
      # |> (&Regex.replace(~r/\(\n\d+\n\)(.*)/m, &1, "\\g{1}")).()
      # |> (&Regex.replace(~r/\([ ]\d+[ ]\)/m, &1, "")).()
      # join sub with empty line
      |> (&Regex.replace(~r/^(\([a-z]+\))\n/m, &1, "\\g{1} ")).()
      # rm space after [::region::]
      |> (&Regex.replace(~r/\[::region::\][ ]/m, &1, "[::region::]")).()
      # rm space after ef bracket
      |> (&Regex.replace(~r/\[[ ]F/m, &1, "[F")).()
      # rm spaces before and after quotes
      |> (&Regex.replace(~r/“[ ]/m, &1, "“")).()
      |> (&Regex.replace(~r/[ ]”/m, &1, "”")).()
      # put in -1 for those articles & paras
      |> (&Regex.replace(
            ~r/(\[::article::\]|\[::paragraph::\])(\d+[A-Z]*)(.*?—.*?\(([A-Z]?1)\))/m,
            &1,
            "\\g{1}\\g{2}-\\g{4}\\g{3}"
          )).()
      # rm spaces before or after sub-para hyphen
      |> (&Regex.replace(~r/\.[ ]—\(/m, &1, ".—(")).()
      |> (&Regex.replace(~r/\.—[ ]\(/m, &1, ".—(")).()
      # rm multi-spaces
      |> (&Regex.replace(~r/[ ]{2,}/m, &1, " ")).()
      # rm space at end of line
      |> (&Regex.replace(~r/[ ]$/m, &1, "")).()
      # rm space at start of line
      |> (&Regex.replace(~r/^[ ]/m, &1, "")).()
      # rm any space after end of tag
      |> (&Regex.replace(~r/(\[::[a-z]+::\])[ ]/m, &1, "\\g{1}")).()

    IO.puts("...complete")
    text
  end
end
