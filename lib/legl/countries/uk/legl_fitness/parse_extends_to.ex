defmodule Legl.Countries.Uk.LeglFitness.ParseExtendsTo do
  @moduledoc """
  Parses the extends_to field in the Legal Fitness Table (LFT)
  """
  require Logger
  alias Legl.Countries.Uk.LeglFitness, as: LF

  @spec extension_outside_gb(list(LF.Fitness.t())) :: list(LF.Fitness.t())
  def extension_outside_gb(fitnesses) when is_list(fitnesses) do
    fitnesses =
      Enum.map(fitnesses, &extension_outside_gb/1)

    # Add a fitness record if the law does not extend outside Great Britain
    if Enum.reduce_while(fitnesses, false, fn
         %LF.Fitness{category: "extends-to", place: ["outside-great-britain"]}, _acc ->
           {:halt, true}

         _, acc ->
           {:cont, acc}
       end) == false,
       do: [
         %LF.Fitness{
           fit_id: "does-not-extend-to|outside-gb",
           lfrt: "Does not extend outside GB",
           rule: %LF.Rule{
             rule: "Does not extend outside Great Britain",
             scope: "Whole"
           },
           category: "does-not-extend-to",
           place: ["outside-great-britain"],
           pattern: ["<place>"]
         }
         | fitnesses
       ],
       else: fitnesses
  end

  @spec extension_outside_gb(map()) :: map()
  def extension_outside_gb(%{rule: %{rule: rule, heading: heading}, place: place} = fitness)
      when is_struct(fitness, LF.Fitness) do
    cond do
      Enum.member?(place, "outside-great-britain") -> parse(fitness)
      String.contains?(heading, "extension outside great britain") -> parse(fitness)
      String.contains?(rule, "Great Britain") -> parse(fitness)
      true -> fitness
    end
  end

  def extension_outside_gb(fitness), do: fitness

  defp parse(fitness) do
    case Regex.named_captures(
           ~r/^.*?shall.*?apply(?<activity>.*?)? outside Great Britain.*$/,
           fitness.rule.rule
         ) do
      %{"activity" => activity} ->
        Map.merge(fitness, pattern_process_fields(String.trim(activity)))
        |> Map.put(:rule, Map.put(fitness.rule, :scope, "Whole"))

      nil ->
        Logger.info("No match for extends_to in: #{inspect(fitness.rule, pretty: true)}")
        fitness
    end
  end

  defp pattern_process_fields(""), do: %{pattern: ["<place>"]}

  defp pattern_process_fields("to and in relation to any activity"),
    do: %{
      process: ["activity"],
      pattern: ["<process>", "<place>"],
      category: "extends-to",
      place: ["outside-great-britain"]
    }

  defp pattern_process_fields("to and in relation to the premises and activities"),
    do: %{
      process: ["premises-activity"],
      pattern: ["<process>", "<place>"],
      category: "extends-to",
      place: ["outside-great-britain"]
    }

  defp pattern_process_fields("to any work"),
    do: %{
      process: ["work"],
      pattern: ["<process>", "<place>"],
      category: "extends-to",
      place: ["outside-great-britain"]
    }

  defp pattern_process_fields(_),
    do: %{process: ["other"], pattern: ["<process>", "<place>"]}
end
