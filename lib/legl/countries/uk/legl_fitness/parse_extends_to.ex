defmodule Legl.Countries.Uk.LeglFitness.ParseExtendsTo do
  @moduledoc """
  Parses the extends_to field in the Legal Fitness Table (LFT)
  """
  alias Legl.Countries.Uk.LeglFitness.Fitness

  @extends_to ~r/^.*?apply(.*?)outside Great Britain.*$/

  def parse_extends_to(text) do
    case Regex.run(@extends_to, text) do
      [_, activity] ->
        %Fitness{
          rule: text,
          category: "extends-to",
          scope: "Whole",
          place: "outside-gb"
        }
        |> make_lft_process(String.trim(activity))

      nil ->
        nil
    end
  end

  defp make_lft_process(fitness, "to and in relation to any activity"),
    do: Map.put(fitness, :process, "activity")

  defp make_lft_process(fitness, "to and in relation to the premises and activities"),
    do: Map.put(fitness, :process, "premises-activity")

  defp make_lft_process(fitness, "to any work"), do: Map.put(fitness, :process, "work")

  defp make_lft_process(fitness, ""), do: fitness

  defp make_lft_process(fitness, _), do: Map.put(fitness, :process, "other")
end
