defmodule Legl.Countries.Uk.AtArticle.AtTaxa.Options do
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
    name: "",
    filesave?: true,
    patch?: false,
    source: :web,
    part: "",
    chapter: "",
    section: "",
    workflow: [actor: true, dutyType: true, popimar: true, aggregate: true],
    # Set to :false for ID with this pattern UK_ukpga_1949_Geo6/12-13-14/74_CPA
    old_id?: false
  }

  def set_workflow_opts(opts) do
    opts =
      case Keyword.has_key?(opts, :workflow) do
        true ->
          Keyword.put(
            opts,
            :workflow,
            Keyword.merge(@default_opts.workflow, Keyword.get(opts, :workflow))
          )

        _ ->
          opts
      end

    opts = Enum.into(opts, @default_opts)

    opts = Map.put(opts, :workflow, Enum.into(opts.workflow, %{}))

    opts = LAO.base_name(opts)

    opts = LAO.table_id(opts)

    opts = LAO.name(opts)

    opts = Map.put(opts, :at_id, opts.name)

    opts =
      Enum.reduce(opts.workflow, opts.fields, fn
        {_k, true}, acc -> acc
        {:actor, false}, acc -> ["Duty Actor" | acc]
        {:dutyType, false}, acc -> ["Duty Type" | acc]
        {:popimar, false}, acc -> ["POPIMAR" | acc]
      end)
      |> (&Map.put(opts, :fields, &1)).()

    opts =
      Map.put(
        opts,
        :formula,
        formula(opts)
      )

    IO.inspect(opts, label: "OPTIONS")
  end

  def patch(opts) do
    Enum.into(opts, @default_opts)
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
      case opts.at_id do
        "" -> formula
        _ -> formula ++ [~s/{UK}="#{opts.at_id}"/]
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
