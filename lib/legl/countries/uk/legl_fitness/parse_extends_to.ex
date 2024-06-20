defmodule Legl.Countries.Uk.LeglFitness.ParseExtendsTo do
  @moduledoc """
  Parses the extends_to field in the Legal Fitness Table (LFT)
  """
  require Logger
  alias Legl.Countries.Uk.LeglFitness

  @exclusions ~r/whether carried on in or outside Great Britain/

  @spec parse_extends_to(map()) :: map()
  def parse_extends_to(%{place: place} = fitness) when place in ["Great Britain"] do
    case Regex.match?(@exclusions, fitness.rule.rule) do
      true ->
        fitness

      false ->
        parse(fitness)
    end
  end

  def parse_extends_to(fitness), do: fitness

  defp parse(fitness) do
    case Regex.named_captures(
           ~r/^.*?apply(?<activity>.*?)? outside Great Britain.*$/,
           fitness.rule.rule
         ) do
      %{"activity" => activity} ->
        rule = Map.replace!(fitness.rule, :scope, "Whole")

        %{
          category: "extends-to",
          place: ["outside-great-britain"],
          rule: rule
        }
        |> Map.merge(make_lft_process(String.trim(activity)))
        |> (&Map.merge(fitness, &1)).()

      nil ->
        Logger.info("No match for extends_to in: #{fitness.rule}")
        fitness
    end
  end

  def does_not_extend_to() do
    %LeglFitness.Fitness{
      fit_id: "does-not-extend-to|outside-gb",
      lfrt: "Does not extend outside GB",
      rule: %LeglFitness.Rule{
        rule: "Does not extend outside Great Britain",
        scope: "Whole"
      },
      category: "does-not-extend-to",
      place: ["outside-great-britain"],
      pattern: ["<place>"]
    }
  end

  defp make_lft_process(""), do: %{pattern: ["<place>"]}

  defp make_lft_process("to and in relation to any activity"),
    do: %{process: ["activity"], pattern: ["<process>", "<place>"]}

  defp make_lft_process("to and in relation to the premises and activities"),
    do: %{
      process: ["premises-activity"],
      pattern: ["<process>", "<place>"]
    }

  defp make_lft_process("to any work"),
    do: %{process: ["work"], pattern: ["<process>", "<place>"]}

  defp make_lft_process(_),
    do: %{process: ["other"], pattern: ["<process>", "<place>"]}
end
