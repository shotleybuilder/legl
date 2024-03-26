defmodule Legl.Countries.Uk.LeglRegister.Options do
  @moduledoc """
  Module has common option choices for running Legal Register operations
  """
  alias Legl.Countries.Uk.LeglRegister.TypeCode
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Countries.Uk.LeglRegister.Models

  @type formula :: list()
  @type opts :: map()

  @spec base_name(map()) :: map()
  def base_name(%{base_name: bn} = opts) when bn not in ["", nil], do: opts

  def base_name(opts) do
    Map.put(
      opts,
      :base_name,
      case ExPrompt.choose("Choose Base (default EHS)", ["HEALTH & SAFETY", "EHS"]) do
        0 ->
          "UK S"

        1 ->
          "UK EHS"

        -1 ->
          "UK EHS"
      end
    )
  end

  @spec base_table_id(map()) :: map()
  def base_table_id(opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    Map.merge(opts, %{base_id: base_id, table_id: table_id})
  end

  def type_code(%{name: name} = opts) when name not in ["", nil], do: opts

  @spec type_code(map()) :: map()
  def type_code(opts) do
    count = Enum.count(TypeCode.type_codes())

    Map.put(
      opts,
      :type_code,
      case ExPrompt.choose("type_code? ", TypeCode.type_codes()) do
        index when index in 0..count ->
          Enum.at(TypeCode.type_codes(), index)

        -1 ->
          ""

        _ ->
          ""
      end
    )
  end

  @spec number(map()) :: map()
  def number(opts) do
    Map.put(
      opts,
      :number,
      ExPrompt.get_required("number? ")
    )
  end

  @spec year(map()) :: map()
  def year(opts) do
    Map.put(
      opts,
      :year,
      ExPrompt.string("year?", 2024)
    )
  end

  def name(%{name: n} = opts) when n in ["", nil] do
    # name = if @name != "", do: @name, else: ExPrompt.string(~s/Name ("")/)
    # Map.put(opts, :name, name)
    Map.put(opts, :name, ExPrompt.string(~s/Name (Default "")/))
  end

  def name(%{name: n} = opts) when is_binary(n), do: opts

  def name(opts), do: name(Map.put(opts, :name, ""))

  @spec view(opts(), String.t()) :: opts()
  def view(opts, view) when is_binary(view), do: Map.put(opts, :view, view)

  @spec view(opts()) :: opts()
  def view(%{view: view} = opts) when view not in ["", nil] do
    case ExPrompt.confirm("Default View #{view}?") do
      true -> opts
      false -> view(Map.put(opts, :view, nil))
    end
  end

  @spec view(opts()) :: opts()
  def view(opts) do
    Map.put(
      opts,
      :view,
      ExPrompt.string("View ID (from url bar)")
    )
  end

  @spec family(map()) :: map()
  def family(%{base_name: "UK S"} = opts) do
    Map.put(
      opts,
      :family,
      case ExPrompt.choose("Choose Family", Models.hs_family()) do
        index when index in 0..20 -> Enum.at(Models.hs_family(), index)
        -1 -> ""
        _ -> ""
      end
    )
  end

  @spec family(map()) :: map()
  def family(%{base_name: "UK E"} = opts) do
    Map.put(
      opts,
      :family,
      case ExPrompt.choose("Choose Family", Models.e_family()) do
        index when index in 0..10 -> Enum.at(Models.e_family(), index)
        -1 -> ""
      end
    )
  end

  def family(%{base_name: bn} = opts) when bn not in ["", [], "UK EHS"],
    do:
      Map.put(
        opts,
        :family,
        opts.base_name
      )

  def family(%{view: view} = opts) when view in ["", nil], do: family(opts)
  def family(%{view: _} = opts), do: opts

  def family(opts),
    do:
      Map.put(
        opts,
        :family,
        case ExPrompt.choose("Choose Family", Models.ehs_family()) do
          index when index in 0..20 -> Enum.at(Models.ehs_family(), index)
          -1 -> ""
          _ -> ""
        end
      )

  def type_class(%{name: name} = opts) when name not in ["", nil], do: opts

  @spec type_class(opts()) :: map()
  def type_class(opts) do
    Map.put(
      opts,
      :type_class,
      case ExPrompt.choose("Choose Type Class (Default \"\")", Models.type_class()) do
        index when index in 0..6 -> Enum.at(Models.type_class(), index)
        -1 -> ""
      end
    )
  end

  @spec at_source(map()) :: map()
  def at_source(opts) do
    Map.put(
      opts,
      :source,
      case ExPrompt.choose("Choose Source of Records", ["Web (default)", "File"], 0) do
        0 -> :web
        1 -> :file
      end
    )
  end

  @spec leg_gov_uk_source(map()) :: map()
  def leg_gov_uk_source(opts) do
    Map.put(
      opts,
      :source,
      case ExPrompt.choose("Choose Source of Records", ["Web (default)", "File"], 0) do
        0 -> :web
        1 -> :file
      end
    )
  end

  @spec patch?(opts()) :: opts()
  def patch?(%{patch?: p} = opts) when is_boolean(p), do: opts

  def patch?(opts) do
    Map.put(
      opts,
      :patch?,
      ExPrompt.confirm("PATCH?", true)
    )
  end

  @workflow [
    :"New (w/Enact)",
    :"New (w/Enact w/oMD)",
    :"Update (w/Enact)",
    :"Update (w/o Enact)",
    :"Delta (w/o Extent & Enact)",
    :Metadata,
    :"Metadata+Enact",
    :Extent,
    :Enact,
    :Affect,
    :Taxa_from_LAT,
    :Taxa_from_leg_gov_uk
  ]

  # :update triggers the update workflow and populates the change log
  @spec workflow(opts()) :: opts()
  def workflow(%{workflow: workflow} = opts) when workflow not in ["", nil], do: opts

  def workflow(%{lrt_workflow_selection: n} = opts) do
    Map.put(
      opts,
      :workflow,
      @workflow
      |> Enum.with_index()
      |> Enum.into(%{}, fn {k, v} -> {v, k} end)
      |> Map.get(n)
    )
  end

  @spec workflow(opts()) :: opts()
  def workflow(opts) do
    case ExPrompt.choose("Workflow? #{__MODULE__}:", @workflow) do
      -1 ->
        nil

      n ->
        opts
        |> Map.put(
          :workflow,
          @workflow
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)
          |> Map.get(n)
        )
    end
  end

  @doc """
  Function to assemble the update functions into a list

  """
  @year &Legl.Countries.Uk.LeglRegister.Year.set_year/1
  @name &Legl.Countries.Uk.LeglRegister.IdField.lrt_acronym/1
  @md &Legl.Countries.Uk.Metadata.get_latest_metadata/2
  @tags &Legl.Countries.Uk.LeglRegister.Tags.set_tags/1
  @type_law &Legl.Countries.Uk.LeglRegister.TypeClass.set_type/1
  @type_class &Legl.Countries.Uk.LeglRegister.TypeClass.set_type_class/1
  @extent &Legl.Countries.Uk.LeglRegister.Extent.set_extent/2
  @enact &Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_enacting_laws/2
  @affect &Legl.Countries.Uk.LeglRegister.Amend.workflow/2
  @taxa_lat &Legl.Countries.Uk.LeglRegister.Taxa.set_taxa/2
  @taxa_leg_gov_uk &Legl.Countries.Uk.LeglRegister.Taxa.set_taxa_leg_gov_uk/2

  # map of tuples {the workflow, dropped fields}

  @workflow_choices [
    "New (w/Enact)":
      {[@md, @year, @name, @tags, @type_law, @type_class, @extent, @enact, @affect], :new},
    "New (w/Enact w/oMD)":
      {[@year, @name, @tags, @type_law, @type_class, @extent, @enact, @affect], :new},
    "Update (w/Enact)":
      {[
         @md,
         @year,
         @name,
         @tags,
         @type_law,
         @type_class,
         @extent,
         @enact,
         @affect
       ], :update},
    "Update (w/o Enact)":
      {[@md, @year, @name, @tags, @type_law, @type_class, @extent, @affect], :update},
    "Delta (w/o Extent & Enact)": {[@md, @affect], :delta},
    Metadata: {[@md, @year, @name, @type_law, @type_class], :metadata},
    Extent: {[@name, @extent], :extent},
    "Metadata+Enact": {[@md, @enact], :"metadata+enact"},
    Enact: {[@enact], :enact},
    Affect: {[@affect], :affect},
    Taxa_from_LAT: {[@taxa_lat], :taxa},
    Taxa_from_leg_gov_uk: {[@taxa_leg_gov_uk], :taxa}
  ]

  @spec update_workflow(opts()) :: opts()
  def update_workflow(%{workflow: workflow} = opts) when workflow not in ["", nil] do
    {update_workflow, drop_field} = Keyword.get(@workflow_choices, workflow)
    drop_fields = Legl.Countries.Uk.LeglRegister.DropFields.drop_fields(drop_field)

    Map.merge(
      opts,
      %{
        update_workflow: update_workflow,
        drop_fields: drop_fields
      }
    )
  end

  @spec create_workflow(opts()) :: opts()
  def create_workflow(%{workflow: workflow} = opts) when workflow not in ["", nil] do
    {create_workflow, drop_field} = Keyword.get(@workflow_choices, workflow)
    drop_fields = Legl.Countries.Uk.LeglRegister.DropFields.drop_fields(drop_field)
    Map.merge(opts, %{create_workflow: create_workflow, drop_fields: drop_fields})
  end

  @spec today(map()) :: map()
  def today(opts) do
    Map.put(
      opts,
      :today,
      case ExPrompt.choose(
             "Date Field: ",
             [
               "Today",
               "Blank",
               "Today & Blank",
               "Not Today",
               "Not Today & Blank",
               ">1 week Old",
               ">1 week Old & Blank"
             ]
           ) do
        0 -> :today
        1 -> :blank
        2 -> :today_and_blank
        3 -> :not_today
        4 -> :not_today_and_blank
        5 -> :older_than_one_week
        6 -> :older_than_one_week_and_blank
        -1 -> nil
      end
    )
  end

  @spec formula_today(list(), binary()) :: list() | []

  def formula_today(%{today?: false} = _opts, _field), do: []

  def formula_today(%{today: today} = _opts, field) do
    cond do
      today == :today ->
        [~s/OR({#{field}}!=BLANK(), {#{field}}=TODAY())/]

      today == :blank ->
        [~s/{#{field}}=BLANK()/]

      today == :today_and_blank ->
        [~s/OR({#{field}}=BLANK(), {#{field}}=TODAY())/]

      today == :not_today ->
        [~s/OR({#{field}}!=BLANK(), {#{field}}!=TODAY())/]

      today == :not_today_and_blank ->
        [~s/OR({#{field}}=BLANK(), {#{field}}!=TODAY())/]

      today == :older_than_one_week ->
        [~s/OR({#{field}}!=BLANK(), {#{field}}<=DATEADD(TODAY(), -7, "day"))/]

      today == :older_than_one_week_and_blank ->
        [~s/OR({#{field}}=BLANK(), {#{field}}<=DATEADD(TODAY(), -7, "day"))/]

      true ->
        []
    end
  end

  def formula_today(f, opts, field), do: f ++ formula_today(opts, field)

  @spec formula_type_code(formula(), opts()) :: list(formula()) | []
  def formula_type_code(f, %{type_code: type_code} = _opts)
      when type_code not in ["", nil, [""]] do
    [~s/{type_code}="#{type_code}"/ | f]
  end

  def formula_type_code(f, _), do: f

  @spec formula_type_class(formula(), opts()) :: list(formula()) | []
  def formula_type_class(f, %{type_class: type_class} = _opts)
      when type_class not in ["", nil, [""]] do
    [~s/{type_class}="#{type_class}"/ | f]
  end

  def formula_type_class(f, _), do: f

  @spec formula_family(formula(), opts()) :: list(formula()) | []
  def formula_family(f, %{family: family} = _opts)
      when family not in ["", nil, [""]] do
    [~s/{Family}="#{family}"/ | f]
  end

  def formula_family(f, _), do: f

  @spec formula_name(formula(), opts()) :: list(formula())
  def formula_name(f, %{name: name}) when name not in ["", nil],
    do: [~s/{Name}="#{name}"/ | f]

  def formula_name(f, _), do: f

  @spec formula_name(opts()) :: opts()
  def formula_name(%{name: name} = opts) do
    Map.put(
      opts,
      :formula,
      ~s/{Name}="#{name}"/
    )
  end

  def formula_names(%{names: names} = opts) when is_list(names) do
    Map.put(
      opts,
      :formula,
      Enum.map(names, fn name -> ~s/{Name}="#{name}"/ end)
      |> Enum.join(",")
      |> or_formula()
    )
  end

  defp or_formula(string) do
    ~s/OR(#{string})/
  end

  @spec formula_empty_metadata(binary(), opts()) :: list(formula())
  def formula_empty_metadata(f, _opts) do
    [
      case ExPrompt.choose(
             "Empty Metadata Field? (rtn for ALL)",
             ~w[md_subjects md_description md_modified md_total_paras si_code]
           ) do
        -1 ->
          ~s/AND({md_subjects}=BLANK(),{md_description}=BLANK(),{md_modified}=BLANK(),{md_total_paras}=BLANK(),{si_code}=BLANK())/

        0 ->
          ~s/{md_subjects}=BLANK()/

        1 ->
          ~s/{md_description}=BLANK()/

        2 ->
          ~s/{md_modified}=BLANK()/

        3 ->
          ~s/{md_total_paras}=BLANK()/

        4 ->
          ~s/{si_code}=BLANK()/
      end
      | f
    ]
  end

  def formula_empty_extent() do
    case ExPrompt.choose(
           "Empty Geo Field? (rtn for ALL)",
           ~w[Geo_Region Geo_Extent All]
         ) do
      -1 -> ""
      0 -> ~s/{Geo_Region}=BLANK()/
      1 -> ~s/{Geo_Extent}=BLANK()/
      2 -> ~s/AND({Geo_Region}=BLANK(),{Geo_Extent}=BLANK())/
    end
  end

  def formula_empty_amend(f, _) do
    [
      case ExPrompt.choose(
             "Empty Amend Field? (rtn for none)",
             ~w[🔺_stats_affected_laws_count 🔻_stats_affected_by_laws_count Both]
           ) do
        -1 ->
          ""

        0 ->
          ~s/{🔺_stats_affected_laws_count}=BLANK()/

        1 ->
          ~s/{🔻_stats_affected_by_laws_count}=BLANK()/

        2 ->
          ~s/AND({🔺_stats_affected_laws_count}=BLANK(),{🔻_stats_affected_by_laws_count}=BLANK())/
      end
      | f
    ]
  end

  def formula_empty_repeal_revoke(f, _) do
    [
      case ExPrompt.choose(
             "Empty Re[peal|voke] Field? (rtn for none)",
             ~w[Revoking Revoked_by Both]
           ) do
        -1 ->
          ""

        0 ->
          ~s/{Revoking}=BLANK()/

        1 ->
          ~s/{Revoked_by}=BLANK()/

        2 ->
          ~s/AND({Revoking}=BLANK(),{Revoked_by}=BLANK())/
      end
      | f
    ]
  end
end
