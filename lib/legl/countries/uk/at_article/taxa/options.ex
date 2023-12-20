defmodule Legl.Countries.Uk.Article.Taxa.Options do
  @moduledoc """
  Functions to set the options for all taxa modules and functions
  """

  alias Legl.Countries.Uk.AtArticle.Options, as: LAO

  @default_opts %{
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
      "Section||Regulation"
    ],
    view: "",
    name: "",
    type_code: "",
    Year: nil,
    Number: "",
    filesave?: true,
    patch?: false,
    source: :web,
    part: "",
    chapter: "",
    section: "",
    # Set to :false for ID with this pattern UK_ukpga_1949_Geo6/12-13-14/74_CPA
    old_id?: false
  }

  def set_workflow_opts(opts) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> LAO.base_name()
      |> LAO.table_id()

    # uses opt.name if exists or prompts if missing
    opts = if opts.source == :web, do: LAO.name(opts), else: opts

    opts = Map.put(opts, :at_id, opts.name)

    opts = taxa_workflow(opts)

    opts =
      Map.put(
        opts,
        :formula,
        formula(opts)
      )

    label =
      if Map.has_key?(opts, :opts_label) do
        opts.opts_label
      else
        "OPTIONS"
      end

    IO.inspect(opts, label: label)
  end

  def patch(opts) do
    Enum.into(opts, @default_opts)
  end

  @duty_actor &Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyActor.DutyActor.process/1
  @duty_type &Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType.process/1
  @popimar &Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaPopimar.Popimar.process/1

  @dutyholder_aggregate &Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa.dutyholder_aggregate/1
  @dutyholder_gvt_aggregate &Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa.dutyholder_gvt_aggregate/1
  @duty_actor_aggregate &Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa.duty_actor_aggregate/1
  @duty_actor_gvt_aggregate &Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa.duty_actor_gvt_aggregate/1
  @duty_type_aggregate &Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa.duty_type_aggregate/1
  @popimar_aggregate &Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa.popimar_aggregate/1

  @workflow_choices [
    Update: [
      @duty_actor,
      @duty_type,
      @popimar,
      @dutyholder_aggregate,
      @dutyholder_gvt_aggregate,
      @duty_actor_aggregate,
      @duty_actor_gvt_aggregate,
      @duty_type_aggregate,
      @popimar_aggregate
    ],
    "Duty Actor": [@duty_actor],
    "Duty Type & Dutyholder": [@duty_type],
    POPIMAR: [@duty_type, @popimar, @popimar_aggregate],
    Aggregates: [
      @dutyholder_aggregate,
      @duty_actor_aggregate,
      @duty_type_aggregate,
      @popimar_aggregate
    ]
  ]

  def taxa_workflow(opts) do
    case ExPrompt.choose(
           "LAT Taxa Workflow",
           Enum.map(@workflow_choices, fn {k, _} -> k end)
         ) do
      -1 ->
        :ok

      n ->
        opts
        |> Map.put(
          :taxa_workflow,
          Enum.map(@workflow_choices, fn {_k, v} -> v end)
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)
          |> Map.get(n)
        )
    end
  end

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

        opts.at_id == "" ->
          formula

        true ->
          [~s/{UK}="#{opts.at_id}"/ | formula]
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
