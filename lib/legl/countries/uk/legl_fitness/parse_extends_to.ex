defmodule Legl.Countries.Uk.LeglFitness.ParseExtendsTo do
  @moduledoc """
  Parses the extends_to field in the Legal Fitness Table (LFT)
  """
  require Logger
  alias Legl.Countries.Uk.LeglFitness.Fitness

  @extends_to ~r/^.*?apply(.*?) (whether carried on in or)?outside Great Britain.*$/

  # These Regulations shall, subject to regulation 2 above, apply to and in relation to the premises and activities outside Great Britain to which sections 1 to 59 and 80 of the 1974 Act apply by virtue of paragraphs (a), (b), (d) and (e) of article 8 of the Health and Safety at Work etc. Act 1974 (Application Outside Great Britain) Order 1995 (fn3) as they apply within Great Britain but they shall not apply in any case where at the relevant time article 4, 5, 6 or 7 of the said Order applies.

  def parse_extends_to(text) do
    case extends_to(text) do
      {:error, error} -> {:error, error}
      fitness -> Fitness.make_fitness_struct(fitness)
    end
  end

  def extends_to(text) do
    case Regex.run(@extends_to, text) do
      [_, activity] ->
        %{
          "rule" => text,
          "category" => "extends-to",
          "scope" => "Whole",
          "place" => ["outside-gb"]
        }
        |> make_lft_process(String.trim(activity))

      nil ->
        Logger.info("No match for extends_to in: #{text}")
        {:error, "No match for extends_to in: #{text}"}
    end
  end

  def does_not_extend_to() do
    %Fitness{
      rule: "Does not extend outside GB",
      category: "does-not-extend-to",
      scope: "Whole",
      place: ["outside-gb"]
    }
  end

  defp make_lft_process(fitness, "to and in relation to any activity"),
    do: Map.put(fitness, "process", ["activity"])

  defp make_lft_process(fitness, "to and in relation to the premises and activities"),
    do: Map.put(fitness, "process", ["premises-activity"])

  defp make_lft_process(fitness, "to any work"), do: Map.put(fitness, "process", ["work"])

  defp make_lft_process(fitness, ""), do: fitness

  defp make_lft_process(fitness, _), do: Map.put(fitness, "process", ["other"])
end
