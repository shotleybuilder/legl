defmodule Legl.Countries.Uk.AtArticle.Original.Original do
  @moduledoc """
  Functions to return the text of legislation from leg.gov.uk to the
  original.txt file and make it available for further processing
  """

  alias Legl.Countries.Uk.AtArticle.Original.AsMade
  alias Legl.Countries.Uk.AtArticle.Original.Latest
  # The original downloaded from leg.gov.uk
  @original ~s[lib/legl/data_files/html/original.html] |> Path.absname()
  @pretty ~s[lib/legl/data_files/html/original_pretty.html] |> Path.absname()
  @ex ~s[lib/legl/data_files/ex/original.ex] |> Path.absname()
  @txt ~s[lib/legl/data_files/txt/original.txt] |> Path.absname()

  @default_opts %{
    saveBody?: true,
    recv_timeout: 20000,
    source: :web,
    status: :latest
  }
  def run(opts) when is_list(opts) do
    opts = Enum.into(opts, @default_opts)
    run(opts)
  end

  def run(%{source: :file} = opts) do
    with {:ok, body} <- File.read(@original),
         {:ok, document} <- Floki.parse_document(body) do
      text =
        case opts.status do
          :as_made -> AsMade.process(document)
          :latest -> Latest.process(document)
        end

      # post-process and save text
      text = post_process(text)
      File.write(@txt, text)
    end
  end

  def run(%{source: :web} = opts) do
    opts = Enum.into(opts, @default_opts)

    with %HTTPoison.Response{
           status_code: 200,
           body: body,
           headers: headers
         } <-
           HTTPoison.get!(opts.url, [], follow_redirect: true, recv_timeout: opts.recv_timeout),
         {:ok, status} <- latest?(headers),
         {:ok, document} <-
           Floki.parse_document(body) do
      # Write body to file
      if opts.saveBody? do
        File.write(@pretty, Floki.raw_html(document, pretty: true))
        File.write(@original, Floki.raw_html(document))
        IO.puts("Original .html saved to file")
      end

      # Write the parsed html to file
      # case File.write(@ex, inspect(document, limit: :infinity)) do
      #  :ok -> IO.puts("Parsed html saved to file")
      #  _ -> IO.puts("Error saving parsed html")
      # end

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
    IO.puts("post_process/1")

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
      # join chapter
      |> (&Regex.replace(~r/(\[::chapter::\].*)\n(.*\[::region::\].*)/m, &1, "\\g{1} \\g{2}")).()
      # "\u{B7}" == ·
      |> (&Regex.replace(~r/[#{"\u{B7}"}]/m, &1, ~s/./)).()
      # "\u{B0}" == °
      |> (&Regex.replace(~r/[#{"\u{B0}"}]C/m, &1, ~s/degrees Celsius/)).()
      # "\u00B0" == °
      |> (&Regex.replace(~r/[#{"\u{00B0}"}]C/m, &1, ~s/degrees/)).()
      # "\u00E0" == à
      |> (&Regex.replace(~r/[#{"\u00E0"}][ ]?/m, &1, ~s/a/)).()
      # "\u00E2" == â
      |> (&Regex.replace(~r/[#{"\u00E2"}][ ]?/m, &1, ~s/a/)).()
      # "\u00E8" == è
      |> (&Regex.replace(~r/[#{"\u00E8"}][ ]?/m, &1, ~s/e/)).()
      # "\u00F4" == ô
      |> (&Regex.replace(~r/[#{"\u00F4"}][ ]?/m, &1, ~s/o/)).()
      # "\u00A3" == £
      |> (&Regex.replace(~r/[#{"\u00A3"}]/m, &1, ~s/GBP/)).()
      # "\u00B1" == ±
      |> (&Regex.replace(~r/[#{"\u00B1"}]/m, &1, ~s/+-/)).()
      # "\u00D7" == ×
      |> (&Regex.replace(~r/[#{"\u00D7"}]/m, &1, ~s/*/)).()
      # "\u2020" == †
      # |> (&Regex.replace(~r/[†]/m, &1, ~s//)).()
      # "\u00BD" == ½
      |> (&Regex.replace(~r/[#{"\u00BD"}]/m, &1, ~s/.5/)).()
      # "\u00BF" == ¿
      |> (&Regex.replace(~r/[#{"\u00BF"}]/m, &1, ~s//)).()
      # "\u00EF" == ï
      |> (&Regex.replace(~r/[#{"\u00EF"}]/m, &1, ~s//)).()
      # "\u00B5" == µ
      |> (&Regex.replace(~r/[#{"\u00B5"}]/m, &1, ~s/micro/)).()
      # Concatenate [::part::] with next line
      |> (&Regex.replace(~r/(\[::part::\].*)\n((?!\[::).*)/m, &1, "\\g{1} \\g{2}")).()
      # Concatenate [::chapter::] with next line
      |> (&Regex.replace(~r/(\[::chapter::\].*)\n((?!\[::).*)/m, &1, "\\g{1} \\g{2}")).()
      # Concatenate [::section::] with next line
      |> (&Regex.replace(~r/(\[::section::\].*)\n((?!\[::).*)/m, &1, "\\g{1} \\g{2}")).()
      # rm empty headings
      |> (&Regex.replace(~r/^\[::heading::\]\[::region::\].+?\n/m, &1, "")).()
      |> (&Regex.replace(~r/^\[::heading::\]\n/m, &1, "")).()
      # Join empty paragraphs
      |> (&Regex.replace(~r/^(\[::paragraph::\][\d\.]+)\n((?!\[::).*)/m, &1, "\\g{1} \\g{2}")).()

    IO.puts("...complete")
    text
  end
end
