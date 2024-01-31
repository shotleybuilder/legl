defmodule Legl.Countries.Uk.Article.Options do
  @moduledoc """
  Module has common option choices for running Legal Register Articles Table operations
  """
  alias Legl.Services.Airtable.AtBasesTables

  @type formula :: list()
  @type opts :: map()

  defp print_opts(%{print_opts?: true} = opts) do
    IO.puts("ARTICLE OPTIONS:
      Total count: #{Enum.count(opts)}
      Name: #{opts."Name"}
      SOURCE___
      source: #{opts.source}
      WORKFLOW___
      article_workflow_name: #{opts.article_workflow_name}
      article_workflow_selection: #{opts.article_workflow_selection}
      lat_workflow: #{inspect(opts.lat_workflow)}
      BOOLEAN___
      filesave?: #{opts.filesave?}
      html?: #{opts.html?},
      type: #{opts.type},
      pbs?: #{opts.pbs?}
      ")
    opts
  end

  defp print_opts(opts), do: opts

  def api_article_options(opts) do
    IO.puts(~s/_____\nSetting Options from [Uk.Article.Options.api_article_options]/)

    opts
    |> name()
    # alt :web or :file
    |> Map.put(:source, :web)
    |> workflow()
    |> lat_workflow()
    |> print_opts()
  end

  @spec base_name(map()) :: map()
  def base_name(%{base_name: bn, base_id: id} = opts)
      when bn not in ["", nil] and id not in ["", nil],
      do: opts

  def base_name(opts) do
    {base_name, base_id} =
      case ExPrompt.choose(
             "Choose Base (default EXITS)",
             Enum.map(Legl.Services.Airtable.AtBases.bases(), fn {_, {k, _}} -> k end)
           ) do
        -1 ->
          :ok

        n ->
          Keyword.get(
            Legl.Services.Airtable.AtBases.bases(),
            n |> Integer.to_string() |> String.to_atom()
          )
      end

    Map.merge(
      opts,
      %{base_name: base_name, base_id: base_id}
    )
  end

  @spec table_id(opts()) :: opts()
  def table_id(opts) do
    case Legl.Services.Airtable.AtTables.get_table_id(opts.base_id, opts.table_name) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table_id} ->
        {:ok,
         Map.put(
           opts,
           :table_id,
           table_id
         )}
    end
  end

  @spec base_table_id(map()) :: map()
  def base_table_id(opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    Map.merge(opts, %{base_id: base_id, table_id: table_id})
  end

  @spec name(opts()) :: opts()
  def name(%{Name: n} = opts) when n in ["", nil, []] do
    Map.put(
      opts,
      :Name,
      ExPrompt.string(~s/Name ("")/)
    )
  end

  def name(%{Name: n} = opts) when is_binary(n), do: opts
  def name(%{Name: false} = opts), do: opts
  def name(opts), do: name(Map.put(opts, :Name, ""))

  @article_workflow_name [
    :Original,
    :"Original -> Clean",
    :"Original -> Clean -> Parse",
    :"Original -> Clean -> Parse -> Airtable",
    :"Original -> Clean -> Parse -> Airtable -> Taxa",
    :"Original -> Clean -> Parse -> Airtable -> CSV",
    :"Original -> Clean -> Parse -> Airtable -> CSV -> Taxa"
  ]

  @spec workflow(opts()) :: opts()
  def workflow(%{article_workflow_name: workflow} = opts) when workflow not in ["", nil], do: opts

  def workflow(%{article_workflow_selection: n} = opts) do
    Map.put(
      opts,
      :article_workflow_name,
      @article_workflow_name
      |> Enum.with_index()
      |> Enum.into(%{}, fn {k, v} -> {v, k} end)
      |> Map.get(n)
    )
  end

  @spec workflow(opts()) :: opts()
  def workflow(opts) do
    case ExPrompt.choose("Workflow ", @article_workflow_name) do
      -1 ->
        nil

      n ->
        opts
        |> Map.put(
          :article_workflow_name,
          @article_workflow_name
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)
          |> Map.get(n)
        )
    end
  end

  @original &Legl.Countries.Uk.AtArticle.Original.Original.run/2
  @clean &Legl.Countries.Uk.UkClean.api_clean/2
  # @annotate &Legl.Countries.Uk.AirtableArticle.UkAnnotations.annotations/2
  @parse &UK.Parser.api_parse/2
  @airtable &Legl.Airtable.Schema.schema/2
  # Called when made? = false
  # @post_process &Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess.process/2
  @csv &Legl.airtable/3
  @taxa &Legl.Countries.Uk.Article.Taxa.LATTaxa.api_update_lat_taxa_from_text/2
  # @post_process &Legl.Countries.Uk.AirtableArticle.UkPostRecordProcess.process/1

  @workflow_functions [
    Original: [@original],
    "Original -> Clean": [@original, @clean],
    "Original -> Clean -> Parse": [@original, @clean, @parse],
    "Original -> Clean -> Parse -> Airtable": [@original, @clean, @parse, @airtable],
    "Original -> Clean -> Parse -> Airtable -> Taxa": [
      @original,
      @clean,
      @parse,
      @airtable,
      @taxa
    ],
    "Original -> Clean -> Parse -> Airtable -> CSV": [@original, @clean, @parse, @airtable, @csv],
    "Original -> Clean -> Parse -> Airtable -> CSV -> Taxa": [
      @original,
      @clean,
      @parse,
      @airtable
    ]
  ]

  @spec lat_workflow(opts()) :: opts()
  def lat_workflow(%{article_workflow_name: workflow} = opts) when workflow not in ["", nil] do
    Map.merge(
      opts,
      %{
        lat_workflow: Keyword.get(@workflow_functions, workflow)
      }
    )
  end
end
