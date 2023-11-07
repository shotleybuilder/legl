defmodule Legl.Countries.Uk.LeglRegister.Amend.Options do
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Countries.Uk.LeglRegister.Amend.Csv
  alias Legl.Countries.Uk.UkTypeCode
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO

  @amended_fields_list ~s[
    Name
    Title_EN
    type_code
    Year
    Number
    amendments_checked
    Amended_by
    leg_gov_uk_updates
    stats_self_amending_count
    stats_amending_laws_count
    stats_amendments_count
    stats_amendments_count_per_law
    amended_by_change_log
  ] |> String.split()

  @amended_fields @amended_fields_list |> Enum.join(",")

  def amended_fields_list(), do: @amended_fields_list
  def amended_fields(), do: @amended_fields

  @default_opts %{
    name: "",
    type_class: "",
    sClass: "",
    family: "",
    percent?: false,
    filesave?: false,
    # include/exclude AT records holding today's date
    today: false,
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
      |> LRO.type_code()
      |> LRO.family()
      |> LRO.today()

    # workflow options are [:create, :update]
    # :update triggers the update workflow and populates the change log
    opts = workflow(opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})

    {:ok, type_classes} = Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class)
    {:ok, sClass} = Legl.Countries.Uk.SClass.sClass(opts.sClass)

    opts =
      Map.merge(opts, %{
        type_class: type_classes,
        sClass: sClass
      })

    fields = fields(opts)
    formula = formula(opts.type_code, opts)

    opts = Map.put(opts, :fields, fields)
    opts = Map.put(opts, :formula, formula)

    opts = if(opts.csv?, do: Map.put(opts, :file, Csv.openCSVfile()), else: opts)

    IO.puts("AT FIELDS: #{inspect(fields)}")
    IO.puts("AT FORMULA: #{formula}")
    IO.puts("OPTIONS: #{inspect(opts)}")

    opts
  end

  @spec workflow(map()) :: map()
  defp workflow(opts) do
    Map.put(
      opts,
      :workflow,
      case ExPrompt.choose("workflow? ", ["Update", "Delta Update"]) do
        0 -> :create
        1 -> :update
      end
    )
  end

  def fields(%{workflow: :create} = _opts),
    do: ["record_id", "Name", "Title_EN", "type_code", "Year", "Number"]

  def fields(%{workflow: :update} = _opts), do: @amended_fields_list

  def formula(type, %{name: ""} = opts) do
    f = LRO.formula_today(opts, "amendments_checked")

    f = if opts.type_code != [""], do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f

    f =
      if opts.percent? != false,
        do: [~s/{% amending law in Base}<"1",{stats_amending_laws_count}>"0"/ | f],
        else: f

    f =
      if opts.family != "",
        do: [~s/{Family}="#{opts.family}"/ | f],
        else: f

    f =
      if opts.sClass != "",
        do: [~s/{sClass}="#{opts.sClass}"/ | f],
        else: f

    ~s/AND(#{Enum.join(f, ",")})/
  end

  def formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end
end
