defmodule Legl.Countries.Uk.LeglFitness.FitnessProvisions do
  @moduledoc """

  Functions related to transforming the provision_number and provision fields in
  the Legal Fitness Table

  """
  alias Legl.Countries.Uk.LeglFitness.Fitness, as: F

  @doc """
  Get the list of article numbers from the rule

  Article numbers are extracted from the rule and returned as a list of strings.
  If no article numbers are found, an empty list is returned.

  ## Examples

      iex> FP.get_list_of_article_numbers("Regulation 20 applies")
      ["20"]

      iex> FP.get_list_of_article_numbers("Regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to a")
      ["7(1A)", "12", "14", "15", "16", "18", "19", "26(1)"]
  """
  def api_get_list_of_article_numbers(fitnesses) do
    Enum.map(fitnesses, fn %{rule: rule} = fitness ->
      case get_list_of_article_numbers(rule) do
        [] -> fitness
        list -> Map.put(fitness, :provision_number, list)
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

  def api_get_provision(fitnesses, heading_index) do
    # IO.inspect(fitnesses, label: "fitnesses")

    Enum.map(fitnesses, fn
      %{provision_number: []} = fitness ->
        fitness

      %{provision_number: provision_number} = fitness ->
        Enum.reduce(provision_number, fitness, fn number, acc ->
          number =
            case String.split(number, "(") do
              [number] ->
                number

              [number, _] ->
                number
            end

          case Map.get(heading_index, number) do
            nil ->
              acc

            text ->
              [text | acc.provision]
              |> (&Map.put(acc, :provision, &1)).()
          end
        end)
        |> (&Map.put(&1, :provision, Enum.uniq(&1.provision) |> Enum.reverse())).()

      fitness ->
        fitness
    end)
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
    F.transform_heading(text)
    |> List.first()
    |> (&Regex.replace(~r/[[:punct:]]/, &1, "")).()
    |> String.replace(" ", "-")
  end
end
