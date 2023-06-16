defmodule Legl.Countries.Uk.AirtableArticle.UkEfCodes do
  alias Legl.Countries.Uk.AirtableArticle.UkArticleQa, as: QA

  def ef_codes(binary, regex, label) when is_binary(regex),
    do: ef_codes(binary, ~r/#{regex}/m, label)

  def ef_codes(binary, regex, label) when is_struct(regex) do
    QA.scan_and_print(binary, regex, label, true)
    # IO.inspect(regex)

    Regex.scan(regex, binary)
    |> Enum.reduce([], fn scan_list, acc ->
      # regex return different sized lists
      ef_code_tuple(scan_list) ++ acc
    end)
    |> Enum.uniq()
    |> IO.inspect(label: "#{label} PRE-PROCESSED", limit: :infinity)
  end

  @doc """
  SCHEDULES
  """
  def ef_code_tuple([match, ef_code, s_code]) do
    ef_code_tuple([match, ef_code, s_code, ""])
  end

  def ef_code_tuple([_, ef_code, s_code, amd_type]) do
    String.split(s_code, ",")
    |> Enum.reduce([], fn x, acc ->
      String.split(x, "and") ++ acc
    end)
    |> Enum.map(&String.trim(&1))
    |> Enum.map(&{:"#{ef_code}", {ef_code, &1, amd_type}})
  end

  def ef_tags(ef_codes) do
    ef_tags =
      Enum.reduce(ef_codes, [], fn
        {_k, {ef_code, s_code, amd_type}}, acc ->
          cond do
            String.contains?(s_code, ",") ->
              accum =
                String.split(s_code, ",")
                |> Enum.reduce([], fn sn, accum ->
                  [{ef_code, sn, amd_type, ef_code <> sn} | accum]
                end)

              if accum == [], do: IO.puts("ERROR: No Ef_tags for #{ef_code} #{s_code}")

              accum ++ acc

            String.contains?(s_code, "-") ->
              accum =
                Utility.RangeCalc.range(s_code)
                |> Enum.reduce([], fn x, accum ->
                  [{ef_code, "#{x}", amd_type, ef_code <> "#{x}"} | accum]
                end)

              if accum == [], do: IO.puts("ERROR: No Ef_tags for #{ef_code} #{s_code}")

              accum ++ acc

            true ->
              [{ef_code, s_code, amd_type, ef_code <> s_code} | acc]
          end

        # ef_codes passed in by the Optimiser have the right pattern set
        {_k, {ef_code, sn, amd, tag}}, acc ->
          [{ef_code, sn, amd, tag} | acc]
      end)
      |> Enum.uniq()
      |> Enum.sort_by(&elem(&1, 3), {:desc, NaturalOrder})

    case Enum.count(ef_tags) do
      0 -> IO.puts("ERROR: zero Ef_tags created")
      _ -> IO.puts("EF_TAGS COUNT #{Enum.count(ef_tags)}")
    end

    ef_tags
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
    with optimised <- optimiser(ef_codes),
         mapped <- mapper(optimised),
         ef_codes <- remover(ef_codes, mapped) do
      combiner(ef_codes, mapped, label)
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
          case Regex.run(~r/(\d+)([A-Z]?)([A-Z]?)-(\d+)([A-Z]?)([A-Z]?)/, k) do
            nil ->
              IO.puts("ERROR OPTIMISER #{k}")
              acc

            result ->
              [_hd | tail] = result
              s_codes = Utility.RangeCalc.range(tail)

              # IO.puts("rng #{rng} count #{Enum.count(v)}")
              # Does the size of the range equal the number of F codes?
              case Enum.count(s_codes) == Enum.count(v) do
                true ->
                  efs = Enum.map(v, &elem(&1, 0))
                  amd_types = Enum.map(v, &elem(&1, 2))

                  [{:"#{k}", {efs, s_codes, amd_types}} | acc]

                false ->
                  acc
              end
          end

        false ->
          acc
      end
    end)
  end

  def mapper(optimised) when is_list(optimised) do
    optimised
    |> Enum.reduce([], fn {_k, {efs, sns, amds}}, acc ->
      Enum.zip([efs, sns, amds]) ++ acc
    end)
    |> Enum.reduce([], fn {ef, sn, amd}, acc ->
      [{:"#{ef}", {ef, sn, amd}} | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Remove the mapped F codes from the original list of ef_codes
  """
  def remover(ef_codes, mapped) do
    Enum.map(mapped, fn {k, _v} -> k end)
    |> (&Keyword.drop(ef_codes, &1)).()
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
