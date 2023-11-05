defmodule Legl.Countries.Uk.LeglRegister.Amend.Options do
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Countries.Uk.LeglRegister.Amend.Csv
  alias Legl.Countries.Uk.UkTypeCode

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
    today?: false,
    # patch? only works with :update workflow
    patch?: true,
    # getting existing field data from Airtable
    view: "VS_CODE_AMENDMENT",
    # saving to csv?
    csv?: false
  }
  def set_options(opts) do
    opts = Enum.into(opts, @default_opts)

    opts = base_name(opts)

    opts = type_code(opts)

    opts = amendment_checked(opts)

    # workflow options are [:create, :update]
    # :update triggers the update workflow and populates the change log
    opts = workflow(opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})

    {:ok, type_classes} = Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class)
    {:ok, sClass} = Legl.Countries.Uk.SClass.sClass(opts.sClass)
    {:ok, family} = Legl.Countries.Uk.Family.family(opts.family)

    opts =
      Map.merge(opts, %{
        type_class: type_classes,
        sClass: sClass,
        family: family
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

  @spec base_name(map()) :: map()
  defp base_name(opts) do
    Map.put(
      opts,
      :base_name,
      case ExPrompt.choose("Choose Base", ["HEALTH & SAFETY", "ENVIRONMENT"]) do
        0 ->
          "UK S"

        1 ->
          "UK E"
      end
    )
  end

  @spec type_code(map()) :: map()
  defp type_code(opts) do
    type_codes =
      UkTypeCode.type_codes()
      |> Enum.with_index(fn v, k -> {k, v} end)

    Map.put(
      opts,
      :type_code,
      ExPrompt.choose("type_code? ", UkTypeCode.type_codes())
      |> (&List.keyfind(type_codes, &1, 0)).()
      |> elem(1)
    )
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

  defp amendment_checked(opts) do
    Map.put(
      opts,
      :today?,
      case ExPrompt.choose(
             "amendment_checked ",
             ["Today", "Blank", "Today & Blank", "Not Today", "Not Today & Blank"]
           ) do
        0 -> :today
        1 -> :blank
        2 -> :today_blank
        3 -> :not_today
        4 -> :not_today_blank
      end
    )
  end

  def fields(%{workflow: :create} = _opts),
    do: ["record_id", "Name", "Title_EN", "type_code", "Year", "Number"]

  def fields(%{workflow: :update} = _opts), do: @amended_fields_list

  def formula(type, %{name: ""} = opts) do
    f =
      cond do
        opts.today? == :today ->
          [~s/OR({amendments_checked}!=BLANK(), {amendments_checked}=TODAY())/]

        opts.today? == :blank ->
          [~s/{amendments_checked}=BLANK()/]

        opts.today? == :today_blank ->
          [~s/OR({amendments_checked}=BLANK(), {amendments_checked}=TODAY())/]

        opts.today? == :not_today ->
          [~s/OR({amendments_checked}!=BLANK(), {amendments_checked}!=TODAY())/]

        opts.today? == :not_today_blank ->
          [~s/OR({amendments_checked}=BLANK(), {amendments_checked}!=TODAY())/]

        true ->
          []
      end

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
