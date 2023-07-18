defmodule Legl.Countries.Uk.UkAirtable do
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records

  @doc """
    Legl.Countries.Uk.UkExtent.get_records_from_at("UK E", true)
  """

  def get_records_from_at(opts) do
    with(
      {:ok, {base_id, table_id}} <-
        AtBasesTables.get_base_table_id(opts.base_name),
      params = %{
        base: base_id,
        table: table_id,
        options: %{
          view: opts.view,
          fields: opts.fields,
          formula: opts.formula
        }
      },
      # IO.inspect(params),
      {:ok, {_, recordset}} <- Records.get_records({[], []}, params)
    ) do
      IO.puts("#{Enum.count(recordset)} Records returned from Airtable")
      {:ok, recordset}
    else
      {:error, error} ->
        IO.inspect(error)
    end
  end

  def enumerate_at_records({file, records}, func) do
    Enum.each(records, fn x ->
      fields = Map.get(x, "fields")
      IO.puts("#{fields["Title_EN"]}")

      with(:ok <- func.(file, fields)) do
        :ok
      end
    end)

    {:ok, "records saved to .csv"}
  end

  def enumerate_at_records(records, opts, func) do
    # IO.inspect(records, limit: :infinity)
    Enum.each(records, fn %{"fields" => fields} = _record ->
      %{"Name" => name, "Title_EN" => title} = fields
      IO.puts("#{title}")
      [_, _, field] = opts.fields_source
      {:ok, path} = Legl.Utility.resource_path(Map.get(fields, field))

      with(:ok <- func.(name, path, opts)) do
        :ok
      else
        {:error, error} ->
          IO.puts("ERROR #{error} with #{fields["Title_EN"]}")

        {:error, :html} ->
          IO.puts(".html from #{fields["Title_EN"]}")
      end
    end)

    {:ok, "metadata properties saved to csv"}
  end
end
