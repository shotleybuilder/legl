defmodule Legl.Countries.Uk.LeglEnforcement.HseCases do
  @moduledoc """

  """

  alias Legl.Countries.Uk.LeglEnforcement.Hse
  alias Legl.Countries.Uk.LeglEnforcement.HseBreaches
  alias Legl.Services.Hse.ClientCases
  alias Legl.Services.Airtable.Get
  alias Legl.Services.Airtable.Patch
  alias Legl.Services.Airtable.Post

  defmodule HSECase do
    @derive Jason.Encoder
    defstruct [
      :regulator,
      :regulator_id,
      :regulator_function,
      :regulator_regulator_function,
      :regulator_url,
      # OFFENDER
      :offender_name,
      :offender_local_authority,
      :offender_main_activity,
      :offender_business_type,
      :offender_index,
      :offender_industry,
      # OFFENCE
      :offence_result,
      :offence_fine,
      :offence_costs,
      :offence_action_type,
      :offence_action_date,
      :offence_hearing_date,
      :offence_number,
      :offence_breaches,
      :offence_breaches_clean,
      :offence_lrt,
      :offender_related_cases
      # RECORD
      # :record_id
    ]
  end

  @base "appq5OQW9bTHC1zO5"
  @table "tbl6NZm9bLU2ijivf"

  @default_opts %{
    filesave?: false,
    database: "convictions"
  }

  def api_get_hse_case_by_id(opts \\ []) do
    opts = Enum.into(opts, @default_opts)
    id = ExPrompt.string("Enter HSE Case ID: ")

    Enum.each(String.split(id, ","), fn id ->
      get_hse_cases(%{id: id}, opts)
      |> HseBreaches.enum_breaches()
      |> List.first()
      |> save_hse_case()
    end)
  end

  def api_get_hse_cases(opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    pages = Hse.pages_picker()
    # country = country_picker()
    IO.puts("Pages: #{inspect(pages)}")

    case pages do
      %Range{} ->
        Enum.each(pages, fn page ->
          IO.puts("PAGE: #{page}")

          cases =
            get_hse_cases(%{page: ~s/#{page}/}, opts)
            |> HseBreaches.enum_breaches()

          Post.post(@base, @table, cases)
        end)

      [] ->
        :ok

      page ->
        IO.puts("PAGE: #{page}")

        cases =
          get_hse_cases(%{page: page}, opts)
          |> HseBreaches.enum_breaches()

        Enum.each(cases, fn kase ->
          save_hse_case(kase)
        end)
    end
  end

  defp get_hse_cases(page, opts) do
    cases = ClientCases.get_hse_cases(page, opts)

    cases =
      Enum.map(
        cases,
        &Map.merge(
          %HSECase{
            regulator: "Health and Safety Executive",
            # offender_country: opts.country,
            offender_business_type: Hse.offender_business_type(&1.offender_name),
            offender_index: Hse.offender_index(&1.offender_name),
            offence_action_type: "Court Case"
          },
          &1
        )
      )

    Enum.reduce(cases, [], fn
      %HSECase{regulator_id: regulator_id} = kase, acc when regulator_id != "" ->
        kase
        |> Map.put(
          :regulator_url,
          ~s|https://resources.hse.gov.uk/#{opts.database}/case/case_details.asp?SF=CN&SV=#{regulator_id}|
        )
        |> Map.merge(ClientCases.get_case_details(regulator_id))
        # |> Map.merge(ClientCases.get_case_breaches(regulator_id))
        |> (&[&1 | acc]).()

      _, acc ->
        acc
    end)
  end

  defp save_hse_case(%{regulator_id: regulator_id} = kase) do
    params = %{formula: ~s/{id}="HSE_#{regulator_id}"/, fields: ["id"]}

    case Get.get_id(@base, @table, params) do
      {:ok, nil} ->
        Post.post(@base, @table, kase)

      {:ok, record_id} ->
        kase = Map.put(kase, :record_id, record_id) |> IO.inspect(label: "KASE")
        Patch.patch(@base, @table, kase)
    end
  end
end
