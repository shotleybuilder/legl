defmodule Legl.Countries.Uk.LeglRegister.Options do
  @moduledoc """
  Module has common option choices for running Legal Register operations
  """
  alias Legl.Countries.Uk.UkTypeCode
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
      case ExPrompt.choose("Choose Base", ["HEALTH & SAFETY", "ENVIRONMENT"]) do
        0 ->
          "UK S"

        1 ->
          "UK E"
      end
    )
  end

  @spec base_table_id(map()) :: map()
  def base_table_id(opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    Map.merge(opts, %{base_id: base_id, table_id: table_id})
  end

  @spec type_code(map()) :: map()
  def type_code(opts) do
    Map.put(
      opts,
      :type_code,
      case ExPrompt.choose("type_code? ", UkTypeCode.type_codes()) do
        index when index in 0..14 -> Enum.at(UkTypeCode.type_codes(), index)
        -1 -> ""
        _ -> ""
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
      ExPrompt.string("year? ", 2023)
    )
  end

  @spec name(opts()) :: opts()

  def name(%{name: n} = opts) when n in ["", nil] do
    Map.put(
      opts,
      :name,
      ExPrompt.string("Name ")
    )
  end

  def name(%{name: n} = opts) when is_binary(n), do: opts

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

  @spec type_class(map()) :: map()
  def type_class(opts) do
    Map.put(
      opts,
      :type_class,
      case ExPrompt.choose("Choose Type Class (Default \"\")", Models.type_class()) do
        index when index in 0..5 -> Enum.at(Models.type_class(), index)
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

  # workflow options are [:create, :update]
  # :update triggers the update workflow and populates the change log
  @spec workflow(opts()) :: opts()
  def workflow(%{workflow: workflow} = opts) when workflow not in ["", nil], do: opts

  @spec workflow(opts()) :: opts()
  def workflow(opts) do
    Map.put(
      opts,
      :workflow,
      case ExPrompt.choose("Workflow ", ["Update", "Delta Update"]) do
        0 -> :create
        1 -> :update
        -1 -> nil
      end
    )
  end

  @spec today(map()) :: map()
  def today(opts) do
    Map.put(
      opts,
      :today,
      case ExPrompt.choose(
             "amendment_checked ",
             ["Today", "Blank", "Today & Blank", "Not Today", "Not Today & Blank"]
           ) do
        0 -> :today
        1 -> :blank
        2 -> :today_and_blank
        3 -> :not_today
        4 -> :not_today_and_blank
        -1 -> nil
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

      true ->
        []
    end
  end

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
end
