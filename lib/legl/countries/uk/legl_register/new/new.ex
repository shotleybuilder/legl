defmodule Legl.Countries.Uk.LeglRegister.New.New do
  @moduledoc """
  Module to obtain new laws from legislation.gov.uk
  """
  alias Legl.Countries.Uk.LeglRegister.New.New.Options
  alias Legl.Countries.Uk.LeglRegister.New.New.Airtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.New.New.LegUkGov

  alias Legl.Countries.Uk.LeglRegister.New.New.Filters

  alias Legl.Countries.Uk.LeglRegister.Helpers.NewLaw

  alias Legl.Countries.Uk.LeglRegister.New.Create

  @exc_path ~s[lib/legl/countries/uk/legl_register/new/exc.json]
  @inc_wo_si_path ~s[lib/legl/countries/uk/legl_register/new/inc_wo_si.json]
  @inc_w_si_path ~s[lib/legl/countries/uk/legl_register/new/inc_w_si.json]
  @inc_path ~s[lib/legl/countries/uk/legl_register/new/inc.json]

  @doc """
  Function to set the options and route the workflow
  """
  def run(opts) do
    {:ok, opts} = Options.setOptions(opts)
    workflow(opts)
  end

  @doc """
  Function to create a new law record for a Legal Register Base
  """
  def workflow(%{source: :web} = opts) do
    with {:ok, opts} <- Options.setOptions(opts),
         {:ok, records} <- getNewLaws(opts),

         # Filter each Law record based on terms in Title_EN
         {:ok, {inc, exc}} <- Filters.terms_filter(records, opts),

         # Add the SI Code(s) to each Law record
         # Those w/o SI Code go in exc-luded list
         {:ok, {inc_w_si, inc_wo_si}} <- LegUkGov.get_si_code(inc),

         # Split Law records based on presence of an SI Code from our set
         # We end up with 3 sets:
         # 1. inc_w_si -> w/ SI Code and Term match
         # 2. inc_wo_si -> w/ only Term match
         # 3. ex -> neither SI Code or Term match
         {:ok, {inc_w_si, inc_wo_si}} <- Filters.si_code_filter({inc_w_si, inc_wo_si}),

         # Filter out laws that are already in the Base
         {:ok, inc_wo_si} <- NewLaw.filterDelta(inc_wo_si, opts),
         {:ok, inc_w_si} <- NewLaw.filterDelta(inc_w_si, opts),

         # Save the results to 3x .json files for manual QA
         :ok = Legl.Utility.save_json(exc, @exc_path),
         :ok = Legl.Utility.save_json(inc_wo_si, @inc_wo_si_path),
         :ok = Legl.Utility.save_json(inc_w_si, @inc_w_si_path) do
      :ok
    else
      {:none, {_inc, exc}} ->
        IO.puts("Terms filter didn't find any laws\n")
        Legl.Utility.save_json(exc, @exc_path)

      {:error, msg} ->
        IO.puts("#{msg}")
    end
  end

  def workflow(%{source: :both} = opts) do
    %{records: inc_w_si} = @inc_w_si_path |> File.read!() |> Jason.decode!(keys: :atoms)
    %{records: inc_wo_si} = @inc_wo_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    {:ok, _records} =
      Map.merge(inc_w_si, inc_wo_si)
      |> complete_new_law_fields(@inc_path, opts)
  end

  def workflow(%{source: :si_coded} = opts) do
    # Open previously saved records from file
    %{records: records} = @inc_w_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    {:ok, _records} = complete_new_law_fields(records, @inc_path, opts)
  end

  def workflow(%{source: :si_uncoded} = opts) do
    # Open previously saved records from file
    %{records: records} = @inc_wo_si_path |> File.read!() |> Jason.decode!(keys: :atoms)

    {:ok, _records} = complete_new_law_fields(records, @inc_path, opts)
  end

  def complete_new_law_fields(records, path, opts) do
    with(
      # type_class field
      records = Create.setTypeClass(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("TYPE CLASS"),

      # Tags field
      records = Create.setTags(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("TAGS"),

      # Metadata fields
      records = Create.setMetadata(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("METADATA"),

      # Extent fields
      records = Create.setExtent(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("EXTENT"),

      # Enacted by fields
      records = Create.setEnactedBy(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("ENACTED BY"),

      # Amended by fields
      records = Create.setAmendedBy(records),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("AMENDED BY"),

      # Revoked by fields
      records = Create.setRevokedBy(records, opts),
      :ok = Legl.Utility.save_json(records, path),
      IO.puts("REVOKED BY")
    ) do
      {:ok, records}
    end
  end

  def getNewLaws(%{days: {from, to}} = opts) when is_integer(from) and is_integer(to) do
    Enum.reduce(from..to, [], fn day, acc ->
      opts = Map.put(opts, :date, ~s<#{opts.year}-#{opts.month}-#{day}>)

      {:ok, response} = LegUkGov.getLaws(opts)

      Enum.reduce(response, acc, fn law, acc2 ->
        Map.put(law, :"Publication Date", opts.date)
        |> (&[&1 | acc2]).()
      end)
    end)
    |> (&{:ok, &1}).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.Options do
  alias Legl.Services.Airtable.AtBasesTables

  @default_opts %{
    base_name: "UK E",
    table_name: "Publication Date",
    type_code: [""],
    year: 2023,
    month: nil,
    day: nil,
    # days as a tuple {from, to} eg {10, 23} for days from 10th to 23rd
    days: nil,
    # Where's the data coming from?
    source: :web
  }

  def setOptions(opts) do
    opts = Enum.into(opts, @default_opts)
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)

    {:ok, {_base_id, pub_table_id}} =
      AtBasesTables.get_base_table_id(opts.base_name, opts.table_name)

    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id, pub_table_id: pub_table_id})

    with {:ok, f} <- formula(opts) do
      opts = Map.put(opts, :formula, f)
      IO.puts("OPTIONS: #{inspect(opts)}")
      {:ok, opts}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp formula(opts) do
    with(
      f = [~s/{Year}="#{opts.year}"/],
      {:ok, f} <-
        if(opts.month != nil,
          do: {:ok, [~s/{Month}="#{opts.month}"/ | f]},
          else: {:error, "Month option required e.g. month: 04"}
        ),
      f = if(opts.day != nil, do: [~s/{Day}="#{opts.day}"/ | f], else: f),
      f = if({from, to} = opts.days, do: [~s/{Day}>="#{from}", {Day}<="#{to}"/ | f])
    ) do
      {:ok, ~s/AND(#{Enum.join(f, ",")})/}
    else
      {:error, msg} -> {:error, msg}
    end
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.Airtable do
  alias Legl.Services.Airtable.UkAirtable, as: AT

  def getDates(opts) do
    {:ok, records} = AT.get_records_from_at(opts)
    Jason.encode!(records) |> Jason.decode!(keys: :atoms)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.LegUkGov do
  alias Legl.Services.LegislationGovUk.RecordGeneric, as: LegGovUk
  alias(Legl.Countries.Uk.LeglRegister.Metadata.UkSiCode, as: SI)

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.new_law_parser/1

  def getLaws(opts) do
    with(
      url = url(opts),
      {:ok, response} <- LegGovUk.leg_gov_uk_html(url, @client, @parser)
    ) do
      {:ok, response}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def url(opts) do
    f = if opts.type_code != [""], do: [~s</new/#{opts.type_code}/>], else: [~s</new/all/>]

    [opts.date | f]
    |> Enum.reverse()
    |> Enum.join()
  end

  def get_si_code(inc) do
    Enum.reduce(inc, {[], []}, fn
      %{type_code: type_code} = law, {ninc, nexc}
      when type_code not in ["ukpga", "asp", "anaw", "apni"] ->
        with(
          {:ok, url} <-
            SI.resource_path({law.type_code, Integer.to_string(law[:Year]), law[:Number]}),
          {:ok, si_code} <- SI.get_si_code(url)
        ) do
          case si_code do
            x when x in [nil, "", []] ->
              {ninc, [law | nexc]}

            _ ->
              law = Map.put(law, :"SI Code", si_code)
              {[law | ninc], nexc}
          end
        else
          {:none, msg} ->
            IO.puts(msg)
            {ninc, [law | nexc]}
        end

      # Acts do not have SI Codes
      law, {ninc, nexc} ->
        {ninc, [law | nexc]}
    end)
    |> (&{:ok, &1}).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.New.New.Filters do
  # alias Legl.Countries.Uk.UkSearch.Terms
  alias Legl.Countries.Uk.UkSearch.Terms.HealthSafety, as: HS
  alias Legl.Countries.Uk.UkSearch.Terms.Environment, as: E
  alias Legl.Countries.Uk.UkSearch.Terms.SICodes

  @hs_search_terms HS.hs_search_terms()
  @e_search_terms E.e_search_terms()

  def si_code_filter({inc_w_si, inc_wo_si}) do
    Enum.reduce(inc_w_si, {[], inc_wo_si}, fn
      %{si_code: si_codes} = law, {inc, exc} ->
        case si_code_member?(si_codes) do
          true -> {[law | inc], exc}
          _ -> {inc, [law | exc]}
        end

      # Acts and some regs don't have SI Codes
      law, {inc, exc} ->
        {[law | inc], exc}
    end)
    |> (&{:ok, &1}).()
  end

  defp si_code_member?(si_codes) do
    Enum.reduce(si_codes, false, fn si_code ->
      case MapSet.member?(SICodes.si_codes(), si_code) do
        true -> {:halt, true}
        _ -> {:cont, false}
      end
    end)
  end

  def terms_filter(laws, opts) do
    search_terms =
      case opts.base_name do
        "UK S" -> @hs_search_terms
        "UK E" -> @e_search_terms
      end

    results =
      Enum.reduce(laws, {[], []}, fn law, {inc, exc} ->
        title = String.downcase(law[:Title_EN])

        match? =
          Enum.reduce_while(search_terms, false, fn {k, n}, _acc ->
            # n = :binary.compile_pattern(v)

            case String.contains?(title, n) do
              true -> {:halt, {true, k}}
              false -> {:cont, false}
            end
          end)

        case match? do
          {true, k} ->
            Map.put(law, :Family, Atom.to_string(k))
            |> (&{[&1 | inc], exc}).()

          false ->
            {inc, [law | exc]}
        end
      end)

    case results do
      {[], _exc} -> {:none, results}
      _ -> {:ok, results}
    end
  end
end
