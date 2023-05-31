defmodule Utility.RangeCalc do
  @moduledoc """
  Functions to generate ranges based on start and end range parameters
  eg
  24-26 -> 24, 25, 26
  24-26A -> 24, 25, 26, 26A
  24A-24D -> 24A, 24B, 24C, 24D
  """
  @doc """
  RANGE based on numerical values
  Pattern
    25-28
  """
  def range({first, last}) do
    a = String.to_integer(first)
    b = String.to_integer(last)
    Enum.map(a..b, fn x -> ~s/#{x}/ end)
  end

  def range({prefix, "", last}), do: range({prefix, nil, last})

  def range({prefix, nil, last}) do
    # 25-25D
    a = Legl.Utility.alphabet_to_numeric_map()["A"]
    b = Legl.Utility.alphabet_to_numeric_map()[last]

    Enum.map(a..b, fn x -> ~s/#{prefix}#{<<x::utf8>>}/ end)
    |> (&Kernel.++(&1, [prefix])).()

    # |> (&[prefix | &1]).()
  end

  def range({prefix, first, last}) do
    # 27H-27K
    # 105ZA-105ZI
    a = Legl.Utility.alphabet_to_numeric_map()[first]
    b = Legl.Utility.alphabet_to_numeric_map()[last]

    Enum.map(a..b, fn x -> ~s/#{prefix}#{<<x::utf8>>}/ end)
    |> (&Kernel.++(&1, [prefix])).()

    # |> (&[prefix | &1]).()
  end

  def range({first, "", last, ""}), do: range({first, last})
  def range({first, nil, last, ""}), do: range({first, last})
  def range({first, "", last, nil}), do: range({first, last})
  def range({first, nil, last, nil}), do: range({first, last})

  def range({first, "", last, suffix}), do: range({first, nil, last, suffix})

  def range({first, nil, last, suffix}) do
    # 19-25D
    r1 = range({first, last})
    r2 = range({last, nil, suffix})
    (r1 ++ r2) |> Enum.uniq()
  end

  def range({first, suffix1, last, suffix2}) when first == last do
    # 27H-27K
    range({first, suffix1, suffix2})
  end

  def range({first, suffix1, last, suffix2}) do
    # 24-26A
    # Equivalent to 24A-24Z, 25A-25Z, 26A
    range({first, last})
    |> Enum.map(fn
      x when x == first -> range({x, suffix1, "Z"})
      x when x == last -> range({x, nil, suffix2})
      x -> range({x, nil, "Z"})
    end)
    |> Enum.concat()
  end
end
