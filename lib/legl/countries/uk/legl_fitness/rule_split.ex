defmodule Legl.Countries.Uk.LeglFitness.RuleSplit do
  @moduledoc """
  Functions to split a rule into its constituent parts
  """
  require Logger
  alias Legl.Countries.Uk.LeglFitness.RuleTransform, as: RT

  def split(%{provision: _provision, rule: rule} = fitness) do
    case String.split(rule, "—\n", parts: 2) do
      # Single rule not broken by a new line
      [_h] ->
        [fitness]

      # Multiple rules with a leader paragraph
      [h | [t]] ->
        case String.split(t, ~r/[^—]\n\([a-z]\) /) do
          [_rule] ->
            {t, tail_qualifier} =
              case Regex.run(~r/\n([^\(].*)$/, t, capture: :all_but_first) do
                [tail_qualifier] ->
                  t = Regex.replace(~r/\n#{tail_qualifier}/, t, "")
                  {t, tail_qualifier}

                nil ->
                  {t, ""}
              end

            # Secondary rules (i), (ii), (iii) etc.
            case String.split(t, ~r/[^—]\n\([ivx]+\) /) do
              [_rule] ->
                [fitness]

              rules ->
                Enum.map(rules, fn rule ->
                  rule
                  # (a) rule -> rule
                  |> (&Regex.replace(~r/^\([ivx]+\)[ ]/, &1, "")).()
                  # rule; or -> rule. || rule; and -> rule.
                  |> (&Regex.replace(~r/(?:;|,) o$|(?:;|,) an$/, &1, "")).()
                end)

                # Break apart rules with 'unless' clause. Returns a list of rules
                |> unless_()
                |> combine_rules(Map.merge(fitness, %{rule: h}))
                |> tail_qualifier(tail_qualifier)
                |> RT.end_period()
            end

          rules ->
            Enum.map(rules, fn rule ->
              rule
              # (a) rule -> rule
              |> (&Regex.replace(~r/^\([a-z]\)[ ]/, &1, "")).()
              # rule; or -> rule. || rule; and -> rule.
              |> (&Regex.replace(~r/; o$|; an$/, &1, "\.")).()
            end)

            # Break apart rules with 'unless' clause
            |> unless_()
            |> combine_rules(Map.merge(fitness, %{rule: h}))
            |> RT.end_period()
        end
    end
  end

  def unless_(rules) when is_list(rules) do
    Enum.reduce(rules, [], fn text, acc ->
      case String.contains?(text, "unless") do
        true ->
          case Regex.run(~r/(.*?(?:shall|do) not extend to)/, text) do
            [_, rule] ->
              rule_opp =
                case String.contains?(rule, "shall not") do
                  true -> String.replace(rule, "shall not", "shall")
                  false -> String.replace(rule, "do not", "do")
                end

              # Split into LHS the 'rule' and RHS the 'unless' exception to the rule
              [h | [t]] = String.split(text, ~r/,? unless/, parts: 2)

              # Add the rule and the opposite exception to the rule to the accumulator
              [h, rule_opp <> t] ++ acc

            nil ->
              Logger.error("No 'unless' rule clause found in rule: #{text}")
              [text | acc]
          end

        _ ->
          [text | acc]
      end
    end)
  end

  defp combine_rules(rules, fitness) when is_list(rules) do
    # Combine the rules
    # Exceptions mean the leader paragraph is a separate rule
    case String.contains?(fitness.rule, "except") do
      # W/O 'except' the children are appended to the parent rule
      false ->
        template = fitness

        Enum.map(rules, fn rule ->
          Map.put(template, :rule, template.rule <> " " <> rule)
        end)

      # When 'except' we treat all children as distinct rules
      true ->
        # Drop the 'except ... —' from the end of the parent rule
        [main_parent, exception_parent] = String.split(fitness.rule, ~r/,? except /, parts: 2)

        fitness = Map.put(fitness, :rule, main_parent)

        fitness_children =
          Enum.map(rules, &Map.merge(fitness, %{rule: exception_parent <> " " <> &1}))

        [fitness | fitness_children]
    end
  end

  defp tail_qualifier(fitnesses, "") when is_list(fitnesses), do: fitnesses

  defp tail_qualifier(fitnesses, tail_qualifier) when is_list(fitnesses) do
    Enum.map(fitnesses, &tail_qualifier(&1, tail_qualifier))
  end

  defp tail_qualifier(%{rule: rule} = fitness, tail_qualifier) do
    Map.put(fitness, :rule, rule <> " " <> tail_qualifier)
  end
end
