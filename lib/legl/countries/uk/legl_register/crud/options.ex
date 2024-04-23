defmodule Legl.Countries.Uk.LeglRegister.CRUD.Options do
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Countries.Uk.LeglRegister.DropFields, as: DF
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO

  @default_opts %{
    base_name: "UK EHS",
    table_name: "Publication Date",
    type_code: [""],
    name: nil,
    formula: "",
    year: 2023,
    month: nil,
    day: nil,
    # days as a tuple {from, to} eg {10, 23} for days from 10th to 23rd
    days: nil,
    # Where's the data coming from?
    source: :web,
    filter: :si_term,
    # Trigger .csv saving?
    csv?: false,
    # Global mute msg
    mute?: true,
    patch?: nil,
    post?: false,
    filesave?: false,
    json?: false
  }

  def default_opts, do: @default_opts

  @drop_fields DF.drop_fields()

  @api_patch_path ~s[lib/legl/countries/uk/legl_register/new/api_patch_results.json]
  @api_post_path ~s[lib/legl/countries/uk/legl_register/new/api_post_results.json]

  def print_options(%{print_opts?: true} = opts) do
    IO.puts("OPTIONS:
      SOURCE___
      Base Name: #{opts.base_name}
      Table ID: #{opts.table_id}
      Formula: #{opts.formula}
      Fields: #{inspect(opts.fields)}
      View: #{opts.view}
      WORKFLOW___
      workflow: #{opts.workflow}
      update_workflow: #{inspect(opts.update_workflow)}
      post?: #{opts.post?}
      patch?: #{opts.patch?}
      filesave?: #{opts.filesave?}
      ")
    opts
  end

  def print_options(opts), do: opts

  def api_create_update_single_record_options(opts) do
    Enum.into(opts, @default_opts)
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> LRO.type_code()
    |> LRO.year()
    |> LRO.number()
    |> LRO.workflow()
    |> LRO.patch?()
    |> drop_fields()
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_create_update_list_of_records_options(opts) do
    Enum.into(opts, @default_opts)
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> (&Map.put(&1, :names, ExPrompt.string(~s/Names (as csv)/) |> String.split(","))).()
    |> LRO.workflow()
    |> LRO.patch?()
    |> drop_fields()
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_update_single_view_options(opts) do
    IO.puts(
      ~s/_____\nSetting Options from [CRUD.Options.api_update_single_view_options]\n:update_workflow, :name, :view, :patch?, :formula, :fields/
    )

    Enum.into(opts, @default_opts)
    |> LRO.workflow()
    |> LRO.update_workflow()
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> LRO.patch?()
    |> fields()
    |> IO.inspect(label: "LRT OPTIONS: ", limit: :infinity)
  end

  def from_file_set_up(opts) do
    Enum.into(opts, @default_opts)
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> source()
    |> drop_fields()
    |> LRO.workflow()
    |> LRO.create_workflow()
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_create_from_file_bare_wo_title_options(opts) do
    Enum.into(opts, @default_opts)
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> source()
    |> drop_fields()
  end

  def api_update_options(opts) do
    opts = Enum.into(opts, @default_opts)

    IO.puts(
      ~s/______\nSettng Options from __CRUD.Options__\n:workflow, :update_workflow, :drop_fields, :view, :type_class, :type_code, :family, :patch?, :formula, :fields/
    )

    opts =
      opts
      # sets :update_workflow, :drop_fields, :view
      |> LRO.workflow()
      |> LRO.update_workflow()
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.type_class()
      |> LRO.type_code()
      |> LRO.family()
      |> LRO.patch?()
      |> fields()

    formula =
      []
      |> LRO.formula_type_class(opts)
      |> LRO.formula_type_code(opts)
      |> LRO.formula_family(opts)

    Map.put(opts, :formula, ~s/AND(#{Enum.join(formula, ",")})/)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_update_metadata_fields_options(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.type_class()
      |> LRO.type_code()
      |> LRO.view()
      |> Map.put(:fields, ~w[record_id Title_EN type_code Number Year])
      |> drop_fields()

    formula =
      []
      |> LRO.formula_type_class(opts)
      |> LRO.formula_type_code(opts)
      |> LRO.formula_family(opts)
      |> LRO.formula_empty_metadata(opts)

    Map.put(opts, :formula, ~s/AND(#{Enum.join(formula, ",")})/)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_update_extent_fields_options(opts) do
    Enum.into(opts, @default_opts)
    |> LRO.base_name()
    |> LRO.base_table_id()
    |> LRO.view()
    |> Map.put(:formula, LRO.formula_empty_extent())
    |> Map.put(:fields, ~w[record_id Title_EN type_code Number Year])
    |> drop_fields()
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_update_enact_fields_options(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.type_class()
      |> LRO.type_code()
      |> LRO.view("viwuCleywh8PFN9Te")
      |> Map.put(:fields, ~w[record_id Title_EN type_code Number Year])
      |> drop_fields()

    formula =
      []
      |> LRO.formula_type_class(opts)
      |> LRO.formula_type_code(opts)
      |> (&[~s/{Enacted_by}=BLANK()/ | &1]).()

    Map.put(opts, :formula, ~s/AND(#{Enum.join(formula, ",")})/)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_update_amend_fields_options(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.type_class()
      |> LRO.type_code()
      |> LRO.name()
      |> LRO.workflow()
      |> LRO.update_workflow()
      # |> LRO.view()
      |> Map.put(:fields, ~w[record_id Title_EN type_code Number Year])
      |> drop_fields()

    formula =
      []
      |> LRO.formula_type_class(opts)
      |> LRO.formula_type_code(opts)
      |> LRO.formula_family(opts)
      |> LRO.formula_name(opts)
      |> LRO.formula_empty_amend(opts)
      |> Enum.filter(&(&1 != ""))

    Map.put(opts, :formula, ~s/AND(#{Enum.join(formula, ",")})/)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  def api_update_repeal_revoke_fields_options(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.name()
      |> LRO.type_class()
      |> LRO.type_code()
      |> view_live()
      |> LRO.view()
      |> LRO.workflow()
      |> Map.put(:fields, ~w[record_id Title_EN type_code Number Year])
      |> drop_fields()

    formula =
      []
      |> LRO.formula_type_class(opts)
      |> LRO.formula_type_code(opts)
      |> LRO.formula_family(opts)
      |> LRO.formula_name(opts)
      |> LRO.formula_empty_repeal_revoke(opts)
      |> Enum.filter(&(&1 != ""))
      |> IO.inspect()

    Map.put(opts, :formula, ~s/AND(#{Enum.join(formula, ",")})/)
    |> IO.inspect(label: "OPTIONS: ", limit: :infinity)
  end

  @spec legal_register_base_id_table_id(map()) :: map()
  def legal_register_base_id_table_id(opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)

    # {:ok, {_base_id, pub_table_id}} = AtBasesTables.get_base_table_id(opts.base_name, opts.table_name)

    # Map.merge(opts, %{base_id: base_id, table_id: table_id, pub_table_id: pub_table_id})

    Map.merge(opts, %{base_id: base_id, table_id: table_id})
  end

  @fields ~w[
    Name record_id Title_EN type_code type_class Number Year Family
  ]

  # Fields to compare against for Delta
  @md_fields ~w[
    md_description
    md_subjects
    md_modified
    md_total_paras
    md_body_paras
    md_schedule_paras
    md_attachment_paras
    md_images

  ]

  @amend_fields ~w[
    Amended_by
    🔺_stats_affects_count
    🔺_stats_self_affects_count
    🔺_stats_affected_laws_count
    Amending
    🔻_stats_affected_by_count
    🔻_stats_self_affected_by_count
    🔻_stats_affected_by_laws_count
    Revoked_by
    🔻_stats_revoked_by_laws_count
    md_change_log
    amending_change_log
    amended_by_change_log
    Live?_change_log
  ]
  @doc """
  Retrieves the fields based on the provided options.

  ## Parameters

    * `opts` - A map containing the options for retrieving the fields.

  ## Returns

  A map with the `:fields` key updated based on the provided options.
  """
  def fields(opts) do
    fields =
      case opts.workflow |> Atom.to_string() |> String.contains?("Delta") do
        true -> @fields ++ @md_fields ++ @amend_fields
        false -> @fields
      end

    Map.put(opts, :fields, fields)
  end

  @source [
            {:source, "lib/legl/countries/uk/legl_register/crud/api_source.json"},
            {:inc, "lib/legl/countries/uk/legl_register/crud/api_inc.json"},
            {:exc, "lib/legl/countries/uk/legl_register/crud/api_exc.json"},
            {:inc_w_si, "lib/legl/countries/uk/legl_register/crud/api_inc_w_si.json"},
            {:inc_wo_si, "lib/legl/countries/uk/legl_register/crud/api_inc_wo_si.json"},
            {:amend, "lib/legl/countries/uk/legl_register/amend/new_amending_laws_enum0.json"},
            {:amend, "lib/legl/countries/uk/legl_register/amend/new_amended_laws_enum0.json"},
            {:repeal_revoke, "lib/legl/countries/uk/legl_register/amend/api_new_laws.json"},
            {:repeal_revoke,
             "lib/legl/countries/uk/legl_register/repeal_revoke/api_new_laws.json"}
          ]
          |> Enum.with_index()
          |> Enum.into(%{}, fn {k, v} -> {v, k} end)

  @spec source(map()) :: map()
  def source(opts) do
    Map.put(
      opts,
      :source,
      case ExPrompt.choose(
             "Source Records (default new/api_new_laws.json)",
             Enum.map(@source, fn {_, {_, v}} -> v end)
           ) do
        -1 ->
          {:default, "lib/legl/countries/uk/legl_register/crud/api_new_laws.json"}

        n ->
          Map.get(@source, n)
      end
    )
  end

  @spec month(map()) :: map()
  def month(opts) do
    Map.put(
      opts,
      :month,
      ExPrompt.choose("Month", ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"])
      |> (&Kernel.+(&1, 1)).()
    )
  end

  @spec day_groups(map()) :: map()
  def day_groups(opts) do
    Map.put(
      opts,
      :days,
      case ExPrompt.choose("Days", ["1-9", "10-20", "21-30", "21-31", "21-28"]) do
        0 -> {1, 9}
        1 -> {10, 20}
        2 -> {21, 30}
        3 -> {21, 31}
        4 -> {21, 28}
      end
    )
  end

  @spec days(map()) :: map()
  def days(opts) do
    from = ExPrompt.string("from?: ") |> String.to_integer()
    to = ExPrompt.string("to?: ") |> String.to_integer()

    Map.put(
      opts,
      :days,
      {from, to}
    )
  end

  @spec formula(map()) :: map()
  def formula(%{source: :web} = opts) do
    with(
      f = [~s/{Year}="#{opts.year}"/],
      {:ok, f} <- month_formula(opts.month, f),
      f = if(opts.day != nil, do: [~s/{Day}="#{opts.day}"/ | f], else: f),
      f = if({from, to} = opts.days, do: [day_range_formula(from, to) | f], else: f)
    ) do
      Map.put(opts, :formula, ~s/AND(#{Enum.join(f, ",")})/)
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def formula(_), do: {:ok, nil}

  defp day_range_formula(from, to) do
    ~s/OR(#{Enum.map(from..to, fn d ->
      d = if String.length(Integer.to_string(d)) == 1 do
        ~s/0#{d}/
      else
        ~s/#{d}/
      end
      ~s/{Day}="#{d}"/
    end) |> Enum.join(",")})/
  end

  defp month_formula(nil, _), do: {:error, "Month option required e.g. month: 4"}

  defp month_formula(month, f) when is_integer(month) do
    month = if String.length(Integer.to_string(month)) == 1, do: ~s/0#{month}/, else: ~s/#{month}/
    {:ok, [~s/{Month}="#{month}"/ | f]}
  end

  def drop_fields(opts) do
    Map.merge(opts, %{
      drop_fields: @drop_fields,
      api_patch_path: @api_patch_path,
      api_post_path: @api_post_path
    })
  end

  def view_live(%{base_name: "UK S"} = opts) do
    Map.put(
      opts,
      :view,
      "viwwYu7jgUN3x9va7"
    )
  end

  def view_live(%{base_name: "UK EHS"} = opts) do
    Map.put(
      opts,
      :view,
      "viwSdG15vYgfTIjDk"
    )
  end
end
