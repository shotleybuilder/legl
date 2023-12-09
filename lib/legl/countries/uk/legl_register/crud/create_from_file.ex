defmodule Legl.Countries.Uk.LeglRegister.Crud.CreateFromFile do
  @moduledoc """
  Module to POST or PATCH records to Legal Register Table

  Records are read from file

  Records are not filtered against H&S or E models
  """

  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.New.New
  alias Legl.Countries.Uk.LeglRegister.Helpers.Create, as: Helper
  alias Legl.Countries.Uk.LeglRegister.CRUD.Options
  alias Legl.Countries.Uk.LeglRegister.New.Filters
  alias Legl.Countries.Uk.LeglRegister.PublicationDate
  alias Legl.Countries.Uk.LeglRegister.Year

  @exc_path ~s[lib/legl/countries/uk/legl_register/crud/api_exc.json]
  @inc_wo_si_path ~s[lib/legl/countries/uk/legl_register/crud/api_inc_wo_si.json]
  @inc_w_si_path ~s[lib/legl/countries/uk/legl_register/crud/api_inc_w_si.json]
  @inc_path ~s[lib/legl/countries/uk/legl_register/crud/api_inc.json]

  def api_create_newly_published_laws(opts) do
    opts = Options.from_file_set_up(opts)

    {_, path} = opts.source

    Legl.Utility.read_json_records(path)
    |> Enum.map(&Kernel.struct(%LegalRegister{}, &1))
    |> New.process_newly_published_laws(opts)
  end

  @doc """
  Function to PATCH or POST to Airtable bare new law records These records might
  have the minimal :type_code, :Number, :Year and all other fields need to be
  populated
  """
  def api_create_from_file_bare(opts \\ [csv?: false, mute?: true]) do
    opts = Options.from_file_set_up(opts)

    {_, path} = opts.source

    records = Legl.Utility.read_json_records(path)

    {:ok, {w_si_code, wo_si_code, exc}} =
      Enum.map(records, &Kernel.struct(%LegalRegister{}, &1))
      |> New.categoriser(opts)
      |> elem(1)
      |> New.populate_newly_published_law(opts)

    New.save({w_si_code, wo_si_code, exc}, opts)
  end

  @doc """
  Function to PATCH or POST to Airtable fully formed new law records stored in
  "inc.json"
  Receives list of options
  Returns :ok after successful post
  Run as UK.create_from_file()
  """
  def create_from_file(opts \\ [csv?: false, mute?: true]) do
    opts = Options.from_file_set_up(opts)

    {_, path} = opts.source

    records = Legl.Utility.read_json_records(path)

    case Helper.filter(:both, records, opts) do
      {[], update} ->
        Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(update, opts)

      {new, []} ->
        Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord.run(new, opts)

      {new, update} ->
        Legl.Countries.Uk.LeglRegister.Helpers.PatchRecord.run(update, opts)
        Legl.Countries.Uk.LeglRegister.Helpers.PostNewRecord.run(new, opts)
    end
  end

  @doc """
  Function to PATCH or POST to Airtable bare new law record.

  These records have metadata set
  """
  def api_create_from_file_w_metadata(opts \\ [csv?: false, mute?: true]) do
    opts = Options.from_file_set_up(opts)

    {_, path} = opts.source

    records =
      Legl.Utility.read_json_records(path)
      |> convert_exc_to_list()

    {inc_w_si, inc_wo_si, exc} = filter_w_metadata(records, opts)

    Enum.each(
      [inc_w_si: inc_w_si, inc_wo_si: inc_wo_si],
      fn {k, v} ->
        case ExPrompt.confirm("Process #{k}?") do
          false ->
            :ok

          true ->
            Enum.each(
              v,
              fn
                %{Number: n, Title_EN: t, type_code: tc, Year: y}
                when n in ["", nil] or t in ["", nil] or tc in ["", nil] or y in ["", nil] ->
                  IO.puts(
                    "ERROR:\n Title_EN: #{t}\n Year: #{y}\n Number: #{n}\n Type Code: #{tc}\n"
                  )

                  :ok

                %{Number: n, Title_EN: t, type_code: tc, Year: y} = record ->
                  IO.puts("Title_EN: #{t} Year: #{y} Number: #{n} Type Code: #{tc}")

                  case Legl.Countries.Uk.LeglRegister.Helpers.Create.exists?(record, opts) do
                    false ->
                      {:ok, record} =
                        New.update_empty_law_fields_w_metadata(
                          Kernel.struct(%LegalRegister{}, record),
                          opts
                        )

                      case ExPrompt.confirm(
                             "SAVE to BASE?: #{record."Title_EN"} #{record.si_code}"
                           ) do
                        true -> New.save([record], opts)
                        _ -> nil
                      end

                    true ->
                      :ok
                  end
              end
            )
        end
      end
    )

    case ExPrompt.confirm("Process exc?") do
      false ->
        :ok

      true ->
        New.save_exc(exc, opts)
    end
  end

  defp convert_exc_to_list(records) when is_map(records) do
    Enum.map(records, fn {_k, v} -> v end)
  end

  defp convert_exc_to_list(records) when is_list(records), do: records

  defp filter_w_metadata(records, opts) when is_list(records) do
    with {:ok, {inc, exc}} <- Filters.terms_filter(records, opts.base_name),
         :ok = Legl.Utility.save_structs_as_json(inc, @inc_path),
         :ok =
           Legl.Utility.maps_from_structs(exc)
           |> New.index_exc()
           |> Legl.Utility.save_json(@exc_path),
         {inc_w_si, inc_wo_si} <- si_code_sorter(inc),
         {:ok, {inc_w_si, inc_wo_si}} <-
           Filters.si_code_filter({inc_w_si, inc_wo_si}, opts.base_name) do
      #
      IO.puts("# W/O SI CODE RECORDS: #{Enum.count(inc_wo_si)}")

      Legl.Utility.save_json(inc_wo_si, @inc_wo_si_path)

      IO.puts("# W/ SI CODE RECORDS: #{Enum.count(inc_w_si)}")

      Legl.Utility.save_json(inc_w_si, @inc_w_si_path)

      {inc_w_si, inc_wo_si, exc}
    end
  end

  @spec si_code_sorter(list()) :: tuple()
  def si_code_sorter(records) do
    Enum.reduce(records, {[], []}, fn
      %{si_code: sic} = record, acc when sic in ["", nil] ->
        {elem(acc, 0), [record | elem(acc, 1)]}

      record, acc ->
        {[record | elem(acc, 0)], elem(acc, 1)}
    end)
  end

  def api_create_newly_published_laws(opts) do
    opts = Options.from_file_set_up(opts)

    {_, path} = opts.source

    records = Legl.Utility.read_json_records(path)

    Enum.map(records, fn record ->
      with(
        # Year field
        {:ok, record} <- Year.set_year(record),
        # Publication Date field
        {:ok, record} <-
          PublicationDate.set_publication_date_link(
            record,
            opts
          ),
        # All the other fields
        {:ok, record} = New.update_empty_law_fields(record, opts)
      ) do
        record
      end
    end)
    |> New.save(opts)
  end
end
