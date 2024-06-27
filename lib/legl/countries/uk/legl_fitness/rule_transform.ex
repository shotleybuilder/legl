defmodule Legl.Countries.Uk.LeglFitness.RuleTransform do
  @moduledoc """
  Functions to transform rules from legislation.gov.uk to save to the Legal
  Fitness Table (LFT) and Legal Fitness Rule Table (LFRT)
  """
  require Logger
  alias Legl.Countries.Uk.LeglFitness, as: F
  alias Legl.Countries.Uk.LeglFitness.Rule
  alias Legl.Countries.Uk.LeglFitness.RuleProvisions, as: RP
  alias Legl.Countries.Uk.LeglFitness.RuleSeparate

  @doc """
    Transform the records from the legislation.gov.uk API into rules for the
    Legal Fitness Rule Table (LFRT).
  """
  @spec transform_rules(list(map())) :: list(Rule.t())
  def transform_rules(records) do
    heading_map = RP.build_heading_map(records)

    Enum.reduce(records, {[], false}, fn
      %{type: type, text: text}, {rules, _} when type in ["heading", "section"] ->
        case rule_struct_template(text) do
          false ->
            {rules, false}

          %F.Rule{} = rule ->
            {rules, rule}
        end

      %{type: type, text: text} = _record, {rules, rule_struct} = _acc
      when type in ["article", "sub-article", "sub-section"] and rule_struct != false ->
        # IO.inspect(text, label: "text")
        # Disaggregated_rules are all the separated and split rules from the original rule
        disaggregated_rules =
          text
          |> clean_rule_text()
          # |> IO.inspect(label: "clean_rule_text")
          |> (&F.Rule.new(%{rule: &1})).()
          |> RuleSeparate.separate_rules()
          |> clean_rules()
          # |> IO.inspect(label: "disaggregated_rules")
          |> RP.api_get_list_of_article_numbers()
          # |> IO.inspect(label: "fitnesses_children_II")
          |> RP.api_get_provision(heading_map)

        # merge new rule properties with the rule struct template
        disaggregated_rules =
          Enum.map(disaggregated_rules, &Map.replace!(&1, :heading, rule_struct.heading))

        # add new rules to the list of rules aggregator
        {rules ++ disaggregated_rules, rule_struct}

      _, acc ->
        acc
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @spec rule_struct_template(String.t()) :: map() | false
  defp rule_struct_template(text) do
    case Regex.match?(~r/Extension|[Dd]isapplication|Duties [Uu]nder|[Aa]pplication/, text) do
      true ->
        text
        |> transform_heading()
        |> (&F.Rule.new(%{heading: &1})).()

      false ->
        false
    end
  end

  @doc """
    Transform the heading text by ---
      removing extraneous characters and converting to lowercase

    @param heading String.t() The heading text to transform
    @return List.t() The transformed heading text

    Public function because this is used in the RuleProvisions module
  """
  def transform_heading(heading),
    do: heading |> rm_efs() |> String.trim() |> String.downcase()

  defp rm_efs(text) do
    text
    |> (&Regex.replace(~r/\[/, &1, "")).()
    |> (&Regex.replace(~r/\]/, &1, "")).()
    |> (&Regex.replace(~r/F\d+/, &1, "")).()
  end

  def clean_rule_text(text) do
    text
    # rm section / article number
    |> (&Regex.replace(~r/.*?([A-Z].*)/, &1, "\\1")).()
    |> (&Regex.replace(~r/[ ]?📌/m, &1, "\n")).()
    |> (&Regex.replace(~r/F\d+[ ]/, &1, "")).()
    |> (&Regex.replace(~r/(?:\[| ?\] ?)/, &1, "")).()
    # Footnote marks
    |> (&Regex.replace(~r/\(fn\d+\) ?/, &1, "")).()
    # Weird punc marks
    |> (&Regex.replace(~r/–/, &1, "—")).()
    |> (&Regex.replace(~r/’/, &1, "'")).()
    |> String.trim()
  end

  defp clean_rules(fitnesses) when is_list(fitnesses),
    do: Enum.map(fitnesses, &clean_rules/1)

  defp clean_rules(%{rule: rule} = fitness) do
    rule
    |> that_the_to_the()
    |> initial_capitalisation()
    |> end_period()
    |> (&Regex.replace(~r/_but_/, &1, "but")).()
    # |> such_clause()
    |> (&Map.put(fitness, :rule, &1)).()
  end

  defp that_the_to_the(text) do
    text
    |> String.trim()
    |> (&Regex.replace(~r/^that the/, &1, "the")).()
  end

  # Start rule with a capital letter
  defp initial_capitalisation(text) when is_binary(text) do
    text
    |> String.split_at(1)
    |> Tuple.to_list()
    |> then(fn
      [h, t] -> String.upcase(h) <> t
      _ -> text
    end)
  end

  # End rule with a period
  def end_period(fitnesses) when is_list(fitnesses) do
    Enum.map(fitnesses, &end_period(&1))
  end

  def end_period(fitness) when is_map(fitness) do
    Map.update!(fitness, :rule, &end_period/1)
  end

  def end_period(rule) when is_binary(rule) do
    rule
    |> String.trim_trailing(".")
    |> (&(&1 <> ".")).()
  end
end
