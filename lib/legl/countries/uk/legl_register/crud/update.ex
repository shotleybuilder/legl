defmodule Legl.Countries.Uk.LeglRegister.Crud.Update do
  @moduledoc """
  Functions to update field sets in the Legal Register Table

  The update process works from Airtable as the source of truth.

  The update process is as follows:
  1. Retrieve a 'skeleton' record from Airtable if 'delta' != true
  2. Run the selected workflow to update the record
  3. Optionally run the delta process to map what changed
  4. Map the Airtable record and the Supabase record
  5. Patch the record to the Postgres database
  6. Patch the record in Airtable

  """
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.CRUD.Options
  alias Legl.Countries.Uk.Metadata, as: MD
  alias Legl.Countries.Uk.LeglRegister.Extent
  alias Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke, as: RR
  alias Legl.Countries.Uk.LeglRegister.Crud.UpdateGetNames, as: UGN

  @type opts() :: keyword()

  @doc """
  Updates the list of names for a given record.

  ## Parameters

  - `opts` - A map containing options for the update.

  ## Returns

  The result of enumerating the names with the given options.

  ## Examples

  ```elixir
  opts = %{...}
  api_update_list_of_names(opts)
  ```
  """
  def api_update_list_of_names(opts) do
    IO.puts("Function Name: #{__MODULE__}.api_update_list_of_names")

    opts =
      Enum.into(opts, Options.default_opts())
      |> default_opts()
      # Set the AT formula to retrieve the record
      |> LRO.formula_name()
      # Set the AT fields to be retrieved
      |> Options.fields()

    names =
      ExPrompt.string(~s/Name or List of Names (as csv)/)
      |> String.replace(" ", "")
      |> String.split(",")

    enumerate_the_names(names, opts)
  end

  @doc """
  This function updates a single view in the API.

  ## Parameters

  - `opts`: A list of options that can be converted into a map. This is used to
    configure the update operation.

  ## Details

  The function first converts the `opts` list into a map and merges it with the
  default options. It then sets the formula to retrieve the record and the
  fields to be retrieved, and configures the view and other options for the
  update operation.

  The function then retrieves the names of the laws from the view. These names
  are fields that contain the names, such as 'Name', 'Amending (from UK) -
  binary', and 'Revoking (from UK) - binary'.

  Finally, the function enumerates the names and performs the update operation.

  ## Usage
      alias Legl.Countries.Uk.LeglRegister.Crud.Update
      Update.api_update_single_view([name_fields: ["field name"], view: "my_view"])

  """
  def api_update_single_view(opts) do
    opts =
      Enum.into(opts, Options.default_opts())
      |> default_opts()
      |> LRO.view()
      # Set the AT formula to retrieve the record
      |> LRO.formula_name()
      # Set the AT fields to be retrieved
      |> Options.fields()

    # |> LRO.view()

    # |> Options.api_update_single_view_options()

    # The name fields from the view that contain the names, e.g.
    # 'Name', 'Amending (from UK) - binary', 'Revoking (from UK) - binary'
    names = UGN.api_get_law_names(view: opts.view, fields: fields_picker(opts))

    enumerate_the_names(names, Map.put(opts, :view, ""))
  end

  def api_update(opts \\ [])

  def api_update(opts) do
    opts = Options.api_update_options(opts)

    records = AT.get_legal_register_records(opts)

    update(records, opts)
  end

  # PRIVATE FUNCTIONS

  defp default_opts(opts) do
    opts
    |> Map.put(:base_name, "UK EHS")
    |> LRO.base_table_id()
    # Populates :workflow with the name of the workflow
    |> LRO.workflow()
    # Populates :update_workflow with the functions to be run
    |> LRO.update_workflow()
    # Set the AT view to be retrieved
    |> Map.put_new(:view, "")
    |> Map.put_new(:csv?, false)
    # Switches off print to console
    |> Map.put_new(:mute?, true)
    # Use these options to manually set the update process
    |> Map.put_new(:update_supabase?, true)
    |> Map.put_new(:update_airtable?, true)
  end

  defp fields_picker(name_fields) when is_list(name_fields), do: name_fields

  defp fields_picker(_) do
    # Manual picker when ':name_fields' isn't passed in as an option
    name_fields = [
      ["Name"],
      ["Amending (from UK) - binary"],
      ["Revoking (from UK) - binary"],
      ["Name", "Amending (from UK) - binary"],
      ["Name", "Revoking (from UK) - binary"],
      ["Amending (from UK) - binary", "Revoking (from UK) - binary"],
      ["Name", "Amending (from UK) - binary", "Revoking (from UK) - binary"]
    ]

    picker = Enum.map(name_fields, &Enum.join(&1, ", "))

    chooser =
      Enum.with_index(name_fields)
      |> Enum.reduce(%{}, fn {choice, index}, acc -> Map.put(acc, index, choice) end)

    choice = ExPrompt.choose("Choose the Fields that contain the Names to Update", picker)

    Map.get(chooser, choice)
  end

  defp enumerate_the_names(names, opts) when is_list(names) do
    for name <- names do
      opts =
        opts
        |> (&Map.put(&1, :name, name)).()
        |> Legl.Countries.Uk.LeglRegister.Options.formula_name()
        |> Map.put(:fields, opts.fields ++ ["Last Modified"])

      IO.puts("Fields: #{inspect(opts.fields)}")

      with(
        [record] <- AT.get_legal_register_records(opts),
        opts = Map.put(opts, :family, record."Family"),
        {:ok, record} = update(record, opts)
      ) do
        if opts.mute? == false, do: IO.puts("Record updated: #{inspect(record)}"), else: :ok
      else
        record ->
          IO.puts(
            ~s/ERROR: Airtable returned duplicate records\n#{Enum.each(record, &IO.puts(&1."Title_EN"))}/
          )

          :ok
      end
    end
  end

  defp update(records, opts) when is_list(records) do
    Enum.each(
      records,
      fn record -> update(record, opts) end
    )
  end

  defp update(record, opts) do
    {record, opts} =
      Enum.reduce(opts.update_workflow, {record, opts}, fn f, acc ->
        result =
          case :erlang.fun_info(f)[:arity] do
            1 -> f.(elem(acc, 0))
            2 -> f.(elem(acc, 0), elem(acc, 1))
          end

        case result do
          {:ok, record, opts} -> {record, opts}
          {:ok, record} -> {record, opts}
        end
      end)

    patch(record, opts)
    {:ok, record}
  end

  defp patch(record, %{patch?: true} = opts) do
    # We know the record exists in AT
    # Does the record exists in Supabase / PG?
    exists_pg? =
      Map.put(opts, :select, ~w[id name])
      |> Legl.Countries.Uk.LeglRegister.Crud.Read.exists_pg?()

    case exists_pg? do
      true ->
        # Patch to PG handles mapping field -> column names
        with(:ok <- patch_supabase(record, opts)) do
          Legl.Countries.Uk.LeglRegister.PatchRecord.run(record, opts)
        else
          {:error, error} ->
            IO.puts("ERROR: #{error}\nRECORD NOT UPDATED IN POSTGRES OR AIRTABLE")
        end

      false ->
        IO.puts("\nRECORD #{record."Name"} EXISTS IN AIRTABLE BUT NOT IN POSTGRES")
        Legl.Countries.Uk.LeglRegister.PostRecord.supabase_post_record(record, opts)
    end
  end

  defp patch(_, %{patch?: false}), do: :ok

  defp patch(record, %{patch?: patch} = opts) when patch in [nil, ""] do
    patch? = ExPrompt.confirm("\nPatch #{record."Title_EN"}?")
    patch(record, Map.put(opts, :patch?, patch?))
  end

  defp patch_supabase(record, %{update_supabase?: true} = opts) do
    {:ok, _} = Legl.Countries.Uk.LeglRegister.PatchRecord.supabase_patch_record(record, opts)
    :ok
  end

  defp patch_supabase(_, %{update_supabase?: false}), do: :ok

  @doc """
  Function to update Legal Register meatadata fields
  """
  @spec api_update_metadata_fields(opts()) :: :ok
  def api_update_metadata_fields(opts) do
    opts = Options.api_update_metadata_fields_options(opts)

    records = AT.get_legal_register_records(opts)

    Enum.each(
      records,
      fn record ->
        record = MD.get_latest_metadata(record) |> elem(1)

        patch? = if opts.patch?, do: true, else: ExPrompt.confirm("\nPatch #{record."Title_EN"}?")

        case patch? do
          true ->
            Legl.Countries.Uk.LeglRegister.PatchRecord.run(record, opts)

          false ->
            :ok
        end
      end
    )
  end

  @doc """
  Function to update Legal Register GEO extent fields
  """
  @spec api_update_extent_fields(opts()) :: :ok
  def api_update_extent_fields(opts) do
    opts = Options.api_update_extent_fields_options(opts)

    records = AT.get_legal_register_records(opts)

    Enum.each(
      records,
      fn record ->
        record = Extent.set_extent(record, []) |> elem(1)

        case ExPrompt.confirm("\nPatch #{record."Title_EN"}?") do
          true ->
            Legl.Countries.Uk.LeglRegister.PatchRecord.run(record, opts)

          false ->
            :ok
        end
      end
    )
  end

  def api_update_enact_fields(opts) do
    opts = Options.api_update_enact_fields_options(opts)

    records = AT.get_legal_register_records(opts)

    Enum.each(
      records,
      fn record ->
        record = GetEnactedBy.get_enacting_laws(record, opts) |> elem(1)
        IO.puts("#{record."Title_EN"} Enacted_by: #{record."Enacted_by"}")

        value? = if record."Enacted_by" != "" or nil, do: true, else: false
        patch? = if opts.patch?, do: true, else: ExPrompt.confirm("\nPatch?")

        case patch? and value? do
          true ->
            Legl.Countries.Uk.LeglRegister.PatchRecord.run(record, opts)

          false ->
            :ok
        end
      end
    )
  end

  def api_update_amend_fields(opts) do
    opts = Options.api_update_amend_fields_options(opts)

    records = AT.get_legal_register_records(opts)

    Enum.each(
      records,
      fn record ->
        record = Amend.workflow(record, opts) |> elem(1)
        IO.puts("#{record."Title_EN"}")

        patch? = if opts.patch?, do: true, else: ExPrompt.confirm("\nPatch?")

        case patch? do
          true ->
            Legl.Countries.Uk.LeglRegister.PatchRecord.run(record, opts)

          false ->
            :ok
        end
      end
    )
  end

  def api_update_repeal_revoke_fields(opts) do
    opts = Options.api_update_repeal_revoke_fields_options(opts)

    records = AT.get_legal_register_records(opts)

    Enum.each(
      records,
      fn record ->
        record = RR.workflow(record, opts) |> elem(1)
        IO.puts("#{record."Title_EN"}")

        patch? = if opts.patch?, do: true, else: ExPrompt.confirm("\nPatch?")

        case patch? do
          true ->
            Legl.Countries.Uk.LeglRegister.PatchRecord.run(record, opts)

          false ->
            :ok
        end
      end
    )
  end
end
