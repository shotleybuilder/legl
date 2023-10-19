defmodule Legl.Countries.Uk.LeglRegister.Helpers do
end

defmodule Legl.Countries.Uk.LeglRegister.Helpers.Create do
  @moduledoc """
  Module to set the field values for a new law record to be POSTed to the Legal Register Base
  """
  def run(records, opts) do
    with records = setTypeClass(records),
         records = setTags(records),
         records = setExtent(records),
         records = setEnactedBy(records, opts),
         records = setAmendedBy(records),
         setRevokedBy(records, opts) do
    end
  end

  @doc """
  Function to set the value of the type_class field in the Legal Register
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

  @doc """
  Function to set the value of the Tags field in the Legal Register
  """
  def setTags(records) do
    Enum.map(records, fn
      # Accumulate any record with a :Tags key containing a non-empty list
      %{Tags: [_, _]} = record ->
        record

      %{Title_EN: title} = record ->
        title
        |> String.trim()
        # Emulate the Airtable name_downcase formula field
        |> String.downcase()
        # Removes numbers and non-alphabetic characters
        |> (&Regex.replace(~r/[^a-zA-Z\s:]+/m, &1, "")).()

        # REMOVE COMMON WORDS
        # Emulates the Airtable name_split formula field

        # To, the, this, that, these, those ...
        |> (&Regex.replace(~r/[ ][T|t]o[ ]|[ ][T|t]h[a|e|i|o]t?s?e?[ ]/, &1, "")).()
        # A, an, and, at, are
        |> (&Regex.replace(
              ~r/[ ][A|a][ ]|[ ][A|a]n[ ]|[ ][A|a]nd[ ]|[ ][A|a]t[ ]|[ ][A|a]re[ ]/,
              &1,
              ""
            )).()
        # For, or
        |> (&Regex.replace(~r/[ ][F|f]?[O|o]r[ ]/, &1, "")).()
        # If, in, is, it, its
        |> (&Regex.replace(~r/[ ][I|i][f|n][ ]|[ ][I|i][s|t]s?[ ]/, &1, "")).()
        # Of, off, on
        |> (&Regex.replace(~r/[ ][O|o][f|n]f?[ ]/, &1, "")).()
        # No, not
        |> (&Regex.replace(~r/[ ][N|n]ot?[ ]/, &1, "")).()
        # Be, by
        |> (&Regex.replace(~r/[ ][B|b][e|y][ ]/, &1, "")).()
        # Who, with
        |> (&Regex.replace(~r/[ ][W|w]i?t?ho?[ ]/, &1, "")).()
        # Has, have
        |> (&Regex.replace(~r/[H| h]as?v?e?[ ]/, &1, "")).()
        # Single letter word, a. a,
        |> (&Regex.replace(~r/[ ][A-Z|a-z][ |\.|,]/, &1, "")).()
        # Duped space
        |> (&Regex.replace(~r/[ ]{2,}/, &1, "")).()
        # Comma at the start
        |> (&Regex.replace(~r/^,[ ]/, &1, "")).()

        # LIST of WORDS
        |> String.trim()
        |> String.split(",")
        |> Enum.map(&String.trim(&1))
        |> Enum.map(&String.capitalize(&1))

        # New :Tags key and save Map into accumulator
        |> (&Map.puts(record, :Tags, &1)).()

      # |> (&[&1 | acc]).()

      # Pass through the record w/o setting :type_class if :Title_EN absent
      record ->
        IO.puts(
          "ERROR: Record does not have a :Title_EN field\n:Tags key cannot be set\n#{inspect(record)}"
        )

        record
    end)
  end

  alias Legl.Countries.Uk.LeglRegister.Extent

  @doc """
  Function to set the Extent fields: 'Geo_Pan_Region', 'Geo_Region' and 'Geo_Extent'
  in the Legal Register
  """
  def setExtent(records) do
    Enum.map(records, fn
      %{Number: number, type_code: type_code, Year: year} = record
      when is_binary(number) and is_binary(type_code) and is_integer(year) ->
        url =
          cond do
            Regex.match?(~r/\//, number) ->
              ~s(https://www.legislation.gov.uk/#{type_code}/#{number}/contents/data.xml)

            true ->
              ~s(https://www.legislation.gov.uk/#{type_code}/#{year}/#{number}/contents/data.xml)
          end

        with(
          {:ok, data} <- Extent.get_extent_leg_gov_uk(url),
          {:ok,
           %{
             geo_extent: geo_extent,
             geo_region: geo_region
           }} <- Extent.extent_transformation(data)
        ) do
          regions_list =
            String.split(geo_region, ", ") |> Enum.map(&String.trim(&1)) |> Enum.sort()

          geo_pan_region =
            cond do
              ["England", "Northern Ireland", "Scotland", "Wales"] == regions_list -> "UK"
              ["England", "Scotland", "Wales"] == regions_list -> "GB"
              ["England", "Wales"] == regions_list -> "E+W"
              ["England", "Scotland"] -> "E+S"
              ["England"] == regions_list -> "E"
              ["Wales"] == regions_list -> "W"
              ["Scotland"] == regions_list -> "S"
              ["Northern Ireland"] == regions_list -> "NI"
              true -> ""
            end

          Map.merge(record, %{
            Geo_Parent: "United Kingdom",
            Geo_Pan_Region: geo_pan_region,
            Geo_Region: geo_region,
            Geo_Extent: geo_extent
          })
        else
          {:error, msg} ->
            IO.puts("ERROR: #{msg}\nProcessing Extents for:\n#{inspect(record[:Title_EN])}\n")
            record
        end

      # Pass through the record w/o setting Extent if :Number, :type_code, :Year absent
      record ->
        IO.puts(
          "ERROR: Record does not have required fields\n:Extents key cannot be set\n#{inspect(record)}"
        )

        record
    end)
  end

  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy
  alias Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy

  @doc """
  Function to set the 'Enacted_by' field
  """
  def setEnactedBy(records, opts) do
    records =
      Enum.reduce(records, [], fn
        # Acts are not Enacted
        %{type_class: "Act"} = record, acc ->
          [record | acc]

        %{type_code: type_code} = record, acc
        when type_code in ["ukpga", "anaw", "asp", "nia", "apni"] ->
          [record | acc]

        record, acc ->
          with({:ok, record} <- GetEnactedBy.get_enacting_laws(record, opts)) do
            [record | acc]
          else
            {:error, msg, _record} ->
              IO.puts("#{msg}")
              acc

            {:no_text, msg, _record} ->
              IO.puts("#{msg}")
              acc
          end
      end)

    enacting_laws_list = GetEnactedBy.enacting_laws_list(records)

    :ok = EnactedBy.workflow_new_laws(enacting_laws_list, opts)

    records
  end

  alias Legl.Countries.Uk.LeglRegister.Amend

  @doc """
  Function to set the 'Amended_by' field
  """
  def setAmendedBy(records) do
    Enum.map(records, fn record ->
      Amend.amendment_bfs_client(record)
    end)
  end

  alias Legl.Services.LegislationGovUk.Url
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke, as: RR

  @doc """
  Function to set the 'Live?_checked', 'Live?', 'Live?_description', 'Revoked_by' fields of the Legal Register
  """
  def setRevokedBy(records, opts) do
    Enum.map(records, fn
      record ->
        with(
          url = Url.content_path(record),
          {:ok, result, _new_laws} <- RR.getRevocations(url, opts)
        ) do
          result
        else
          :no_records ->
            record

          {:live, result} ->
            result

          :error ->
            record
        end
    end)
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
