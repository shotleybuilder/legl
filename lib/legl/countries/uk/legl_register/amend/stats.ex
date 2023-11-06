defmodule Legl.Countries.Uk.LeglRegister.Amend.Stats do
  @moduledoc """
  Module handles creating stats for laws affecting amendments and laws affected by amendment
  Returns the AmendmentStats struct
  """
  alias Legl.Countries.Uk.LeglRegister.IdField
  alias Legl.Countries.Uk.LeglRegister.Amend
  alias Legl.Countries.Uk.LeglRegister.Amend.Stats.AmendmentStats

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

    # Now we need to work with unique laws
    grouped = Enum.group_by(records, &{&1.path})
    uniq_records = collect_targets_affects_applied(grouped)

    stats =
      Map.merge(
        stats,
        %{
          # The count of uniq laws affected by an affecting law or
          # The count of uniq laws affecting an affected law
          laws: Enum.count(uniq_records),
          # String list of each law and number of changes
          counts: counts(uniq_records),
          counts_detailed: counts_detailed(uniq_records),
          # String list of the Name fields for each law changed
          links: links(uniq_records)
        }
      )

    {:ok, stats, uniq_records}
  end

  @spec count_self_amendments(list()) :: integer()
  defp count_self_amendments(records) do
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

  defp counts(records) do
    Enum.map(records, fn record ->
      ~s[#{record."Name"} - #{record.affect_count}💚️#{record."Title_EN"}💚️https://legislation.gov.uk#{record.path}]
    end)
    |> Enum.sort(:desc)
    |> Enum.join("💚️💚️")
  end

  defp links(records) do
    Enum.map(records, fn record ->
      record."Name"
    end)
    |> Enum.sort_by(
      &{Regex.run(~r/\d{4}/, &1),
       Regex.run(~r/UK_[a-z]*_\d{4}_(.*)_/, &1, capture: :all_but_first)},
      :desc
    )
    |> Enum.join(",")
  end

  defp counts_detailed(records) do
    Enum.map(records, fn record ->
      detail = Enum.join(record.target_affect_applied?, "💚️ ")
      url = ~s[https://legislation.gov.uk#{record.path}]

      ~s[#{record."Name"} - #{record.affect_count}💚️#{record."Title_EN"}💚️#{url}💚️ #{detail}]
    end)
    |> Enum.sort(:desc)
    |> Enum.join("💚️💚️")
  end
end