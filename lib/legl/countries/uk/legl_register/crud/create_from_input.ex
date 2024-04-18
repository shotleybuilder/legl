defmodule Legl.Countries.Uk.LeglRegister.Crud.CreateFromInput do
  @moduledoc """
  Functions to create new record in the Legal Register Table with user input

  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.New.New
  alias Legl.Countries.Uk.LeglRegister.CRUD.Options
  alias Legl.Countries.Uk.LeglRegister.Helpers.Create, as: Helper
  alias Legl.Countries.Uk.LeglRegister.Crud.Read

  @type opts() :: keyword()

  @doc """
  Function to create or update the Legal Register record for a SINGLE law.

  Receives :type_code, :Number and :Year

  """
  @spec api_create_update_single_record(opts()) :: :ok
  def api_create_update_single_record(opts \\ [csv?: false, mute?: true]) do
    opts = Options.api_create_update_single_record_options(opts)

    record =
      Kernel.struct(%LegalRegister{}, %{
        Number: opts.number,
        type_code: opts.type_code,
        Year: String.to_integer(opts.year)
      })

    bare_record(record, opts)
  end

  @spec api_create_update_list_of_records(opts()) :: list()
  def api_create_update_list_of_records(opts \\ [csv?: false, mute?: true]) do
    opts = Options.api_create_update_list_of_records_options(opts)

    names = Enum.map(opts.names, &Legl.Utility.split_name(&1))

    for {type_code, year, number} <- names do
      record =
        Kernel.struct(%LegalRegister{}, %{
          Number: number,
          type_code: type_code,
          Year: String.to_integer(year)
        })

      bare_record(record, opts)
    end
  end

  @doc """
  Receives a bare Legal Register record as a map
  Builds the Legal Register Record and either PATCHes or POSTs to AT
  """
  @spec bare_record(%LegalRegister{}, opts()) :: :ok
  def bare_record(%LegalRegister{Year: year} = record, opts) when is_binary(year) do
    Map.put(record, :Year, String.to_integer(year)) |> bare_record(opts)
  end

  def bare_record(%LegalRegister{Year: year} = record, opts)
      when is_integer(year) do
    # Build BARE struct to initiate the process

    # record = Kernel.struct(%LegalRegister{}, record)

    # IO.inspect(record, limit: :infinity, pretty: true)

    case Read.exists_at?(record, opts) do
      false ->
        {:ok, record} = New.update_empty_law_fields(record, opts)

        post? =
          if opts.post? == true, do: true, else: ExPrompt.confirm("Post #{record."Title_EN"}?")

        case post? do
          true ->
            Legl.Countries.Uk.LeglRegister.PostRecord.post_single_record(record, opts)

          false ->
            :ok
        end

      true ->
        {:ok, %{id: id, fields: fields} = _record} = Helper.get_lr_record(record, opts)

        record = Kernel.struct(%LegalRegister{}, fields) |> Map.put(:record_id, id)

        patch? =
          if opts.patch? == true,
            do: true,
            else: ExPrompt.confirm("Patch #{record."Title_EN"}?")

        case patch? do
          true ->
            New.update_empty_law_fields(record, opts)
            |> elem(1)
            |> Legl.Countries.Uk.LeglRegister.PatchRecord.run(opts)

          false ->
            :ok
        end
    end
  rescue
    e ->
      IO.puts("ERROR: #{inspect(e)}")
      :error
  end
end
