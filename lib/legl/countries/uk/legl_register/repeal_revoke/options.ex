defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.Options do
  @moduledoc """
  Module to handle setting default and user provided options

  """
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Csv

  @code_full "❌ Revoked / Repealed / Abolished"
  @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"

  @live %{
    green: @code_live,
    amber: @code_part,
    red: @code_full
  }

  # these are the fields for the source data
  # also used for patch after empty fields are dropped
  @at_url_field "leg.gov.uk - changes"
  @fields ~w[
    record_id
    Name
    Title_EN
    type_code
    Number
    Year
    Live?
    Revoked_by
    Live?_description
    Live?_change_log
  ] ++ [@at_url_field]

  # these are the fields that will be updated in Airtable
  @fields_update ~w[
      Name
      Live?
      Revoked_by
      Live?_description
    ] |> Enum.join(",")

  @default_opts %{
    # field content is list of tuples of {field name, content state}
    name: nil,
    field_content: "",
    base_name: nil,
    type_code: [""],
    type_class: "",
    sClass: "",
    family: "",
    # Workflow is either :create or :update
    workflow: :create,
    # Content for Live? field
    code_full: @code_full,
    code_part: @code_part,
    code_live: @code_live,
    # today's date
    date: ~s/#{Date.utc_today()}/,
    # a list
    live: "",
    fields_source: @fields,
    fields_update: @fields_update,
    fields_new_law: ~w[Name Title_EN type_code Year Number] |> Enum.join(","),
    view: "VS_CODE_REPEALED_REVOKED",
    # Switches for save
    csv?: false,
    patch?: nil,
    post?: false,
    # include/exclude AT records holding today's date
    today?: false
  }

  def single_record_options(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.workflow()
      |> LRO.name()
      |> LRO.view()
      |> LRO.patch?()
      |> formula()
      |> fields()

    if(opts.csv?, do: Map.put(opts, :file, Csv.openFiles(opts)), else: opts)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def set_options(opts) do
    # IO.puts("DEFAULTS: #{inspect(@default_opts)}")
    Enum.into(opts, @default_opts)
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> LRO.type_code()
    |> LRO.type_class()
    |> LRO.family()
    |> LRO.today()
    |> LRO.patch?()
    |> field_content()
    |> fields()
    |> formula()
    |> live_field_formula()
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  defp fields(opts) do
    Map.put(
      opts,
      :fields,
      @fields
    )
  end

  defp field_content(%{field_content: ""} = opts), do: opts

  defp field_content(opts) do
    f =
      Enum.reduce(opts.field_content, [], fn {field, content}, acc ->
        content = if content == "", do: "BLANK()", else: ~s/"#{content}"/
        [~s/{#{field}}=#{content}/ | acc]
      end)

    f = ~s/#{Enum.join(f, ",")}/

    Map.put(opts, :field_content, f)
  end

  defp live_field_formula(%{live: ""} = opts), do: opts

  defp live_field_formula(%{live: live} = opts) when is_binary(live) do
    Map.put(opts, :live, ~s/{Live?}="#{Map.get(@live, live)}"/)
  end

  defp live_field_formula(%{live: live} = opts) when is_list(live) do
    formula =
      Enum.reduce(opts.live, "", fn x, acc ->
        case Map.get(@live, x) do
          nil -> acc
          res -> acc <> ~s/{Live?}="#{res}"/
        end
      end)

    case formula do
      "" ->
        Map.put(opts, :live, "")

      _ ->
        formula
        |> (&fn -> ~s/OR(#{&1})/ end).()
        |> (&Map.put(opts, :live, &1)).()
    end
  end

  def formula(%{name: n} = opts) when n in ["", nil] do
    f =
      LRO.formula_today(opts, "Live?_checked")
      |> LRO.formula_type_code(opts)
      |> LRO.formula_type_class(opts)
      |> LRO.formula_family(opts)

    f = if opts.sClass != "", do: [~s/{sClass}="#{opts.sClass}"/ | f], else: f
    f = if opts.live != "", do: [opts.live | f], else: f
    f = if opts.field_content != "", do: [opts.field_content | f], else: f

    Map.put(
      opts,
      :formula,
      ~s/AND(#{Enum.join(f, ",")})/
    )
  end

  def formula(%{name: name} = opts) do
    Map.put(
      opts,
      :formula,
      ~s/{name}="#{name}"/
    )
  end
end
