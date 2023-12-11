defmodule Legl.Countries.Uk.LeglRegister.Crud.CreateFromInput do
  @moduledoc """
  Functions to create new record in the Legal Register Table with user input

  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.New.New
  alias Legl.Countries.Uk.LeglRegister.CRUD.Options
  alias Legl.Countries.Uk.LeglRegister.Helpers.Create, as: Helper

  @type opts() :: keyword()
  @type bare_record() :: %{type_code: String.t(), Number: String.t(), Year: Integer}

  @doc """
  Function to create or update the Legal Register record for a SINGLE law.

  Receives :type_code, :Number and :Year

  """
  @spec api_create_update_single_record(opts()) :: :ok
  def api_create_update_single_record(opts \\ [csv?: false, mute?: true]) do
    opts = Options.api_create_update_single_record_options(opts)

    record = %{
      Number: opts.number,
      type_code: opts.type_code,
      Year: String.to_integer(opts.year)
    }

    bare_record(record, opts)
  end

  @doc """
  Receives a bare Legal Register record as a map
  Builds the Legal Register Record and either PATCHes or POSTs to AT
  """
  def bare_record(%{Year: year} = record, opts) when is_binary(year) do
    Map.put(record, :Year, String.to_integer(year)) |> bare_record(opts)
  end

  @spec bare_record(bare_record(), opts()) :: :ok
  def bare_record(%{Year: year} = record, opts)
      when is_integer(year) do
    # Build BARE struct to initiate the process

    record = Kernel.struct(%LegalRegister{}, record)

    case Helper.exists?(record, opts) do
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
        {:ok, %{fields: fields} = record} = Helper.get_lr_record(record, opts)

        patch? =
          if opts.patch? == true,
            do: true,
            else: ExPrompt.confirm("Patch #{fields."Title_EN"}?")

        case patch? do
          true ->
            New.update_empty_law_fields(fields, opts)
            |> (&Map.put(record, :fields, &1)).()
            |> Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(opts)

          false ->
            :ok
        end
    end

    # rescue
    #  e -> IO.puts("ERROR: #{inspect(e)}")
  end
end
