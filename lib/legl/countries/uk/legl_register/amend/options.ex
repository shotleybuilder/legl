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

  def formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end
end
