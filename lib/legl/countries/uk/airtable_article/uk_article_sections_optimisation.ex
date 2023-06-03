defmodule Legl.Countries.Uk.AirtableArticle.UkArticleSectionsOptimisation do
  @moduledoc """
  Functions to optimise section ranges assigned to F codes Workflow
  1. OPTIMISER Review the list of ef_codes and determine if any can be mapped 1
     to 1 rather than 1 to range and build a keyword with the results
  2. MAPPER Take those results and build the ef_code list with the same shape /
     pattern as the original
  3. REMOVER Drop the optimised ef_codes from the original list of ef_codes
  4. COMBINER Combine the optimised ef_codes with the revised original list
  """
  def optimise_ef_codes(ef_codes) do
    with optimised <- optimiser(ef_codes),
         mapped <- mapper(optimised),
         ef_codes <- remover(ef_codes, mapped) do
      combiner(ef_codes, mapped)
    end
  end

  @doc """
  Function to check if we have an F code with a range of section numbers
  And then if the count of F codes equals the size of the range
  If this is the case we can optimise assuming a 1 to 1 between F code and section number
  """
  def optimiser(ef_codes) when is_list(ef_codes) do
    # Do we have a 1 to 1 mapping between F number and range?
    ef_codes
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.group_by(&elem(&1, 1))
    # |> IO.inspect()
    |> Enum.reduce([], fn {k, v}, acc ->
      # Do we have a range?
      case String.contains?(k, "-") do
        true ->
          [_, from, to] = Regex.run(~r/(\d+)-(\d+)/, k)
          # IO.puts("from #{from} to #{to}")
          rng = String.to_integer(to) - String.to_integer(from) + 1
          # IO.puts("rng #{rng} count #{Enum.count(v)}")
          # Does the size of the range equal the number of F codes?
          case rng == Enum.count(v) do
            true ->
              s_codes =
                Enum.map(String.to_integer(from)..String.to_integer(to), &Integer.to_string(&1))
                |> Enum.reverse()

              efs = Enum.map(v, &elem(&1, 0))
              amd_types = Enum.map(v, &elem(&1, 2))

              [{:"#{k}", {efs, s_codes, amd_types}} | acc]

            false ->
              acc
          end

        false ->
          acc
      end
    end)
    |> IO.inspect(label: "OPTIMISED")
  end

  def mapper(optimised) when is_list(optimised) do
    optimised
    |> Enum.reduce([], fn {_k, {efs, sns, amds}}, acc ->
      Enum.zip([efs, sns, amds]) ++ acc
    end)
    |> Enum.reduce([], fn {ef, sn, amd}, acc ->
      [{:"#{ef}", {ef, sn, amd, ef <> sn}} | acc]
    end)
    |> Enum.reverse()
    |> IO.inspect(label: "MAPPED")
  end

  @doc """
  Remove the mapped F codes from the original list of ef_codes
  """
  def remover(ef_codes, mapped) do
    Enum.map(mapped, fn {k, _v} -> k end)
    |> (&Keyword.drop(ef_codes, &1)).()
    |> IO.inspect(label: "REMOVED")
  end

  @doc """
  Function to combine the optimised ef_codes with the 'new' original list of
  ef_codes. Namely the list with the optimised ef_codes removed
  """
  def combiner(ef_codes, optimised) do
    (ef_codes ++ optimised)
    |> Enum.sort_by(&Atom.to_string(elem(&1, 0)), {:desc, NaturalOrder})
    |> IO.inspect(label: "COMBINED")
  end
end
