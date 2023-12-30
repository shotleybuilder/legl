defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib do
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib

  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGoverned
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGovernment
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefn

  @type duty_types :: list()
  @type dutyholders :: list()
  @type dutyholders_gvt :: list()
  @type article_text :: binary()

  @spec duty_types_for_dutyholders_gvt(article_text(), list()) ::
          {dutyholders_gvt(), duty_types()}
  def duty_types_for_dutyholders_gvt(text, actors) do
    # has to process first to ensure the amending text for other law doesn't get tagged
    {text, duty_types} = process({text, []}, DutyTypeDefn.amendment())

    if actors != [] do
      government = DutyholderLib.custom_dutyholder_library(actors, :government)

      text = blacklist(government, text)

      responsibility = build_lib(government, &DutyTypeDefnGovernment.responsibility/1)
      discretionary = build_lib(government, &DutyTypeDefnGovernment.discretionary/1)
      power_conferred = build_lib(government, &DutyTypeDefnGovernment.power_conferred/1)

      {_text, {dutyholders, duty_types}} =
        {text, {[], duty_types}}
        |> process_dutyholder(responsibility)
        |> process_dutyholder(power_conferred)
        |> process_dutyholder(discretionary)

      dedupe({dutyholders, duty_types})
    else
      {[], duty_types}
    end
  end

  @doc """
  Function to set duty type for 'governed' dutyholders
  """
  @spec duty_types_for_dutyholders(article_text(), list()) :: {dutyholders(), duty_types()}
  def duty_types_for_dutyholders(text, actors) do
    {text, duty_types} = process({text, []}, DutyTypeDefn.amendment())

    if actors != [] do
      # A subset of the full 'governed' library of duty actors
      governed = DutyholderLib.custom_dutyholder_library(actors, :governed)

      right = build_lib(governed, &DutyTypeDefnGoverned.right/1)
      duty = build_lib(governed, &DutyTypeDefnGoverned.duty/1)

      text = blacklist(governed, text)

      {_text, {dutyholders, duty_types}} =
        {text, {[], duty_types}}
        |> process_dutyholder(right)
        |> process_dutyholder(duty)

      if Enum.any?(actors, fn actor -> actor == "Org: Employer" end) and dutyholders == [] do
        # regex = Keyword.get(duty, :"Org: Employer")
        # IO.puts("DUTY REGEX: #{inspect(regex)}\nDutyholders: #{inspect(dutyholders)}\n#{text}")
        IO.puts(
          ~s/\nNOTE: The "Org: Employer" Actor did not result in a DUTY for this article\n#{text}/
        )
      end

      dedupe({dutyholders, duty_types})
    else
      {[], duty_types}
    end
  end

  @spec blacklist(list(), binary()) :: binary()
  def blacklist(govern, text) when is_list(govern) do
    Enum.reduce(govern, text, fn
      # {_k, {_, regex}}, acc -> blacklist(acc, regex)
      {_k, regex}, acc -> blacklist(acc, regex)
    end)
  end

  @spec blacklist(binary(), binary()) :: binary()
  def blacklist(text, gvn_regex) do
    blacklist_regex = blacklist_regex(gvn_regex)

    Enum.reduce(blacklist_regex, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/, acc, "")
    end)
  end

  @spec blacklist_regex(binary()) :: list(binary())
  defp blacklist_regex(regex) do
    [
      "area of the authority",
      "#{regex}may (?:be|not)"
    ]
  end

  @spec build_lib(list(), function()) :: keyword()
  def build_lib(governed, f) do
    Enum.map(governed, fn
      {actor, regex} -> {actor, f.(regex)}
    end)
    |> List.flatten()
  end

  def process_dutyholder(collector, library) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn {regex, duty_type}, {text, {dutyholders, duty_types}} = acc2 ->
        {regex, rm_matched_text?} =
          case regex do
            {regex, true} -> {regex, true}
            _ -> {regex, false}
          end

        regex_c =
          case Regex.compile(regex, "m") do
            {:ok, regex} ->
              # IO.puts(~s/#{inspect(regex)}/)
              regex

            {:error, error} ->
              IO.puts(~s/ERROR: Regex doesn't compile\n#{error}\n#{regex}/)
          end

        case Regex.run(regex_c, text) do
          [match] ->
            text =
              case rm_matched_text? do
                false -> text
                true -> Regex.replace(regex_c, text, "")
              end

            IO.puts(~s/DUTYHOLDER: #{actor}/)
            IO.puts(~s/MATCH: #{inspect(match)}/)
            IO.puts(~s/REGEX: #{regex}\n/)

            {text, {[actor | dutyholders], [duty_type | duty_types]}}

          nil ->
            # IO.puts(~s/"#{regex}" did not match "#{text}"/)
            acc2

          match ->
            IO.puts(
              "ERROR process_dutyholder/3:\nText:\n#{text}\nRegex:\n#{regex}\nMATCH:\n#{inspect(match)}"
            )
        end
      end)
    end)
  end

  @spec duty_types_generic(article_text()) :: list(duty_types()) | []
  def duty_types_generic(text) do
    {text, []}
    |> process_duty_types()
    |> elem(1)
    |> Enum.uniq()
  end

  @spec process_duty_types({article_text(), []}) :: {article_text(), duty_types() | []}
  def process_duty_types(collector) do
    collector
    |> process(DutyTypeDefn.enaction_citation_commencement())
    |> process(DutyTypeDefn.extent())
    |> process(DutyTypeDefn.interpretation_definition())
    |> process(DutyTypeDefn.application_scope())
    |> process(DutyTypeDefn.exemption())
    |> process(DutyTypeDefn.repeal_revocation())
    # |> process("Transitional Arrangement", transitional_arrangement())
    |> process(DutyTypeDefn.charge_fee())
    |> process(DutyTypeDefn.offence())
    |> process(DutyTypeDefn.enforcement_prosecution())
    |> process(DutyTypeDefn.defence_appeal())
  end

  @spec process({article_text(), []}, list()) :: {article_text(), list()}
  def process(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, duty_type}, {text, duty_types} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          # IO.puts(~s/#{text} #{duty_type}/)
          duty_type = if is_binary(duty_type), do: [duty_type], else: duty_type

          # A specific term (approved person) should be removed from the text to avoid matching on 'person'
          {Regex.replace(~r/#{regex}/m, text, ""), duty_types ++ duty_type}

        false ->
          acc
      end
    end)
  end

  def process_qa(
        {article_text, {_dutyholders, ["Process, Rule, Constraint, Condition"]}} = collector
      ) do
    IO.puts(~s/No specific duty-type match for this text\n#{article_text}/)
    collector
  end

  defp dedupe({dutyholders, duty_types}) do
    {Enum.uniq(dutyholders), Enum.uniq(duty_types)}
  end
end
