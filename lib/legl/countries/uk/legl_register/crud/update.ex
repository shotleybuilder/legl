defmodule Legl.Countries.Uk.LeglRegister.Crud.Update do
  @moduledoc """
  Functions to update field sets in the Legal Register Table
  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister

  alias Legl.Services.Airtable.UkAirtable, as: AT

  alias Legl.Countries.Uk.LeglRegister.CRUD.Options
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
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
    opts = Options.api_update_single_name_options(opts)

    [%LegalRegister{} = record] = AT.get_legal_register_records(opts)

    update(record, opts)
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
    record =
      Enum.reduce(opts.update_workflow, record, fn f, acc ->
        {:ok, record} =
          case :erlang.fun_info(f)[:arity] do
            1 -> f.(acc)
            2 -> f.(acc, opts)
          end

        record
      end)

    patch? = if opts.patch?, do: true, else: ExPrompt.confirm("\nPatch #{record."Title_EN"}?")

    case patch? do
      true ->
        Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(record, opts)

      false ->
        :ok
    end
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
