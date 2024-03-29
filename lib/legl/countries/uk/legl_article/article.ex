defmodule Legl.Countries.Uk.LeglArticle.Article do
  @moduledoc """
  Functions to get and parse a law from legislation.gov.uk

  Called like this:
  > UK.lat(filesave?: true, type: :regulation, pbs?: false, country: :uk)

  WORKFLOW
  The workflow is set in Legl.Countries.Uk.Article.Options

  Comprises the following functions:
    Legl.Countries.Uk.AtArticle.Original.Original.run/2
    Legl.Countries.Uk.UkClean.api_clean/2
    UK.Parser.api_parse/2
    Legl.Airtable.Schema.schema/2
    Legl.airtable/3
    Legl.Countries.Uk.Article.Taxa.LATTaxa.api_update_lat_taxa_from_text/2

  """

  alias Legl.Countries.Uk.Article.Options

  @path_orig_html ~s[lib/legl/data_files/html/original.html] |> Path.absname()
  @path_orig_html_pretty ~s[lib/legl/data_files/html/original_pretty.html] |> Path.absname()
  # @path_orig_ex ~s[lib/legl/data_files/ex/original.ex] |> Path.absname()
  @path_orig_txt ~s[lib/legl/data_files/txt/original.txt] |> Path.absname()
  @path_clean_txt ~s[lib/legl/data_files/txt/clean.txt] |> Path.absname()
  @path_parsed_txt ~s[lib/legl/data_files/txt/parsed.txt] |> Path.absname()
  @path_at_schema_txt ~s[lib/legl/data_files/json/at_schema.json] |> Path.absname()

  def api_article(opts) do
    opts = Options.api_article_options(opts)

    opts =
      Map.merge(opts, %{
        path_orig_html: @path_orig_html,
        path_orig_html_pretty: @path_orig_html_pretty,
        path_orig_txt: @path_orig_txt,
        # path_orig_ex: @path_orig_ex,
        path_clean_txt: @path_clean_txt,
        path_parsed_txt: @path_parsed_txt,
        path_at_schema_txt: @path_at_schema_txt
      })

    article(opts)
  end

  defp article(opts) do
    {binary, _opts} =
      Enum.reduce(opts.lat_workflow, {nil, opts}, fn f, acc ->
        result =
          case :erlang.fun_info(f)[:arity] do
            1 -> f.(elem(acc, 0))
            2 -> f.(elem(acc, 0), elem(acc, 1))
          end

        case result do
          {:ok, record, opts} -> {record, opts}
          {:ok, record} -> {record, opts}
          :error -> {"", opts}
        end
      end)

    {:ok, binary}
  end
end
