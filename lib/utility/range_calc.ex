defmodule Utility.RangeCalc do
  @moduledoc """
  Functions to generate ranges based on start and end range parameters
  eg
  24-26 -> 24, 25, 26
  24-26A -> 24, 25, 26, 26A
  24A-24D -> 24A, 24B, 24C, 24D
  78A-78YC
  """
  def range(range) when is_binary(range) do
    case String.contains?(range, "-") do
      true ->
        String.split(range, "-")
        |> range()

      false ->
        {:error, range, "no range provided"}
    end
  end

  def range([first, last] = range) when is_binary(first) and is_binary(last) do
    Enum.reduce(range, [], fn x, acc ->
      case Regex.run(~r/(\d+)([A-Z]?)([A-Z]?)/, x) do
        [_, n, "", ""] -> [[n, "", ""] | acc]
        [_, n, suffix1, ""] -> [[n, suffix1, ""] | acc]
        [_, n, suffix1, suffix2] -> [[n, suffix1, suffix2] | acc]
      end
    end)
    |> Enum.reverse()
    |> List.flatten()
    |> range()
  end

  def range([n1, "", "", n2, "", ""]) do
    # 1-5 -> ["1", "2", "3", "4", "5"]
    n1 = String.to_integer(n1)
    n2 = String.to_integer(n2)
    Enum.map(n1..n2, fn x -> ~s/#{x}/ end)
  end

  def range([n1, "", "", n1, s2a, ""]) do
    # 1-1C -> [1A, 1B, 1C, 1]
    s1a = Legl.Utility.alphabet_to_numeric_map()["A"]
    s2a = Legl.Utility.alphabet_to_numeric_map()[s2a]

    Enum.map(s1a..s2a, fn x -> ~s/#{n1}#{<<x::utf8>>}/ end)
    |> (&Kernel.++(&1, [n1])).()
  end

  def range([n1, "", "", n2, s2a, ""]) do
    # 19-21D
    # r1 is ["19", "20", "21"]
    r1 = range([n1, "", "", n2, "", ""])
    # r2 is ["21A", "21B", "21C", "21D"]
    r2 = [n2, "A", "", n2, s2a, ""]
    (r1 ++ r2) |> Enum.uniq()
  end

  def range([n1, s1a, "", n1, s2a, ""]) do
    # 27H-27K
    s1a = Legl.Utility.alphabet_to_numeric_map()[s1a]
    s2a = Legl.Utility.alphabet_to_numeric_map()[s2a]

    Enum.map(s1a..s2a, fn x -> ~s/#{n1}#{<<x::utf8>>}/ end)
    |> (&Kernel.++(&1, [n1])).()
  end

  def range([n1, s1a, "", n2, s2a, ""]) do
    # 2C-3B -> ["2C", "2D" ... "3A", "3B", "3C"]
    r1 = range([n1, s1a, "", n1, "Z", ""]) |> (&Kernel.++(&1, [n1])).()
    r2 = range([n2, "A", "", n2, s2a, ""]) |> (&Kernel.++(&1, [n2])).()
    (r1 ++ r2) |> Enum.uniq()
  end

  def range([n1, s1a, "", n1, s2a, s2b]) do
    # 78A-78YC
    r1 = range([n1, s1a, "", n1, s2a, ""]) |> (&Kernel.++(&1, [n1])).()
    r2 = range([n1, s1a, "A", n1, s1a, s2b])
    (r1 ++ r2) |> Enum.uniq()
  end

  def range([n1, s1a, s1b, n1, s1a, s2b]) do
    # 105ZA-105ZI
    s1b = Legl.Utility.alphabet_to_numeric_map()[s1b]
    s2b = Legl.Utility.alphabet_to_numeric_map()[s2b]

    Enum.map(s1b..s2b, fn x -> ~s/#{n1}#{s1a}#{<<x::utf8>>}/ end)
    |> (&Kernel.++(&1, ["#{n1}#{s1a}"])).()
  end

  # def range([n1, s1a, s1b, n2, s2a, s2b]) do
  # end
end
