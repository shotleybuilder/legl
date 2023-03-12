defmodule Legl.Countries.Uk.UkAirtable do

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records

  @doc """
    Legl.Countries.Uk.UkExtent.get_records_from_at("UK E", true)
  """
  @default_opts %{
    base_name: "UK E",
    filesave?: false,
    fields: ["Name", "Title_EN"],
    view: nil,
    formula: nil
  }

  def get_records_from_at(opts \\ []) do

    opts = Enum.into(opts, @default_opts)

    with(
      {:ok, {base_id, table_id}} <-
        AtBasesTables.get_base_table_id(opts.base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
            view: opts.view,
            fields: opts.fields,
            formula: opts.formula
          }
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      IO.puts("Records returned from Airtable")
      if opts.filesave? == true do
        Legl.Utility.save_at_records_to_file(recordset) end
      if opts.filesave? == false do {:ok, recordset} end
    else
      {:error, error} -> {:error, error}
    end
  end

end
