defmodule Legl.Countries.Uk.LeglRegister.Amend.Stats do
  @moduledoc """
  Module handles creating stats for laws affecting amendments and laws affected by amendment
  Returns the AmendmentStats struct
  """
  alias Legl.Countries.Uk.LeglRegister.IdField
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.Amend.Stats.AmendmentStats
  alias Legl.Countries.Uk.LeglRegister.Amend.Options

  defmodule AmendmentStats do
    @type stats :: %__MODULE__{
            links: String.t(),
            self: integer(),
            laws: integer(),
            amendments: integer(),
            counts: String.t(),
            counts_detailed: String.t()
          }
    defstruct links: "", self: 0, laws: 0, amendments: 0, counts: "", counts_detailed: ""
  end

  @doc """
  Receives a list of Amended or Amending Laws

  Returns the %AmendmentStats{}, and a list of the unique Amended / Amending
  Laws
  """

  @spec amendment_stats([]) :: {:ok, AmendmentStats.stats(), list()}
  def amendment_stats([]), do: {:ok, %AmendmentStats{}, []}

  @spec amendment_stats(list()) :: {:ok, AmendmentStats.stats(), list()}
  def amendment_stats(records) do
    # Total number of amendments made by or made to a law
    stats =
      Map.merge(
        %AmendmentStats{},
        %{
          amendments: Enum.count(records),
          # Total number of self-amendments - made by the law to itself
          self: count_self_amendments(records)
        }
      )

    if stats.amendments > Options.results_count(), do: IO.puts("WARNING: @url record limit")

    # Now we need to work with unique laws
    grouped = Enum.group_by(records, &{&1.path})
    uniq_records = collect_targets_affects_applied(grouped)
    law_count = Enum.count(uniq_records)

    sorted_records = Enum.sort(uniq_records, fn %{Year: x}, %{Year: y} -> x > y end)

    stats =
      Map.merge(
        stats,
        %{
          # String list of the Name fields for each law changed
          links: links(sorted_records),
          # The count of uniq laws affected by an affecting law or
          # The count of uniq laws affecting an affected law
          laws: law_count,
          # String list of each law and number of changes
          counts: counts(law_count, sorted_records),
          counts_detailed: counts_detailed(sorted_records)
        }
      )

    {:ok, stats, uniq_records}
  end

  @spec count_self_amendments(list()) :: integer()
  defp count_self_amendments(records) do
    # path is the amended law (child)
    # pathA is the amending law (parent)
    Enum.reduce(records, 0, fn
      %{path: path, pathA: pathA}, acc ->
        if path == pathA do
          acc + 1
        else
          acc
        end

      %{title: title, Title_EN: amending_title}, acc ->
        if title == amending_title do
          acc + 1
        else
          acc
        end

      _affecting, acc ->
        acc
    end)
  end

  @doc """
  Receives records grouped on title
  Returns unique records on title with changing properties as lists
  """
  def collect_targets_affects_applied(grouped_records) do
    Enum.map(grouped_records, fn {_key, group} ->
      count = Enum.count(group)

      record =
        Enum.reduce(group, %Amend{}, fn
          record, acc when acc."Title_EN" == nil ->
            Map.merge(acc, %{
              Title_EN: record."Title_EN",
              path: record.path,
              type_code: record.type_code,
              Year: record."Year",
              Number: record."Number",
              target: [record.target],
              affect: [record.affect],
              applied?: [record.applied?],
              target_affect_applied?: [
                ~s/#{record.target} #{record.affect} [#{record.applied?}]/
              ]
            })

          record, acc ->
            target = [record.target | acc.target]
            affect = [record.affect | acc.affect]
            applied? = [record.applied? | acc.applied?]

            target_affect_applied? = [
              ~s/#{record.target} #{record.affect} [#{record.applied?}]/
              | acc.target_affect_applied?
            ]

            Map.merge(acc, %{
              target: target,
              affect: affect,
              applied?: applied?,
              target_affect_applied?: target_affect_applied?
            })
        end)

      # IO.puts(
      #  ~s/#{__MODULE__} #{record."Title_EN"} #{record.type_code} #{record."Year"} #{record."Number"}/
      # )

      %{
        record
        | target: Enum.uniq(record.target),
          affect: Enum.uniq(record.affect),
          applied?: Enum.uniq(record.applied?),
          affect_count: count,
          Name: IdField.id(record."Title_EN", record.type_code, record."Year", record."Number")
      }
    end)
    |> List.flatten()

    # |> IO.inspect(label: "uniq")
  end

  defp links(records) do
    Enum.map(records, fn record ->
      record."Name"
    end)
    # |> Enum.sort_by( &{Regex.run(~r/\d{4}/, &1), Regex.run(~r/UK_[a-z]*_\d{4}_(.*)_/, &1, capture: :all_but_first)}, :desc )
    |> Enum.join(",")
  end

  @spec counts(integer(), %Amend{}) :: String.t()
  defp counts(law_count, records) do
    counts =
      Enum.map(records, fn record ->
        ~s[#{record."Name"} - #{record.affect_count}💚️#{record."Title_EN"}💚️https://legislation.gov.uk#{record.path}]
      end)
      # |> Enum.sort_by( &{Regex.run(~r/\d{4}/, &1)}, :desc )
      |> Enum.join("💚️💚️")

    if law_count > 600 do
      optimise_counts(counts)
    else
      counts
    end
  end

  @spec optimise_counts(String.t()) :: String.t()
  defp optimise_counts(record) do
    length = String.length(record)

    cond do
      length > 95_000 ->
        IO.puts("CONDENSING: Counts field is #{length} characters & > 95_000")
        # Condensing involves removing "https://legislation.gov.uk/"

        ~s/Text condensed to meet Airtable cell limit of 100K characters💚️💚️#{record}/
        |> truncate_counts()

      true ->
        record
    end
  end

  defp counts_detailed(records) do
    Enum.map(
      records,
      fn record ->
        detail = Enum.join(record.target_affect_applied?, "💚️ ")
        url = ~s[https://legislation.gov.uk#{record.path}]

        ~s[#{record.affect_count} - #{record."Title_EN"}💚️#{url}💚️ #{detail}]
      end
    )
    # |> Enum.sort_by( &{Regex.run(~r/\d{4}/, &1)}, :desc )
    |> Enum.join("💚️💚️")
    |> optimise_counts_detailed()
  end

  @spec optimise_counts_detailed(String.t()) :: String.t()
  defp optimise_counts_detailed(record) do
    length = String.length(record)
    # Maximum character count for Airtable's long text field is 100,000
    cond do
      length > 50_000 ->
        IO.puts("CONDENSING: Counts - detailed field is #{length} & is > 50_000")

        ~s/Text condensed to meet Airtable cell limit of 100K characters💚️💚️#{record}/
        |> condense_references()
        |> truncate_counts()

      true ->
        record
    end
  end

  @spec condense_references(String.t()) :: String.t()
  defp condense_references(ref) do
    # TODDO https://t.ly/ provides an api to a url shortener $5 pcm
    ref
    |> (&Regex.replace(~r/(s|reg|Sch|Pt)\.[ ](\d)/m, &1, "\\g{1}.\\g{2}")).()
    |> (&Regex.replace(~r/applied in part \(with modifications\)/m, &1, "ap in pt w/ mods")).()
    |> (&Regex.replace(~r/applied in part/m, &1, "ap in pt")).()
    |> (&Regex.replace(~r/applied \(with modifications\)/m, &1, "ap w/ mods")).()
    |> (&Regex.replace(~r/applied/m, &1, "ap")).()
    |> (&Regex.replace(~r/modified/m, &1, "mod")).()
    |> (&Regex.replace(~r/extended/m, &1, "ext")).()
    |> (&Regex.replace(~r/amended/m, &1, "amd")).()
    |> (&Regex.replace(~r/repealed in part/m, &1, "rep in pt")).()
    |> (&Regex.replace(~r/repealed/m, &1, "rep")).()
    |> (&Regex.replace(~r/transfer of functions/m, &1, "trans func")).()
    |> (&Regex.replace(
          ~r/power to apply in part for certain purposes conferred/m,
          &1,
          "pwr to app in pt for certain purp conf"
        )).()
    |> (&Regex.replace(~r/as inserted/m, &1, "as ins")).()
    |> (&Regex.replace(~r/savings for effects/m, &1, "svg fr eff")).()
    |> (&Regex.replace(
          ~r/amendment to earlier affecting provision/m,
          &1,
          "amd to earlier aff prov"
        )).()
    |> (&Regex.replace(~r/\[Yes\]/, &1, "[Y]")).()
    |> (&Regex.replace(~r/[ ]{2,}/, &1, " ")).()
    |> (&Regex.replace(~r/[ ]-[ ]/, &1, "-")).()
  end

  defp truncate_counts(record) do
    length = String.length(record)
    # Step 1.  Switch from full url to path and see if that meets target
    record =
      cond do
        length > 90_000 ->
          IO.puts("URL -> PATH: Counts or Counts - detailed field is #{length} & is > 90_000")
          condense_url(record)

        true ->
          record
      end

    length = String.length(record)

    # Step 2. Truncate the string if it's still too long
    cond do
      length > 90_000 ->
        IO.puts("SLICING: Counts or Counts - detailed field is #{length} & is > 90_000")

        "Text condensed to meet Airtable cell limit of 100K characters💚️💚️" <> record = record

        String.slice(
          "Text condensed to meet Airtable cell limit of 100K characters💚️Text truncated💚️💚️" <>
            record,
          0..90_000
        )

      true ->
        record
    end
  end

  defp condense_url(ref) do
    ref
    |> (&Regex.replace(~r/https:\/\/legislation.gov.uk/m, &1, "")).()
  end
end
