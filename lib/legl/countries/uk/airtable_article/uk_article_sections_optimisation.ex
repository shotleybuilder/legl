defmodule Legl.Countries.Uk.AirtableArticle.UkEfCodes do
  alias Legl.Countries.Uk.AirtableArticle.UkArticleQa, as: QA

  def ef_codes(binary, regex, label) do
    QA.scan_and_print(binary, regex, label, true)

    Regex.scan(~r/#{regex}/m, binary)
    |> Enum.reduce([], fn scan_list, acc ->
      # regex return different sized lists
      ef_codes = ef_code_tuple(scan_list)

      case ef_codes do
        [t1, t2] -> [t1, t2 | acc]
        [t] -> [t | acc]
      end
    end)
    |> Enum.uniq()
    |> IO.inspect(label: "#{label} PRE-PROCESSED")
  end

  def ef_code_tuple([match, ef_code, s_code]) do
    ef_code_tuple([match, ef_code, s_code, ""])
  end

  def ef_code_tuple([_, ef_code, s_code, amd_type]) do
    s_code =
      s_code
      |> (&Regex.replace(~r/ and cross[- ]heading/m, &1, "")).()
      |> (&Regex.replace(~r/[ ]/m, &1, "")).()

    # "31,32and34-42"
    case Regex.match?(~r/and/, s_code) do
      true ->
        [_, a, b] = Regex.run(~r/(.*)and(.*)/, s_code)

        [
          {:"#{ef_code}", {ef_code, a, amd_type}},
          {:"#{ef_code}", {ef_code, b, amd_type}}
        ]

      false ->
        [{:"#{ef_code}", {ef_code, s_code, amd_type}}]
    end
  end

  def ef_tags(ef_codes) do
    Enum.reduce(ef_codes, [], fn
      {_, nil, _}, acc ->
        acc

      {_k, {ef_code, s_code, amd_type}}, acc ->
        cond do
          String.contains?(s_code, ",") ->
            accum =
              String.split(s_code, ",")
              |> Enum.reduce([], fn sn, accum ->
                [{ef_code, sn, amd_type, ef_code <> sn} | accum]
              end)

            accum ++ acc

          String.contains?(s_code, "-") ->
            cond do
              # RANGE with this pattern 87-87C
              # RANGE with this pattern 32-35
              # RANGE with this pattern 27H-27K
              Regex.match?(~r/\d+[A-Z]?-\d+[A-Z]?/, s_code) ->
                # IO.puts("cond do #1 #{match}")
                [_, a, b, c, d] = Regex.run(~r/(\d+)([A-Z]?)-(\d+)([A-Z]?)/, s_code)

                range =
                  case a == c do
                    true ->
                      Utility.RangeCalc.range({a, b, d})

                    false ->
                      b =
                        if b == "" do
                          "A"
                        else
                          b
                        end

                      Utility.RangeCalc.range({a, b, c, d})
                  end

                accum =
                  Enum.reduce(range, [], fn x, accum ->
                    [{ef_code, x, amd_type, ef_code <> x} | accum]
                  end)
                  |> Enum.reverse()

                accum ++ acc

              # RANGE with this pattern 105ZA-105ZI
              Regex.match?(~r/\d+[A-Z][A-Z]-\d+[A-Z][A-Z]/, s_code) ->
                # IO.puts("cond do #3 #{match}")
                [_, num, a, b] = Regex.run(~r/(\d+[A-Z])([A-Z])-\d+[A-Z]([A-Z])/, s_code)

                range = Utility.RangeCalc.range({num, a, b})

                accum =
                  Enum.reduce(range, [], fn x, accum ->
                    [{s_code, ef_code, x, ef_code <> x, amd_type} | accum]
                  end)
                  |> Enum.reverse()

                # |> IO.inspect()

                accum ++ acc

              true ->
                acc
            end

          true ->
            acc
        end

      # ef_codes passed in by the Optimiser have the right pattern set
      {_k, {ef_code, sn, amd, tag}}, acc ->
        [{ef_code, sn, amd, tag} | acc]
    end)
    |> Enum.uniq()
    |> Enum.reverse()
    |> IO.inspect(label: "EF_TAGS", limit: :infinity)
  end
end

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
  def optimise_ef_codes(ef_codes, label) do
    with optimised <- optimiser(ef_codes, label),
         mapped <- mapper(optimised, label),
         ef_codes <- remover(ef_codes, mapped, label) do
      combiner(ef_codes, mapped, label)
    end
  end

  @doc """
  Function to check if we have an F code with a range of section numbers
  And then if the count of F codes equals the size of the range
  If this is the case we can optimise assuming a 1 to 1 between F code and section number
  """
  def optimiser(ef_codes, label) when is_list(ef_codes) do
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
    |> IO.inspect(label: "#{label} OPTIMISED")
  end

  def mapper(optimised, label) when is_list(optimised) do
    optimised
    |> Enum.reduce([], fn {_k, {efs, sns, amds}}, acc ->
      Enum.zip([efs, sns, amds]) ++ acc
    end)
    |> Enum.reduce([], fn {ef, sn, amd}, acc ->
      [{:"#{ef}", {ef, sn, amd, ef <> sn}} | acc]
    end)
    |> Enum.reverse()
    |> IO.inspect(label: "#{label} MAPPED")
  end

  @doc """
  Remove the mapped F codes from the original list of ef_codes
  """
  def remover(ef_codes, mapped, label) do
    Enum.map(mapped, fn {k, _v} -> k end)
    |> (&Keyword.drop(ef_codes, &1)).()
    |> IO.inspect(label: "#{label} REMOVED")
  end

  @doc """
  Function to combine the optimised ef_codes with the 'new' original list of
  ef_codes. Namely the list with the optimised ef_codes removed
  """
  def combiner(ef_codes, optimised, label) do
    (ef_codes ++ optimised)
    |> Enum.sort_by(&Atom.to_string(elem(&1, 0)), {:desc, NaturalOrder})
    |> IO.inspect(label: "#{label} COMBINED")
  end
end
