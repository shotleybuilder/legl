defmodule Legl.Countries.Uk.LeglRegister.Amend.Options do
  alias Legl.Countries.Uk.LeglRegister.Amend.Csv
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO

  # Fields list for Airtable GET request for PATCH
  @amend_fields_list ~w[
    Name
    Title_EN
    type_code
    Year
    Number
    amendments_checked

    Amending
    Amended_by

    stats_amendings_count
    stats_self_amendings_count
    stats_amended_laws_count
    stats_amendings_count_per_law
    stats_amendings_count_per_law_detailed

    stats_self_amending_count
    stats_amending_laws_count
    stats_amendments_count
    stats_amendments_count_per_law
    amended_by_change_log
  ]

  # Comma delimited string
  @amend_fields @amend_fields_list |> Enum.join(",")

  @results_count 4000

  def amend_fields_list(), do: @amend_fields_list
  def amend_fields(), do: @amend_fields

  @default_opts %{
    name: "",
    type_class: "",
    sClass: "",
    family: "",
    percent?: false,
    filesave?: false,
    # include/exclude AT records holding today's date
    today: nil,
    # patch? only works with :update workflow
    patch?: true,
    # getting existing field data from Airtable
    view: "VS_CODE_AMENDMENT",
    # saving to csv?
    csv?: false
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

    if(opts.csv?, do: Map.put(opts, :file, Csv.openCSVfile()), else: opts)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  @doc """
  Gets Amending laws that are not present in the Base
  """
  def new_amending_law_finder(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> (&Map.put(&1, :view, new_amending_law_finder_view(&1))).()
      |> LRO.family()
      |> Map.put(:fields, [
        "Amending (from UK) - binary",
        "Amending",
        "Revoking (from UK) - binary",
        "Revoking"
      ])

    formula =
      []
      |> LRO.formula_family(opts)
      |> (&[
            ~s/OR({% Amending (calc)}=0.00,{% Amending (calc)}<1, {% Revoking (calc)}=0.00, {% Revoking (calc)}<1)/
            | &1
          ]).()

    Map.put(opts, :formula, ~s/AND(#{Enum.join(formula, ",")})/)
    |> IO.inspect(label: "OPTIONS: ")
  end

  # % DIFF Amending
  defp new_amending_law_finder_view(%{base_name: "UK S"}), do: "viwkGW5JF0YiNUlJQ"
  defp new_amending_law_finder_view(%{base_name: "UK E"}), do: "viwEiBh5ygBoaAvE3"

  def new_amended_by_law_finder(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> (&Map.put(&1, :view, new_amended_law_finder_view(&1))).()
      |> LRO.family()
      |> Map.put(:fields, [
        "Amended_by (from UK) - binary",
        "Amended_by",
        "Revoked_by (from UK) - binary",
        "Revoked_by"
      ])

    formula =
      []
      |> LRO.formula_family(opts)
      |> (&[
            ~s/OR({% Affected By (calc)}=0.00,{% Affected By (calc)}<1, {% Revoked By (calc)}=0.00,{% Revoked By (calc)}<1)/
            | &1
          ]).()

    Map.put(opts, :formula, ~s/AND(#{Enum.join(formula, ",")})/)
    |> IO.inspect(label: "OPTIONS: ")
  end

  # % DIFF Amended by
  defp new_amended_law_finder_view(%{base_name: "UK S"}), do: "viwAkbFl4dB4txpxx"
  defp new_amended_law_finder_view(%{base_name: "UK E"}), do: "viwou7VrF2rAevrDt"

  def set_options(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.type_code()
      |> LRO.type_class()
      |> LRO.workflow()
      |> LRO.family()
      |> LRO.today()
      |> LRO.view()
      |> LRO.patch?()
      |> formula()
      |> fields()

    if(opts.csv?, do: Map.put(opts, :file, Csv.openCSVfile()), else: opts)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def results_count() do
    case @results_count do
      c when is_integer(c) ->
        @results_count

      c when c in [nil, ""] ->
        ExPrompt.get("results_count?", 2000)
    end
  end

  def fields(%{workflow: :create} = opts) do
    Map.put(
      opts,
      :fields,
      ["record_id", "Name", "Title_EN", "type_code", "Year", "Number"]
    )
  end

  def fields(%{workflow: :update} = opts), do: Map.put(opts, :fields, @amend_fields_list)

  def formula(%{name: ""} = opts) do
    f =
      LRO.formula_today(opts, "amendments_checked")
      |> LRO.formula_type_code(opts)
      |> LRO.formula_type_class(opts)
      |> LRO.formula_family(opts)

    f =
      if opts.percent? != false,
        do: [~s/{% amending law in Base}<"1",{stats_amending_laws_count}>"0"/ | f],
        else: f

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
