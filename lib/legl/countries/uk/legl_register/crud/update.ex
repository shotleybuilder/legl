defmodule Legl.Countries.Uk.LeglRegister.Crud.Update do
  @moduledoc """
  Functions to update field sets in the Legal Register Table
  """

  alias Legl.Services.Airtable.UkAirtable, as: AT

  alias Legl.Countries.Uk.LeglRegister.CRUD.Options
  alias Legl.Countries.Uk.Metadata, as: MD
  alias Legl.Countries.Uk.LeglRegister.Extent
  alias Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke, as: RR

  @type opts() :: keyword()

  @doc """
  Function to patch a record already in the Legal Register table
  Uses the 'Name' index field to retrieve the record from AT
  """
  @spec api_update_single_name(opts()) :: :ok
  def api_update_single_name(opts \\ [csv?: false, mute?: true]) do
    opts =
      opts
      |> Enum.into(%{})
      |> Legl.Countries.Uk.LeglRegister.Options.name()
      |> Options.api_update_single_name_options()

    with([record] <- AT.get_legal_register_records(opts)) do
      opts = Map.put(opts, :family, record."Family")

      update(record, opts)
    else
      record ->
        IO.puts(
          ~s/ERROR: Airtable returned more than one record\n#{Enum.each(record, &IO.puts(&1."Title_EN"))}/
        )

        :ok
    end
  end

  @doc """
  Function UPDATES records from a list of 'Names'
  """
  @spec api_update_list_of_names(opts()) :: :ok
  def api_update_list_of_names(opts \\ [csv?: false, mute?: true]) do
    opts =
      opts
      |> Enum.into(%{})
      |> Options.api_update_list_of_names_options()

    names =
      ExPrompt.string(~s/Names (as csv)/)
      |> String.split(",")

    for name <- names do
      opts =
        opts
        |> (&Map.put(&1, :name, name)).()
        |> Legl.Countries.Uk.LeglRegister.Options.formula_name()

      # IO.puts("Formula: #{opts.formula}")

      with([record] <- AT.get_legal_register_records(opts)) do
        opts = Map.put(opts, :family, record."Family")

        update(record, opts)
      else
        record ->
          IO.puts(
            ~s/ERROR: Airtable returned zero or more than one record\n#{Enum.each(record, &IO.puts(&1."Title_EN"))}/
          )

          :ok
      end
    end
  end

  @spec api_update_single_view(opts()) :: :ok
  def api_update_single_view(opts \\ [csv?: false, mute?: true]) do
    opts =
      opts
      |> Enum.into(%{})
      |> Legl.Countries.Uk.LeglRegister.Options.view()
      |> Options.api_update_single_view_options()

    records = AT.get_legal_register_records(opts)

    # opts = Map.put(opts, :family, record."Family")

    update(records, opts)
  end

  def api_update(opts \\ [])

  def api_update(opts) do
    opts = Options.api_update_options(opts)

    records = AT.get_legal_register_records(opts)

    update(records, opts)
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

  defp patch(record, %{patch?: true} = opts),
    do: Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(record, opts)

  defp patch(_, %{patch?: false}), do: :ok

  defp patch(record, %{patch?: patch} = opts) when patch in [nil, ""] do
    patch? = ExPrompt.confirm("\nPatch #{record."Title_EN"}?")
    patch(record, Map.put(opts, :patch?, patch?))
  end

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
            Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(record, opts)

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
        record = Extent.set_extent(record) |> elem(1)

        case ExPrompt.confirm("\nPatch #{record."Title_EN"}?") do
          true ->
            Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(record, opts)

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
            Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(record, opts)

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
            Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(record, opts)

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
            Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(record, opts)

          false ->
            :ok
        end
      end
    )
  end
end
