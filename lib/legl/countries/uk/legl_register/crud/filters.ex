defmodule Legl.Countries.Uk.LeglRegister.New.Filters do
  # alias Legl.Countries.Uk.UkSearch.Terms
  alias Legl.Countries.Uk.UkSearch.Terms.HealthSafety, as: HS
  alias Legl.Countries.Uk.UkSearch.Terms.Environment, as: E
  alias Legl.Countries.Uk.UkSearch.Terms.SICodes

  @hs_search_terms HS.hs_search_terms()
  @e_search_terms E.e_search_terms()

  @hs_si_codes SICodes.si_codes()
  @e_si_codes SICodes.e_si_codes()

  def si_code_filter({inc_w_si, inc_wo_si}, base_name) do
    lib_si_codes =
      case base_name do
        "UK S" -> @hs_si_codes
        "UK E" -> @e_si_codes
        "UK EHS" -> @hs_si_codes ++ @e_si_codes
      end

    Enum.reduce(inc_w_si, {[], inc_wo_si}, fn
      %{si_code: si_codes} = law, {inc, exc} ->
        si_codes = if is_binary(si_codes), do: String.split(si_codes, ","), else: si_codes

        case si_code_member?(si_codes, lib_si_codes) do
          true -> {[law | inc], exc}
          _ -> {inc, [law | exc]}
        end

      # Acts and some regs don't have SI Codes
      law, {inc, exc} ->
        {[law | inc], exc}
    end)
    |> (&{:ok, &1}).()
  end

  def si_code_member?(si_code, lib_si_codes) when is_binary(si_code),
    do: MapSet.member?(lib_si_codes, si_code)

  def si_code_member?(si_codes, lib_si_codes) when is_list(si_codes) do
    Enum.reduce_while(si_codes, false, fn si_code, _acc ->
      case MapSet.member?(lib_si_codes, si_code) do
        true -> {:halt, true}
        _ -> {:cont, false}
      end
    end)
  end

  @spec terms_filter(list(), map()) :: {:ok, {list(), list()}}
  def terms_filter(laws, base_name) do
    IO.puts("Terms inside Title Filter")
    IO.puts("# PRE_FILTERED RECORDS: #{Enum.count(laws)}")

    search_terms =
      case base_name do
        "UK S" -> @hs_search_terms
        "UK E" -> @e_search_terms
        "UK EHS" -> @hs_search_terms ++ @e_search_terms
      end

    {inc, exc} =
      Enum.reduce(laws, {[], []}, fn law, {inc, exc} ->
        title = String.downcase(law."Title_EN")

        match? =
          Enum.reduce_while(search_terms, false, fn {k, n}, _acc ->
            # n = :binary.compile_pattern(v)

            case String.contains?(title, n) do
              true -> {:halt, {true, k}}
              false -> {:cont, false}
            end
          end)

        case match? do
          {true, k} ->
            case exclude?(title) do
              true ->
                {inc, exc}

              false ->
                Map.put(law, :Family, Atom.to_string(k))
                |> (&{[&1 | inc], exc}).()
            end

          false ->
            case exclude?(title) do
              true ->
                {inc, exc}

              false ->
                {inc, [law | exc]}
            end
        end
      end)

    IO.puts("# INCLUDED RECORDS: #{Enum.count(inc)}")
    IO.puts("# EXCLUDED RECORDS: #{Enum.count(exc)}")
    {:ok, {Enum.reverse(inc), Enum.reverse(exc)}}
  end

  @doc """
  Function to exclude certain laws even though terms filter includes them
  """
  def exclude?(title) do
    search_terms = ~w[
    restriction\u00a0of\u00a0flying
    correction\u00a0slip
    trunk\u00a0road
    harbour\u00a0empowerment\u00a0order
    harbour\u00a0revision\u00a0order
  ] |> Enum.map(&String.replace(&1, "\u00a0", " "))

    Enum.reduce_while(search_terms, false, fn n, _acc ->
      # n = :binary.compile_pattern(v)

      case String.contains?(title, n) do
        true -> {:halt, true}
        false -> {:cont, false}
      end
    end)
  end
end
