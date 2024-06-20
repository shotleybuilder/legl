defmodule Legl.Countries.Uk.LeglFitness.RuleProvisions do
  @moduledoc """

  Functions related to transforming the provision_number and provision fields in
  the Legal Fitness Table

  """
  alias Legl.Countries.Uk.LeglFitness.Rule
  alias Legl.Countries.Uk.LeglFitness.RuleTransform, as: RT

  @doc """
  Get the list of article numbers from the rule

  Article numbers are extracted from the rule and returned as a list of strings.
  If no article numbers are found, an empty list is returned.

  ## Examples

      iex> alias Legl.Countries.Uk.LeglFitness.RuleProvisions, as: RP
      iex> RP.get_list_of_article_numbers("Regulation 20 applies")
      ["20"]

      iex> alias Legl.Countries.Uk.LeglFitness.RuleProvisions, as: RP
      iex> RP.get_list_of_article_numbers("Regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to a")
      ["7(1A)", "12", "14", "15", "16", "18", "19", "26(1)"]
  """
  @spec get_list_of_article_numbers(list(Rule.t())) :: list(Rule.t())
  def api_get_list_of_article_numbers(rules) when is_list(rules) do
    Enum.map(rules, fn %{rule: text} = rule ->
      case get_list_of_article_numbers(text) do
        [] ->
          rule

        list ->
          Map.replace!(rule, :provision_number, list)
      end
    end)
  end

  defp get_list_of_article_numbers(rule) do
    case Regex.run(~r/(.*?)(?: do not | shall not | shall | )?appl/, rule,
           capture: :all_but_first
         ) do
      nil ->
        []

      refs ->
        refs
        |> List.first()
        |> expansion()
        |> listing()
        |> case do
          x when is_list(x) -> List.flatten(x)
          x -> [x]
        end
    end
  end

  defp expansion([]), do: []

  defp expansion(rule) when is_binary(rule) do
    case Regex.scan(~r/\d+ to \d+/, rule) do
      [] ->
        rule

      range ->
        Enum.map(range, fn [range] ->
          [h | [t]] =
            range
            |> String.split(" to ")
            |> Enum.map(&String.to_integer/1)

          Range.new(h, t)
          |> Enum.map(&Integer.to_string/1)
        end)
    end
  end

  defp listing([]), do: []

  defp listing(list) when is_list(list), do: list

  defp listing(rule) when is_binary(rule) do
    case Regex.scan(~r/\d+\(?\d*[A-Z]?\)?\(?[a-z]?\)?/, rule) do
      [] ->
        []

      list ->
        List.flatten(list)
        |> Enum.reduce({[], ""}, fn value, {acc, major} ->
          case String.match?(value, ~r/^\d+\)/) do
            false ->
              [major] = Regex.run(~r/^\d+/, value)
              {[value | acc], major}

            true ->
              {[~s/#{major}(#{value}/ | acc], major}
          end
        end)
        |> elem(0)
        |> Enum.reverse()
    end
  end

  def api_get_provision(rules, heading_index) do
    # IO.inspect(rules, label: "rules")

    Enum.map(rules, fn
      %{provision_number: []} = rule ->
        rule

      %{provision_number: _provision_number} = rule ->
        find_provisions(rule, heading_index)

      rule ->
        rule
    end)
  end

  defp find_provisions(%{provision_number: provision_number} = rule, heading_index) do
    Enum.reduce(provision_number, rule, fn number, acc ->
      case Map.get(heading_index, extract_number(number)) do
        nil ->
          acc

        text ->
          Map.replace!(acc, :provision, [text | acc.provision])
      end
    end)
    |> (&Map.replace!(&1, :provision, Enum.uniq(&1.provision) |> Enum.reverse())).()
  end

  @spec extract_number(String.t()) :: String.t()
  defp extract_number(number) do
    case String.split(number, "(") do
      [number] ->
        number

      [number, _] ->
        number
    end
  end

  def build_heading_map(records) do
    Enum.reduce(records, %{}, fn
      %{type: type, text: text, heading: heading}, acc
      when type in ["heading", "section"] ->
        text
        |> transform_heading_text()
        |> (&Map.put(acc, ~s/#{heading}/, &1)).()

      _, acc ->
        acc
    end)
  end

  defp transform_heading_text(text) do
    RT.transform_heading(text)
    |> List.first()
    |> (&Regex.replace(~r/[[:punct:]]/, &1, "")).()
    |> String.replace(" ", "-")
  end
end
