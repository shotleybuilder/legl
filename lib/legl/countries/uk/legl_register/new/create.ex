defmodule Legl.Countries.Uk.LeglRegister.New.Create do
  @moduledoc """
  Module to set the field values for a new law record to be POSTed to the Legal Register Base
  """
  alias Legl.Services.LegislationGovUk.Url
  alias Legl.Countries.Uk.Metadata, as: MD
  alias Legl.Countries.Uk.LeglRegister.Extent
  alias Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke, as: RR
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR

  def run(records, opts) do
    with records = set_type_class(records),
         records = set_tags(records),
         records = set_metadata(records),
         records = set_extent(records),
         records = set_enacted_by(records, opts),
         records = set_amended_by(records, opts),
         set_revoked_by(records, opts) do
    end
  end

  @spec set_year(list(LR.legal_register())) :: list(LR.legal_register())
  def set_year(records) do
    Enum.map(records, fn
      %_{Year: year} = record ->
        cond do
          is_integer(year) ->
            record

          is_binary(year) ->
            Map.put(record, :Year, String.to_integer(year))
        end
    end)
  end

  @doc """
  Linked record field linking the Legal Register to the Publication Date table
  """
  def setPublicationDateLink(records, opts) do
    Enum.map(records, fn record ->
      Map.get(opts[:record_ids], record[:publication_date])
      |> (&Map.put(record, :"Publication Date", &1)).()
    end)
  end

  @spec set_name(list(LR.legal_register())) :: list(LR.legal_register())
  def set_name(records) do
    Enum.map(records, fn
      %_{Name: nil} = record ->
        Legl.Countries.Uk.LeglRegister.IdField.id(record)
        |> (&Map.put(record, :Name, &1)).()

      record ->
        record
    end)
  end

  @doc """
  Function to set the value of the type_class field in the Legal Register
  """
  @spec set_type_class(list(LR.legal_register())) :: list(LR.legal_register())
  def set_type_class(records) do
    Enum.map(
      records,
      fn
        # :type_class is already set
        %_{type_class: type_class} = record
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
        %_{Title_EN: title} = record when title != nil ->
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
                "\nERROR: :Title_EN field could not be parsed for type_class\ntype_class cannot be set\n#{inspect(record)}"
              )

              record

            _ ->
              Map.put(record, :type_class, type_class)
          end

        # Pass through the record w/o setting :type_class if :Title_EN absent
        record ->
          IO.puts(
            "\nERROR: Record does not have a valid :Title_EN field\ntype_class cannot be set\n#{inspect(record)}"
          )

          record
      end
    )
  end

  @doc """
  Function to set the value of the type field in the Legal Register
  """
  @spec set_type(list(LR.legal_register())) :: list(LR.legal_register())
  def set_type(records) do
    Enum.map(records, fn
      %_{type_code: type_code} = record when type_code != nil ->
        type =
          case type_code do
            "ukpga" ->
              "Public General Act of the United Kingdom Parliament"

            "uksi" ->
              "UK Statutory Instrument"

            # SCOTLAND
            "asp" ->
              "Act of the Scottish Parliament"

            "ssi" ->
              "Scottish Statutory Instrument"

            # NORTHERN IRELAND
            "nisr" ->
              "Northern Ireland Statutory Rule"

            "nisi" ->
              "Northern Ireland Order in Council 1972-date"

            # WALES
            "wsi" ->
              "Wales Statutory Instrument 2018-date"

            "mwa" ->
              "Measure of the National Assembly for Wales 2008-2011"

            _ ->
              nil
          end

        Map.put(record, :Type, type)
    end)
  end

  @doc """
  Function to set the value of the Tags field in the Legal Register
  """
  @spec set_tags(list(LR.legal_register())) :: list(LR.legal_register())
  def set_tags(records) do
    Enum.map(records, fn
      # Accumulate any record with a :Tags key containing a non-empty list
      %_{Tags: [_, _]} = record ->
        record

      %_{Title_EN: title} = record ->
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

  defp tags(title) do
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
    # |> (&Regex.replace(~r/([abcdefghijklmnopqrtuvwxyz])s[ ]/, &1, "\\g{1} ")).()

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
    md_dct_valid_date
    md_modified
    md_total_paras
    md_body_paras
    md_schedule_paras
    md_attachment_paras
    md_images
    md_change_log
    title
  """
  @spec set_metadata(list(LR.legal_register())) :: list(LR.legal_register())
  def set_metadata(records) do
    Enum.map(
      records,
      fn %_{} = record ->
        url = Url.introduction_path(record)
        {:ok, metadata} = MD.get_latest_metadata(url)

        record =
          if metadata.title != record."Title_EN",
            do: Map.put(record, :Title_EN, metadata.title),
            else: record

        metadata =
          Map.drop(metadata, [:si_code, :pdf_href, :md_modified_csv, :md_subjects_csv, :title])

        Kernel.struct(record, metadata)
      end
    )
  end

  @doc """
  Function to set the Extent fields: 'Geo_Pan_Region', 'Geo_Region' and 'Geo_Extent'
  in the Legal Register
  """
  @spec set_extent(list(LR.legal_register())) :: list(LR.legal_register())
  def set_extent(records) do
    Enum.map(records, fn
      %_{Number: number, type_code: type_code, Year: year} = record
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
          Kernel.struct(
            record,
            %{
              Geo_Parent: "United Kingdom",
              Geo_Pan_Region: geo_pan_region,
              Geo_Region: geo_region,
              Geo_Extent: geo_extent
            }
          )

          # |> IO.inspect(label: "EXTENT: ")
        else
          {:no_data, []} ->
            IO.puts("\nNO DATA: No Extent data returned from legislation.gov.uk\n Check manually")
            record

          {:error, msg} ->
            IO.puts("\nERROR: #{msg}\nProcessing Extents for:\n#{inspect(record[:Title_EN])}\n")
            record
        end

      # Pass through the record w/o setting Extent if :Number, :type_code, :Year absent
      record ->
        IO.puts(
          "\nERROR: Record does not have required fields\n:Extents key cannot be set\n#{inspect(record)}"
        )

        record
    end)
  end

  defp geo_pan_region(""), do: ""

  defp geo_pan_region(geo_region) do
    regions_list =
      geo_region
      # String.split(geo_region, ",")
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

  @enacting ~s[lib/legl/countries/uk/legl_register/enact/enacting.json]
  @doc """
  Function to set the 'Enacted_by' field
  """
  @spec set_enacted_by(list(LR.legal_register()), map()) :: list(LR.legal_register())
  def set_enacted_by(records, opts) do
    {:ok, records, enacting_laws} = GetEnactedBy.get_enacting_laws(records, opts)

    # Save the Enacting Laws to file for later processing as NEW LAWs
    :ok = Legl.Utility.save_json(enacting_laws, @enacting)

    # :ok = EnactedBy.post_new_laws(enacting_laws, opts)

    records
    # |> IO.inspect(label: "ENACTED: ")
  end

  @doc """
  Function to set the 'Amended_by' field
  """
  @spec set_amended_by(list(LR.legal_register()), map()) :: list(LR.legal_register())
  def set_amended_by(records, opts) do
    Amend.workflow(records, opts)
    # |> IO.inspect(label: "AMENDED: ")
  end

  @doc """
  Function to set the 'Live?_checked', 'Live?', 'Live?_description', 'Revoked_by' fields of the Legal Register
  """
  @spec set_revoked_by(list(LR.legal_register()), map()) :: list(LR.legal_register())
  def set_revoked_by(records, opts) do
    RR.workflow(records, opts)
    # |> IO.inspect(label: "REVOKED: ")
  end
end
