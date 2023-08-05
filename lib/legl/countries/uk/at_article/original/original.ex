defmodule Legl.Countries.Uk.AtArticle.Original.Original do
  @moduledoc """
  Functions to return the text of legislation from leg.gov.uk to the
  original.txt file and make it available for further processing
  """

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
    status: :latest,
    debug?: false
  }
  def run(opts) when is_list(opts) do
    opts = Enum.into(opts, @default_opts)
    File.open(@txt, [:write, :utf8])
    run(opts)
  end

  def run(%{source: :file} = opts) do
    with {:ok, body} <- File.read(@original),
         {:ok, document} <- Floki.parse_document(body),
         :ok <-
           process_source(document, opts) do
      IO.puts("Processed source text saved to file")
    else
      {:error, reason} ->
        IO.puts("ERROR saving source text #{reason}")
    end
  end

  def run(%{source: :web} = opts) do
    opts = Enum.into(opts, @default_opts)

    with %HTTPoison.Response{
           status_code: 200,
           body: body,
           headers: _headers
         } <-
           HTTPoison.get!(opts.url, [], follow_redirect: true, recv_timeout: opts.recv_timeout),
         {:ok, document} <-
           Floki.parse_document(body),
         :ok <-
           process_source(document, opts) do
      IO.puts("Processed source text saved to file")
    else
      %HTTPoison.Error{reason: error} ->
        IO.puts("#{error}")

      {:error, reason} ->
        IO.puts("ERROR saving source text #{reason}")
    end
  end

  def process_source(document, opts) do
    # Write body to file
    if opts.saveBody? do
      File.write(@pretty, Floki.raw_html(document, pretty: true))
      File.write(@original, Floki.raw_html(document))
      IO.puts("Original .html saved to file")
    end

    # Write the parsed html to file
    if opts.debug? == true do
      case File.write(@ex, inspect(document, limit: :infinity)) do
        :ok -> IO.puts("Parsed html saved to file")
        {:error, reason} -> IO.puts("Error saving parsed html #{reason}")
      end
    end

    text = Latest.process(document)

    # Replace multibyte characters
    # text = multibyte_character_replace(text)

    # IO.inspect(text, limit: :infinity)
    File.write!(@txt, text)
  end

  defp multibyte_character_replace(binary) do
    binary
    # "\u{B7}" == ·
    # |> (&Regex.replace(~r/[#{"\u{B7}"}]/m, &1, ~s/./)).()
    # "\u{B0}" == °
    |> (&Regex.replace(~r/[#{"\u{B0}"}]C/m, &1, ~s/degrees Celsius/)).()
    # "\u00B0" == °
    |> (&Regex.replace(~r/[#{"\u{00B0}"}]C/m, &1, ~s/degrees/)).()
    # "\u00E0" == à
    # |> (&Regex.replace(~r/[#{"\u00E0"}][ ]?/m, &1, ~s/a/)).()
    # "\u00E2" == â
    # |> (&Regex.replace(~r/[#{"\u00E2"}][ ]?/m, &1, ~s/a/)).()
    # "\u00E8" == è
    |> (&Regex.replace(~r/[#{"\u00E8"}][ ]?/m, &1, ~s/e/)).()
    # "\u00F4" == ô
    |> (&Regex.replace(~r/[#{"\u00F4"}][ ]?/m, &1, ~s/o/)).()
    # "\u00A3" == £
    # |> (&Regex.replace(~r/[#{"\u00A3"}]/m, &1, ~s/GBP/)).()
    # "\u00B1" == ±
    # |> (&Regex.replace(~r/[#{"\u00B1"}]/m, &1, ~s/+-/)).()
    # "\u00D7" == ×
    |> (&Regex.replace(~r/[#{"\u00D7"}]/m, &1, ~s/*/)).()
    # "\u2020" == †
    # |> (&Regex.replace(~r/[†]/m, &1, ~s//)).()
    # "\u00BD" == ½
    # |> (&Regex.replace(~r/[#{"\u00BD"}]/m, &1, ~s/.5/)).()
    # "\u00BF" == ¿
    # |> (&Regex.replace(~r/[#{"\u00BF"}]/m, &1, ~s//)).()
    # "\u00EF" == ï
    # |> (&Regex.replace(~r/[#{"\u00EF"}]/m, &1, ~s//)).()
    # "\u00B5" == µ
    # |> (&Regex.replace(~r/[#{"\u00B5"}]/m, &1, ~s/micro/)).()
    # "\u00BA" == <<194, 186>> == º
    |> (&Regex.replace(~r/#{<<194, 186>>}/m, &1, ~s/degs/)).()

    # "\u03B1" == α
    # |> (&Regex.replace(~r/#{<<206, 177>>}/m, &1, ~s/a/)).()
  end
end
