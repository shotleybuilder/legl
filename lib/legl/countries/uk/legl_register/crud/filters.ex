defmodule Legl.Countries.Uk.LeglRegister.New.Filters do
  # alias Legl.Countries.Uk.UkSearch.Terms
  alias Legl.Countries.Uk.UkSearch.Terms.HealthSafety, as: HS
  alias Legl.Countries.Uk.UkSearch.Terms.Environment, as: E
  alias Legl.Countries.Uk.UkSearch.Terms.SICodes

  @hs_search_terms HS.hs_search_terms()
  @e_search_terms E.e_search_terms()

  def si_code_filter(records) when is_list(records) do
    Enum.reduce(records, {[], []}, fn
      %{si_code: si_code} = record, acc when si_code not in ["", nil, []] ->
        si_codes = String.split(si_code, ",")

        case si_code_member?(si_codes) do
          true ->
            record = Map.put(record, :Family, si_code_family(si_codes))
            {[record | elem(acc, 0)], elem(acc, 1)}

          _ ->
            {elem(acc, 0), [record | elem(acc, 1)]}
        end

      record, acc ->
        {elem(acc, 0), [record | elem(acc, 1)]}
    end)
    |> (&{:ok, &1}).()
  end

  def si_code_filter({inc_w_si, inc_wo_si}) do
    Enum.reduce(inc_w_si, {[], inc_wo_si}, fn
      %{si_code: si_codes} = law, {inc, exc} ->
        si_codes = if is_binary(si_codes), do: String.split(si_codes, ","), else: si_codes

        case si_code_member?(si_codes) do
          true ->
            Map.put(law, :Family, si_code_family(si_codes))
            |> (&{[&1 | inc], exc}).()

          _ ->
            {inc, [law | exc]}
        end

      # Acts and some regs don't have SI Codes
      law, {inc, exc} ->
        {[law | inc], exc}
    end)
    |> (&{:ok, &1}).()
  end

  def si_code_member?(si_code) when is_binary(si_code),
    do: MapSet.member?(SICodes.si_codes(), si_code)

  def si_code_member?(si_codes) when is_list(si_codes) do
    Enum.reduce_while(si_codes, false, fn si_code, _acc ->
      case si_code_member?(si_code) do
        true -> {:halt, true}
        _ -> {:cont, false}
      end
    end)
  end

  def si_code_family(si_codes) when is_list(si_codes) do
    Enum.map(si_codes, &si_code_family(&1))
    |> Enum.uniq()
    |> Enum.filter(fn family -> family != nil end)
    |> List.first()
  end

  @doc """
  Function to lookup si_code and return Family
  """
  @spec si_code_family(binary()) :: binary() | nil
  def si_code_family(si_code) do
    case Map.get(Legl.Countries.Uk.LeglRegister.Models.ehs_si_code_family(), si_code) do
      nil -> ""
      family -> family
    end
  end

  @spec terms_filter({list(), list()}) :: {:ok, {list(), list()}}
  def terms_filter({i, e}) do
    IO.puts("Terms inside Title Filter")
    IO.puts("# PRE_FILTERED RECORDS: inc:#{Enum.count(i)} exc:#{Enum.count(e)}")

    search_terms = @hs_search_terms ++ @e_search_terms

    {inc, exc} =
      Enum.reduce(i, {[], e}, fn law, {inc, exc} ->
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
            Map.put(law, :Family, Atom.to_string(k))
            |> (&{[&1 | inc], exc}).()

          false ->
            {inc, [law | exc]}
        end
      end)

    IO.puts("# INCLUDED RECORDS: #{Enum.count(inc)}")
    IO.puts("# EXCLUDED RECORDS: #{Enum.count(exc)}")
    {:ok, {Enum.reverse(inc), Enum.reverse(exc)}}
  end

  @doc """
  Function to exclude certain common new law titles
  """
  @spec title_filter(list()) :: {list(), list()}
  def title_filter(records) do
    IO.puts(~s/PRE-TITLE FILTER RECORD COUNT: #{Enum.count(records)}/)

    {inc, exc} =
      Enum.reduce(records, {[], []}, fn record, {inc, exc} ->
        title = String.downcase(record."Title_EN")

        case exclude?(title) do
          false ->
            {[record | inc], exc}

          true ->
            {inc, [record | exc]}
        end
      end)

    IO.puts(~s/POST-TITLE FILTER/)
    IO.puts("# INCLUDED RECORDS: #{Enum.count(inc)}")
    IO.puts("# EXCLUDED RECORDS: #{Enum.count(exc)}")
    {Enum.reverse(inc), Enum.reverse(exc)}
  end

  @exclusions [
    ~r/railways?.*station.*order/,
    ~r/railways?.*junction.*order/,
    ~r/(network rail|railways?).*(extensions?|improvements?|preparation|enhancement|reduction).*order/,
    ~r/rail freight.*order/,
    ~r/light railway order/,
    ~r/drought.*order/,
    ~r/restriction of flying/,
    ~r/correction slip/,
    ~r/trunk road/,
    ~r/harbour empowerment order/,
    ~r/harbour revision order/,
    ~r/parking places/,
    ~r/parking prohibition/,
    ~r/parking and waiting/,
    ~r/development consent order/,
    ~r/electrical system order/
  ]

  defp exclude?(title) do
    Enum.reduce_while(@exclusions, false, fn n, _acc ->
      # n = :binary.compile_pattern(v)

      case Regex.match?(n, title) do
        true -> {:halt, true}
        false -> {:cont, false}
      end
    end)
  end
end
