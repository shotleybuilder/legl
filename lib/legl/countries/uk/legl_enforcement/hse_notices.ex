defmodule Legl.Countries.Uk.LeglEnforcement.HseNotices do
  @moduledoc """
  This module is responsible for fetching and processing HSE notices.
  """
  require Logger
  alias Legl.Countries.Uk.LeglEnforcement.Hse
  alias Legl.Countries.Uk.LeglEnforcement.HseBreaches
  alias Legl.Services.Hse.ClientNotices
  alias Legl.Services.Airtable.Post

  defmodule HSENotice do
    @derive Jason.Encoder
    defstruct [
      :regulator,
      :regulator_function,
      :regulator_regulator_function,
      # regulator_id is the unqiue Notice Number
      :regulator_id,
      :regulator_url,
      # HSE call this 'recipients name'
      # DETAILS OF THE OFFENDER
      :offender_name,
      :offender_index,
      :offender_address,
      :offender_local_authority,
      :offender_country,
      :offender_sic,
      :offender_main_activity,
      :offender_industry,
      :offender_business_type,
      # DETAILS OF THE OFFENCE
      # HSE call this 'notice type'
      :offence_action_type,
      # HSE call this 'issue date' of the notice
      :offence_action_date,
      :offence_compliance_date,
      :offence_revised_compliance_date,
      :offence_description,
      :offence_result,
      :offence_breaches,
      :offence_breaches_clean,
      :offence_lrt
    ]
  end

  @default_opts %{
    filesave?: false,
    country: "England"
  }

  @base "appq5OQW9bTHC1zO5"
  @table "tbl6NZm9bLU2ijivf"

  def api_get_hse_notices(opts) do
    opts = Enum.into(opts, @default_opts)

    pages = Hse.pages_picker()
    # country = country_picker()
    IO.puts("Pages: #{inspect(pages)}")

    case pages do
      %Range{} ->
        Enum.each(pages, fn page ->
          notices =
            get_hse_notices(~s/#{page}/, opts)
            |> HseBreaches.enum_breaches()

          # Enum.each(notices, &post_hse_notice/1)

          Post.post(@base, @table, notices)
        end)

      [] ->
        :ok

      _ ->
        notices =
          get_hse_notices(pages, opts)
          |> HseBreaches.enum_breaches()

        Enum.each(notices, fn notice ->
          Post.post(@base, @table, notice)
        end)
    end
  end

  defp get_hse_notices(page, opts) when is_binary(page) do
    IO.puts("PAGE: #{page}")
    # GET #1 - basic notice details
    notices = ClientNotices.get_hse_notices(page_number: page, country: opts.country)

    notices =
      Enum.map(
        notices,
        &Map.merge(
          %HSENotice{
            regulator: "Health and Safety Executive",
            offender_country: opts.country,
            offender_business_type: Hse.offender_business_type(&1.offender_name),
            offender_index: Hse.offender_index(&1.offender_name)
          },
          &1
        )
      )

    notices =
      Enum.reduce(notices, [], fn
        %HSENotice{regulator_id: regulator_id} = notice, acc when regulator_id != "" ->
          notice
          |> Map.put(
            :regulator_url,
            ~s|https://resources.hse.gov.uk/notices/notices/notice_details.asp?SF=CN&SV=#{regulator_id}|
          )
          |> Map.merge(ClientNotices.get_notice_details(regulator_id))
          |> Map.merge(ClientNotices.get_notice_breaches(regulator_id))
          |> (&[&1 | acc]).()

        _, acc ->
          acc
      end)

    notices =
      Enum.map(
        notices,
        &Map.put(
          &1,
          :regulator_regulator_function,
          regulator_regulator_function(&1.regulator_function)
        )
      )

    if opts.filesave? == true,
      do:
        Legl.Utility.save_json(
          notices,
          Path.expand("lib/legl/countries/uk/legl_enforcement/hse_notices.json")
        )

    notices
  end

  defp regulator_regulator_function(regulator_function) do
    "HSE_" <> regulator_function
  end
end
