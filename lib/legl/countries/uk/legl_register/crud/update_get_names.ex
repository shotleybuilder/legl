defmodule Legl.Countries.Uk.LeglRegister.Crud.UpdateGetNames do
  @moduledoc """
  This module provides functions for updating the ECARM data.

  ## Functions

  - `laws_amended_by_new_laws(opts)`

    This function retrieves legal register records based on the provided options, filters them to get the latest metadata, and saves the records as JSON files.

    ### Parameters

    - `opts` (map): Options for retrieving legal register records.

    ### Example

    ```elixir
    opts = %{country: "uk", category: "legislation"}
    LeglRegister.Crud.UpdateEcarm.laws_amended_by_new_laws(opts)
    ```

    The above example retrieves the latest legal register records for the UK legislation category and saves them as JSON files.

  """
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  alias Legl.Services.Airtable.UkAirtable, as: AT

  @default_opts %{
    base_name: "UK EHS",
    table_id: "table1",
    fields: ["Amending (from UK) - binary", "Revoking (from UK) - binary"],
    formula: ""
  }
  @api_get_law_names_path ~s[lib/legl/countries/uk/legl_register/crud/api_get_law_names.json]

  @doc """
  This function retrieves records from Airtable LRT and saves the unique names
  'name' of the records to a file.

  ## Parameters

  - `opts`: A list of options that can be converted into a map. This is used to
    configure the retrieval of records.

  ## Details

  The function first converts the `opts` list into a map and merges it with the
  default options. It then retrieves the records from the table specified in the
  options.

  The records are processed to extract the names, which are then made unique and
  joined into a comma-separated string. This string is then written to a file
  specified by the `@newly_amended_laws_path` module attribute.

  Finally, the function prints the number of records saved to the console.

  ## Usage
      alias Legl.Countries.Uk.LeglRegister.Crud.UpdateGetNames, as: UGN
      UGN.api_get_law_names([view: "my_view"])

  """
  def api_get_law_names(opts) do
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.base_table_id()

    opts =
      case opts.view do
        nil ->
          LRO.view(opts)

        _ ->
          opts
      end

    records =
      AT.get_records_from_at(opts)
      |> elem(1)
      |> Enum.reduce([], fn record, acc ->
        acc ++ extract_names(record, opts.fields)
      end)
      |> Enum.map(&String.trim/1)
      |> Enum.uniq()

    records
    |> Legl.Utility.save_json(@api_get_law_names_path)

    # |> Enum.join(",")
    # |> (&File.write!(Path.expand(@api_get_law_names_path), &1)).()

    IO.puts("\n#{Enum.count(records)} records saved to #{@api_get_law_names_path}")

    records
  end

  # PRIVATE FUNCTIONS

  defp extract_names(%{"fields" => fields}, name_fields) do
    Enum.reduce(name_fields, [], fn field, acc ->
      case Map.get(fields, field) do
        nil ->
          acc

        value ->
          acc ++ String.split(value, ",")
      end
    end)
  end

  def laws_rescinded_by_new_laws() do
  end
end
