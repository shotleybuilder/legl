defmodule Legl.Countries.Uk.LeglRegister.Helpers do
end

defmodule Legl.Countries.Uk.LeglRegister.Helpers.NewLawRecord do
  @moduledoc """
  Module to set the field values for a new law record to be POSTed to the Legal Register Base
  """
  def run(records) do
    with records = setTypeClass(records),
         records = setTags(records),
         records = setExtent(records),
         records = setEnactedBy(records),
         records = setAmendedBy(records),
         records = setRevokedBy(records) do
    end
  end

  @doc """
  Function to set the value of the type_class field
  """
  def setTypeClass(records) do
    Enum.map(
      records,
      fn
        # :type_class is already set
        %{type_class: type_class} = record, acc
        when type_class in [
               "Act",
               "Regulation",
               "Order",
               "Rules",
               "Scheme",
               "Confirmation Statement",
               "Byelaws"
             ] ->
          [record | acc]

        # set :type_class using :Title_EN
        %{Title_EN: title} = record, acc ->
          type_class =
            cond do
              Regex.match?(~r/Act[ ]?$|Act[ ]\(Northern Ireland\)[ ]?$/, title) ->
                "Act"

              Regex.match?(~r/Regulations?[ ]?$|Regulations? \(Northern Ireland\)[ ]?$/, title) ->
                "Regulation"

              Regex.match?(~r/Order[ ]?$|Order[ ]\(Northern Ireland\)[ ]?$/, title) ->
                "Order"

              Regex.match?(~r/Rules?[ ]?$|Rules?[ ]\(Northern Ireland\)[ ]?$/, title) ->
                "Rules"

              Regex.match?(~r/Scheme$|Schem[ ]\(Northern Ireland\)$/, title) ->
                "Scheme"

              Regex.match?(
                ~r/Confirmation[ ]Instrument$|Confirmation Instrument[ ]\(Northern Ireland\)$/,
                title
              ) ->
                "Confirmation Instrument"

              Regex.match?(~r/Byelaws$|Bye-?laws \(Northern Ireland\)$/, title) ->
                "Byelaws"

              true ->
                nil
            end

          # A nil return means we've not been able to parse the :Title_EN field correctly
          case type_class do
            nil ->
              IO.puts(
                "ERROR: :Title_EN field could not be parsed for type_class\ntype_class cannot be set\n#{inspect(record)}"
              )

              [record | acc]

            _ ->
              [Map.put(record, :type_class, type_class) | acc]
          end

        # Pass through the record w/o setting :type_class if :Title_EN absent
        record, acc ->
          IO.puts(
            "ERROR: Record does not have a :Title_EN field\ntype_class cannot be set\n#{inspect(record)}"
          )

          [record | acc]
      end
    )
  end

  def setTags(records) do
  end

  def setExtent(records) do
  end

  def setEnactedBy(records) do
  end

  def setAmendedBy(records) do
  end

  def setRevokedBy(records) do
  end
end

defmodule Legl.Countries.Uk.LeglRegister.Helpers.NewLaw do
  @moduledoc """
  Module to filter a list of laws based on whether they are a record or not a
  record in the Legal Register Base
    Records parameter should have this shape:
    [
      %{
        Name: "UK_uksi_2003_3073_RVRLAR",
        Number: "3073",
        Title_EN: "Road Vehicles (Registration and Licensing) (Amendment) (No. 4) Regulations",
        Year: "2003",
        type_code: "uksi"
      }
    ]
  """
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  @doc """
  Function to filter out laws that are present in the Base.
  Laws that are a record in the the Base are removed from the records.
  To create a list of records suitable for a POST request.
  """
  def filterDelta(records, opts) do
    with {:ok, records} <- setUrl(records, opts),
         records <- filter(:delta, records) do
      {:ok, records}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Function to filter out laws that are NOT present in the Base.
  Laws that are NOT in the Base are removed from the list
  To create a list suitable for a PATCH request
  """
  def filterMatch(records, opts) do
    with {:ok, records} <- setUrl(records, opts),
         records <- filter(:match, records) do
      {:ok, records}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp setUrl(records, opts) do
    records =
      Enum.reduce(records, [], fn
        %{Number: number, Year: year, type_code: type_code} = record, acc ->
          options = [
            formula: ~s/AND({Number}="#{number}", {Year}="#{year}", {type_code}="#{type_code}")/,
            fields: ["Name"]
          ]

          {:ok, url} = Url.url(opts.base_id, opts.table_id, options)
          [Map.put(record, :url, url) | acc]

        record, acc ->
          IO.puts("ERROR: Incomplete record.\nCannot check presence in Base.\n#{inspect(record)}")
          acc
      end)

    case records do
      [] -> {:error, "No record URLs could be set"}
      _ -> {:ok, records}
    end
  end

  defp filter(:delta, records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            Map.drop(record, [:url])
            |> (&[&1 | acc]).()

          _ ->
            acc
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR: #{record[:Title_EN]}\n#{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end

  defp filter(:match, records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            acc

          _ ->
            Map.drop(record, [:url])
            |> (&[&1 | acc]).()
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR #{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end
end
