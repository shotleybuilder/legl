defmodule Legl.Countries.Uk.Article.Taxa.Options do
  @moduledoc """
  Functions to set the options for all taxa modules and functions
  """
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  alias Legl.Countries.Uk.AtArticle.Options, as: LAO

  @api_update_multi_lat_taxa %{
    table_name: "UK",
    lrt_fields: ["Name"],
    opts_label: "LRT OPTIONS",
    filesave?: false,
    patch?: true
  }
  @doc """
  Function to set the options for multi-law taxa

  Gets the 'Name' of the laws from the 'UK' LRT
  Makes a :lrt_params option to GET those records
  Drops the generic
  """
  def api_update_multi_lat_taxa(opts) do
    # Legal Register Table opts
    with(
      opts = Enum.into(opts, @api_update_multi_lat_taxa),
      opts = LAO.base_name(opts),
      {:ok, opts} <- LAO.table_id(opts),
      opts = LRO.type_class(opts),
      opts = LRO.type_code(opts),
      opts = LRO.family(opts),
      opts = LRO.today(opts),
      opts = Map.put(opts, :lrt_table_name, opts.table_name),
      opts = Map.put(opts, :lrt_table_id, opts.table_id),
      opts = Map.drop(opts, [:table_name, :table_id]),
      formula =
        []
        |> LRO.formula_type_class(opts)
        |> LRO.formula_type_code(opts)
        |> LRO.formula_family(opts)
        |> LRO.formula_today(opts, "Last Modified Rollup (from Articles)")
        |> (&[~s/{Count (Articles)}>0/ | &1]).(),
      opts = Map.put(opts, :lrt_formula, ~s/AND(#{Enum.join(formula, ",")})/),
      opts =
        Map.put(
          opts,
          :lrt_params,
          {:params,
           %{
             base: opts.base_id,
             table: opts.lrt_table_id,
             options: %{
               # view: opts.lrt_view,
               fields: opts.lrt_fields,
               formula: opts.lrt_formula
             }
           }}
        ),
      opts = taxa_workflow(opts, 0)
    ) do
      label =
        if Map.has_key?(opts, :opts_label) do
          opts.opts_label
        else
          "OPTIONS"
        end

      IO.inspect(opts, label: label)
      opts
    else
      {:error, msg} ->
        IO.puts(~s/ERROR: #{msg}/)
    end
  end

  @set_workflow_opts %{
    base_name: nil,
    table_name: "Articles",
    fields: [
      "ID",
      "Record_Type",
      "Text",
      "Record_ID",
      "type_code",
      "Year",
      "Number",
      "Part",
      "Chapter",
      "Section||Regulation"
    ],
    view: "",
    Name: "",
    type_code: "",
    Year: nil,
    Number: "",
    filesave?: true,
    patch?: false,
    source: :web,
    taxa_workflow: nil,
    part: "",
    chapter: "",
    section: "",
    # Set to :false for ID with this pattern UK_ukpga_1949_Geo6/12-13-14/74_CPA
    old_id?: false
  }

  def set_workflow_opts(opts) do
    with opts = Enum.into(opts, @set_workflow_opts),
         opts <- LAO.base_name(opts),
         {:ok, opts} <- LAO.table_id(opts),
         opts = if(opts.source == :web, do: LAO.name(opts), else: opts),
         # uses opt.name if exists or prompts if missing
         opts = Map.put(opts, :at_id, opts."Name"),
         opts = taxa_workflow(opts),
         opts =
           Map.put(
             opts,
             :formula,
             formula(opts)
           ) do
      label =
        if Map.has_key?(opts, :opts_label) do
          opts.opts_label
        else
          "OPTIONS"
        end

      IO.puts(~s/#{label}
                type_code: #{opts.type_code}
                Year: #{opts."Year"}
                Number: #{opts."Number"}
                base_name: #{opts.base_name}
                base_id: #{opts.base_id}
                table_name: #{opts.table_name}
                table_id: #{opts.table_id}
                patch?: #{opts.patch?}
                /)

      opts
    else
      {:error, msg} ->
        IO.puts(~s/ERROR: #{msg}/)
    end
  end

  def patch(opts) do
    Enum.into(opts, @set_workflow_opts)
  end

  @duty_actor &Legl.Countries.Uk.Article.Taxa.TaxaDutyActor.DutyActor.api_duty_actor/2
  @duty_type &Legl.Countries.Uk.Article.Taxa.DutyTypeTaxa.DutyType.api_duty_type/2
  @popimar &Legl.Countries.Uk.Article.Taxa.TaxaPopimar.Popimar.process/1

  @dutyholder_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.dutyholder_aggregate/1
  @rightsholder_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.rightsholder_aggregate/1

  @responsibility_holder_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.responsibility_holder_aggregate/1
  @power_holder_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.power_holder_aggregate/1

  @duty_actor_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.duty_actor_aggregate/1
  @duty_actor_gvt_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.duty_actor_gvt_aggregate/1
  @duty_type_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.duty_type_aggregate/1
  @popimar_aggregate &Legl.Countries.Uk.Article.Taxa.LATTaxa.popimar_aggregate/1

  @workflow_choices [
    Update: [
      @duty_actor,
      @duty_type,
      @popimar,
      @dutyholder_aggregate,
      @rightsholder_aggregate,
      @responsibility_holder_aggregate,
      @power_holder_aggregate,
      @duty_actor_aggregate,
      @duty_actor_gvt_aggregate,
      @duty_type_aggregate,
      @popimar_aggregate
    ],
    "Duty Actor": [@duty_actor],
    "Duty Type & Role Holder": [@duty_actor, @duty_type],
    POPIMAR: [@duty_actor, @duty_type, @popimar, @popimar_aggregate],
    Aggregates: [
      @dutyholder_aggregate,
      @rightsholder_aggregate,
      @responsibility_holder_aggregate,
      @power_holder_aggregate,
      @duty_actor_aggregate,
      @duty_actor_gvt_aggregate,
      @duty_type_aggregate,
      @popimar_aggregate
    ]
  ]

  def taxa_workflow(%{taxa_workflow_selection: tws} = opts)
      when is_integer(tws) and tws not in [nil, ""],
      do: taxa_workflow(opts, tws)

  def taxa_workflow(%{taxa_workflow: nil} = opts) do
    case ExPrompt.choose(
           "LAT Taxa Workflow",
           Enum.map(@workflow_choices, fn {k, _} -> k end)
         ) do
      -1 ->
        :ok

      n ->
        taxa_workflow(opts, n)
    end
  end

  def taxa_workflow(opts), do: opts

  def taxa_workflow(opts, n) when is_integer(n),
    do:
      opts
      |> Map.put(
        :taxa_workflow,
        Enum.map(@workflow_choices, fn {_k, v} -> v end)
        |> Enum.with_index()
        |> Enum.into(%{}, fn {k, v} -> {v, k} end)
        |> Map.get(n)
      )

  defp formula(opts) do
    record_type =
      ~w[
      part
      chapter
      section
      sub-section
      heading
      article
      sub-article
    ]
      |> Enum.map(&String.replace_prefix(~s/"#{&1}"/, "", "{Record_Type}="))
      |> Enum.join(",")

    formula = [~s/{flow}="main"/]

    formula = formula ++ [~s/OR(#{record_type})/]

    formula =
      cond do
        Regex.match?(~r/[a-z]+/, opts.type_code) and is_integer(opts."Year") and
            Regex.match?(~r/\d+/, opts."Number") ->
          [
            ~s/{type_code}="#{opts.type_code}"/,
            ~s/{Year}="#{opts."Year"}"/,
            ~s/{Number}="#{opts."Number"}"/ | formula
          ]

        opts."Name" == "" ->
          formula

        true ->
          [~s/{UK}="#{opts."Name"}"/ | formula]
      end

    formula =
      cond do
        Regex.match?(~r/[1234567890]/, opts.part) == true ->
          formula ++ [~s/{Part}="#{opts.part}"/]

        true ->
          formula
      end

    formula =
      cond do
        Regex.match?(~r/[1234567890]/, opts.chapter) == true ->
          formula ++ [~s/{Chapter}="#{opts.chapter}"/]

        true ->
          formula
      end

    formula =
      cond do
        Regex.match?(~r/[1234567890]/, opts.section) == true ->
          formula ++ [~s/{Section||Regulation}="#{opts.section}"/]

        true ->
          formula
      end

    ~s/AND(#{Enum.join(formula, ", ")})/
  end
end
