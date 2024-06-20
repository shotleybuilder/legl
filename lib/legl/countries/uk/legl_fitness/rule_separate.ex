defmodule Legl.Countries.Uk.LeglFitness.RuleSeparate do
  @moduledoc """
  Functions to separate the rule into its constituent parts
  """

  require Logger
  alias Legl.Countries.Uk.LeglFitness.RuleSplit, as: RS

  def separate_rules(fitnesses) when is_list(fitnesses) do
    Enum.map(fitnesses, &separate_rules/1)
    |> List.flatten()
    |> Enum.uniq()
  end

  def separate_rules(%{provision: _provision, rule: _rule} = fitness) do
    # IO.inspect(fitness, label: "fitness")

    with [fitness] <- such(fitness),
         [_] <- but(fitness),
         [_] <- RS.split(fitness),
         [_] <- save_that(fitness),
         [fitness] <- as_respects_any(fitness),
         [_] <- except(fitness) do
      [fitness]
    else
      fitnesses ->
        # IO.inspect(fitnesses, label: "fitnesses")
        separate_rules(fitnesses)
    end
  end

  def such(%{rule: rule} = fitness) do
    case Regex.match?(~r/(?:apply|extend only) to such/, rule) do
      true ->
        such_clause(rule)
        |> (&Map.put(fitness, :rule, &1)).()
        |> List.wrap()

      false ->
        [fitness]
    end
  end

  @doc """
    Function to rewrites a rule to replace a 'such' clause

    #Example
    "in respect of work equipment shall apply to such equipment" ->
    "in respect of work equipment shall apply to work equipment"
  """
  def such_clause(rule) do
    # Find the abbreviated subjects

    case Regex.named_captures(
           ~r/(?:apply|extend only) to such (?:a )?(?<subject1>.*?) (or (?<subject2>.*?) )?/,
           rule
         ) do
      %{"subject1" => s1, "subject2" => s2} ->
        subject = if s2 != "", do: "#{s1} or #{s2}", else: s1
        regex = ~r/(?:any|in respect of)(.*?#{s1}.*?),? shall (?:apply|extend only)/

        clause =
          Regex.run(regex, rule, capture: :all_but_first)
          |> List.first()
          |> String.trim()

        # Logger.info(~s/\nSUCH CLAUSE\nrule: #{rule}\nsubject: #{subject}\nclause: #{clause}/)

        Regex.replace(
          ~r/such (a )?#{subject}/m,
          rule,
          "\\1#{clause}"
        )

      nil ->
        Logger.error("No 'such' clause found in rule: #{rule}")
        rule
    end
  end

  def but(%{rule: rule} = fitness) do
    case String.contains?(rule, " but ") do
      true ->
        but_clause(fitness)

      false ->
        [fitness]
    end
  end

  defp but_clause(%{rule: rule} = fitness) do
    case everything_before_the_rule(rule) do
      [_, subject, rule] ->
        Enum.map(
          String.split(rule, ~r/,? but /, parts: 2),
          fn text ->
            Map.put(fitness, :rule, subject <> " " <> String.trim(text))
          end
        )

      nil ->
        [fitness]
    end
  end

  defp everything_before_the_rule(rule) do
    Regex.run(
      ~r/(.*?)((?: (?:shall|doe?s?) not| (?:shall|does)|, to the)? (?:extend?t?|apply)[\s\S]*)/,
      rule
    )
  end

  def save_that(%{rule: rule} = fitness) do
    case String.match?(
           rule,
           ~r/(?:save|except) that/
         ) do
      true ->
        save_that_clause(fitness)

      false ->
        [fitness]
    end
  end

  defp save_that_clause(%{rule: rule} = fitness) do
    case Regex.named_captures(
           ~r/(?<provision>.*?) (?:shall|does) not apply to a (?<subject>.*?),? (?:save|except) that/,
           rule,
           capture: :all_names
         ) do
      %{"provision" => provision, "subject" => subject} ->
        such_a_subject =
          Regex.run(~r/apply?i?e?s? to (?:any )?such (?:a )?(.*?)[ \.]/, rule,
            capture: :all_but_first
          )

        [defn] =
          Regex.run(~r/#{such_a_subject} (.*)/, subject, capture: :all_but_first)

        # Surround any 'but' in the definition with underscores to avoid it being processed as a 'but' clause
        defn = Regex.replace(~r/but/, defn, "_but_")

        IO.puts(
          ~s/\nrule: #{rule}\nprovision: #{provision}\nsubject: #{subject}\nsuch_a_subject: #{such_a_subject}\ndefn: #{defn}/
        )

        # Split on the 'save that' term.  The head is the main rule, the tail is the exception
        [h, t] = String.split(rule, ~r/,? (?:save|except) that /, parts: 2)

        # Use of 'it' in the exception rule indicates a provision
        t =
          case Regex.match?(~r/apply to it/, t) do
            true ->
              Regex.replace(~r/it/, t, "#{provision}", global: false)

            false ->
              # Rebuild the exception rule
              Regex.replace(~r/to such a #{such_a_subject}/, t, "to a #{such_a_subject} #{defn}")
          end

        [
          Map.put(fitness, :rule, h),
          Map.put(fitness, :rule, t)
        ]
        |> Enum.map(&initial_capitalisation(&1))

      _ ->
        # Logger.error("No 'save that' clause found in rule: #{rule}")
        [fitness]
    end
  end

  def as_respects_any(%{rule: rule} = fitness) do
    case String.match?(rule, ~r/As respects any .*? to (?:any )?such (?:a )?/) do
      true ->
        as_respects_any_clause(fitness)

      false ->
        [fitness]
    end
  end

  defp as_respects_any_clause(%{rule: rule} = fitness) do
    subject =
      Regex.run(~r/apply?i?e?s? to (?:any )?such (?:a )?(.*?)[ \.]/, rule,
        capture: :all_but_first
      )

    # IO.inspect(subject, label: "subject")

    [defn] =
      Regex.run(~r/As respects any #{subject} (.*?) regulation/, rule, capture: :all_but_first)

    # Surround any 'but' in the definition with underscores to avoid it being processed as a 'but' clause
    defn = Regex.replace(~r/but/, defn, "_but_")

    # IO.inspect(defn, label: "defn")

    [_h, t] = String.split(rule, ~r/regulation/, parts: 2)
    # IO.inspect(t, label: "t")
    t =
      "Regulation" <>
        Regex.replace(~r/to (?:any )?such (?:a )?#{subject}/, t, "to a #{subject} #{defn}")

    # IO.inspect(t, label: "t")

    [
      Map.put(fitness, :rule, t)
    ]
    |> Enum.map(&initial_capitalisation(&1))

    # |> IO.inspect(label: "as_respects_any_clause")
  end

  defp except(%{rule: rule} = fitness) do
    case String.split(rule, ~r/,? except (?:that )?/, parts: 2) do
      [_h] ->
        [fitness]

      [h, t] ->
        [
          Map.put(fitness, :rule, h),
          Map.put(fitness, :rule, t)
        ]

      _ ->
        Logger.error("Multiple 'except' clauses found in rule: #{fitness.rule}")
        [fitness]
    end
  end

  defp initial_capitalisation(%{rule: rule} = fitness) do
    Map.put(fitness, :rule, initial_capitalisation(rule))
  end

  defp initial_capitalisation(text) when is_binary(text) do
    text
    |> String.split_at(1)
    |> Tuple.to_list()
    |> then(fn
      [h, t] -> String.upcase(h) <> t
      _ -> text
    end)
  end

  defp initial_capitalisation(text) do
    String.capitalize(text)
  end
end
