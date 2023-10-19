defmodule Legl.Countries.Uk.LeglRegister.New.Create do
  @moduledoc """
  Module to set the field values for a new law record to be POSTed to the Legal Register Base
  """
  alias Legl.Services.LegislationGovUk.Url
  alias Legl.Countries.Uk.Metadata, as: MD
  alias Legl.Countries.Uk.LeglRegister.Extent
  alias Legl.Countries.Uk.LeglRegister.Enact.EnactedBy
  alias Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke, as: RR

  def run(records, opts) do
    with records = setTypeClass(records),
         records = setTags(records),
         records = setMetadata(records),
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
        %{type_class: type_class} = record
        when type_class in [
               "Act",
               "Regulation",
               "Order",
               "Rules",
               "Scheme",
               "Confirmation Statement",
               "Byelaws"
             ] ->
          record

        # set :type_class using :Title_EN
        %{Title_EN: title} = record ->
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

              record

            _ ->
              Map.put(record, :type_class, type_class)
          end

        # Pass through the record w/o setting :type_class if :Title_EN absent
        record ->
          IO.puts(
            "ERROR: Record does not have a :Title_EN field\ntype_class cannot be set\n#{inspect(record)}"
          )

          record
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
        |> tags()
        # New :Tags key and save Map into accumulator
        |> (&Map.put(record, :Tags, &1)).()

      # |> (&[&1 | acc]).()

      # Pass through the record w/o setting :type_class if :Title_EN absent
      record ->
        IO.puts(
          "ERROR: Record does not have a :Title_EN field\n:Tags key cannot be set\n#{inspect(record)}"
        )

        record
    end)
  end

  def tags(title) do
    title
    |> String.trim()
    # Emulate the Airtable name_downcase formula field
    |> String.downcase()
    # Removes numbers and non-alphabetic characters
    |> (&Regex.replace(~r/[^a-zA-Z\s:]+/m, &1, "")).()
    # Duped space
    |> (&Regex.replace(~r/[ ]{2,}/, &1, " ")).()

    # REMOVE COMMON WORDS
    # Emulates the Airtable name_split formula field

    # To, the, this, that, these, those ...
    |> (&Regex.replace(~r/[ ]to[ ]|[ ]th[a|e|i|o]t?s?e?[ ]/, &1, " ")).()
    # A, an, and, at, are
    |> (&Regex.replace(
          ~r/^a[ ]|[ ]a[ ]|[ ]an[ ]|[ ]and[ ]|[ ]at[ ]|[ ]are[ ]/,
          &1,
          " "
        )).()
    # For, or
    |> (&Regex.replace(~r/[ ]f?or[ ]/, &1, " ")).()
    # If, in, is, it, its
    |> (&Regex.replace(~r/[ ][I|i][f|n][ ]|[ ][I|i][s|t]s?[ ]/, &1, " ")).()
    # Of, off, on
    |> (&Regex.replace(~r/[ ][O|o][f|n]f?[ ]/, &1, " ")).()
    # No, not
    |> (&Regex.replace(~r/[ ][N|n]ot?[ ]/, &1, " ")).()
    # Be, by
    |> (&Regex.replace(~r/[ ][B|b][e|y][ ]/, &1, " ")).()
    # Who, with
    |> (&Regex.replace(~r/[ ][W|w]i?t?ho?[ ]/, &1, " ")).()
    # Has, have
    |> (&Regex.replace(~r/[H| h]as?v?e?[ ]/, &1, " ")).()
    # Single letter word, a. a,
    |> (&Regex.replace(~r/[ ][A-Z|a-z][ |\.|,]/, &1, " ")).()
    # Depluralise
    |> (&Regex.replace(~r/([abcdefghijklmnopqrtuvwxyz])s[ ]/, &1, "\\g{1} ")).()

    # Duped space
    |> (&Regex.replace(~r/[ ]{2,}/, &1, " ")).()
    # Comma at the start
    |> (&Regex.replace(~r/^,[ ]/, &1, "")).()

    # LIST of WORDS
    |> String.trim()
    |> String.split(" ")
    |> Enum.map(&String.trim(&1))
    |> Enum.map(&String.capitalize(&1))
  end

  @doc """
    Function to set the value of the following fields:
    md_error_code
    md_subjects
    md_description
    md_restrict_start_date
    mc_dct_valid_date
    md_modified
    md_total_paras
    md_body_paras
    md_schedule_paras
    md_attachment_paras
    md_images
    md_change_log
  """
  def setMetadata(records) do
    Enum.map(records, fn record ->
      url = Url.introduction_path(record)
      {:ok, metadata} = MD.get_latest_metadata(url)

      Map.drop(metadata, [:si_code, :pdf_href, :md_modified_csv, :md_subjects_csv, :title])
      |> (&Map.merge(record, &1)).()
    end)
  end

  @doc """
  Function to set the Extent fields: 'Geo_Pan_Region', 'Geo_Region' and 'Geo_Extent'
  in the Legal Register
  """
  def setExtent(records) do
    Enum.map(records, fn
      %{Number: number, type_code: type_code, Year: year} = record
      when is_binary(number) and is_binary(type_code) and is_integer(year) ->
        path = Url.contents_xml_path(record)

        with(
          {:ok, data} <- Extent.get_extent_leg_gov_uk(path),
          {:ok,
           %{
             geo_extent: geo_extent,
             geo_region: geo_region
           }} <- Extent.extent_transformation(data),
          geo_pan_region = geo_pan_region(geo_region)
        ) do
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

  def geo_pan_region(geo_region) do
    regions_list =
      String.split(geo_region, ",")
      |> Enum.map(&String.trim(&1))
      |> Enum.sort()

    cond do
      ["England", "Northern Ireland", "Scotland", "Wales"] == regions_list -> "UK"
      ["England", "Scotland", "Wales"] == regions_list -> "GB"
      ["England", "Wales"] == regions_list -> "E+W"
      ["England", "Scotland"] == regions_list -> "E+S"
      ["England"] == regions_list -> "E"
      ["Wales"] == regions_list -> "W"
      ["Scotland"] == regions_list -> "S"
      ["Northern Ireland"] == regions_list -> "NI"
      true -> ""
    end
  end

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
            {:error, msg, record} ->
              IO.puts("#{msg}")
              [record | acc]

            {:no_text, msg, record} ->
              IO.puts("#{msg}")
              [record | acc]
          end
      end)

    enacting_laws_list = GetEnactedBy.enacting_laws_list(records)

    EnactedBy.workflow_new_laws(enacting_laws_list, opts)

    records
  end

  @doc """
  Function to set the 'Amended_by' field
  """
  def setAmendedBy(records) do
    Enum.map(records, fn record ->
      Amend.amendment_bfs_client(record)
    end)
  end

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
