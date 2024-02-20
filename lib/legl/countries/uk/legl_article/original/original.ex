defmodule Legl.Countries.Uk.AtArticle.Original.Original do
  @moduledoc """
  Functions to return the text of legislation from leg.gov.uk to the
  original.txt file and make it available for further processing
  """

  alias Legl.Countries.Uk.AtArticle.Original.Latest
  # The original downloaded from leg.gov.uk

  @default_opts %{
    status: :latest
  }
  def run(_, opts) when is_map(opts) do
    opts = Enum.into(opts, @default_opts)
    File.open(opts.path_orig_txt, [:write, :utf8])
    run(opts)
  end

  def run(%{source: :file} = opts) do
    with {:ok, body} <- File.read(opts.path_orig_html) do
      process(body, opts)
    else
      {:error, reason} ->
        IO.puts("ERROR #{reason}\n [#{__MODULE__}.run - file]")
    end
  end

  @spec run(map()) :: {:ok, binary} | :ok
  def run(%{source: :web} = opts) do
    opts = Enum.into(opts, @default_opts)

    url = Legl.Services.LegislationGovUk.Url.article_url(opts."Name")

    with {:ok, body, made?} <- Legl.Services.LegislationGovUk.RecordGeneric.article(url),
         opts = Map.put(opts, :made?, made?),
         :ok <-
           if(opts.filesave?, do: save_html(body, opts), else: :ok) do
      process(body, opts)
    else
      %HTTPoison.Error{reason: error} ->
        IO.puts("#{error}")
        :error

      %HTTPoison.Response{status_code: status_code, body: body} ->
        IO.puts("HTTPS ERROR: #{status_code}\n#{body}\n[__MODULE__].original")
        :error

      {:error, reason} ->
        IO.puts("ERROR #{reason}\n [#{__MODULE__}.run - web]")
        :error
    end
  end

  @spec process(binary(), map()) :: {:ok, binary()} | :ok
  defp process(body, opts) do
    with {:ok, document} <- Floki.parse_document(body),
         :ok <-
           if(opts.filesave?,
             do: File.write(opts.path_orig_ex, inspect(document, limit: :infinity)),
             else: :ok
           ),
         text <- Latest.process(document),
         :ok <- if(opts.filesave?, do: File.write(opts.path_orig_txt, text), else: :ok),
         :ok = if(opts.filesave?, do: IO.puts(".html, .ex and .txt files saved"), else: :ok) do
      {:ok, text, opts}
    else
      {:error, reason} ->
        IO.puts("ERROR #{reason}\n [#{__MODULE__}.process]")
    end
  end

  @spec save_html(map(), map()) :: :ok
  defp save_html(document, opts) do
    File.write(opts.path_orig_html_pretty, Floki.raw_html(document, pretty: true))
    File.write(opts.path_orig_html, Floki.raw_html(document))
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
