defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib do
  alias Legl.Countries.Uk.Article.Taxa.Actor.ActorLib
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGoverned
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGovernment
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefn

  @type duty_types :: list()
  @type dutyholders :: list()
  @type dutyholders_gvt :: list()
  @type article_text :: binary()
  @type opts :: map()

  @spec duty_types_for_dutyholders_gvt(%LATTaxa{}, binary(), opts()) ::
          {dutyholders_gvt(), duty_types()} | {[], []}
  def duty_types_for_dutyholders_gvt(%{"Duty Actor Gvt": []}, _text, _opts), do: {[], []}

  def duty_types_for_dutyholders_gvt(%{"Duty Actor Gvt": actors}, text, opts)
      when is_list(actors) do
    government = ActorLib.custom_actor_library(actors, :government)

    # |> IO.inspect(label: "GVT:")
    text = blacklist(government, text)

    responsibility = build_lib(government, &DutyTypeDefnGovernment.responsibility/1)
    discretionary = build_lib(government, &DutyTypeDefnGovernment.discretionary/1)
    power_conferred = build_lib(government, &DutyTypeDefnGovernment.power_conferred/1)

    {_text, {dutyholders, duty_types}} =
      {text, {[], []}}
      |> process_dutyholder(responsibility, opts)
      |> process_dutyholder(power_conferred, opts)
      |> process_dutyholder(discretionary, opts)

    dedupe({dutyholders, duty_types})
  end

  @doc """
  Function to set duty type for 'governed' dutyholders
  """

  @spec duty_types_for_dutyholders(%LATTaxa{}, article_text(), opts()) ::
          {dutyholders(), duty_types()} | {[], []}
  def duty_types_for_dutyholders(%{"Duty Actor": []}, _text, _opts), do: {[], []}

  def duty_types_for_dutyholders(%{"Duty Actor": actors}, text, opts) when is_list(actors) do
    # A subset of the full 'governed' library of duty actors
    governed = ActorLib.custom_actor_library(actors, :governed)

    # right = build_lib(governed, &DutyTypeDefnGoverned.right/1)
    duty = build_lib(governed, &DutyTypeDefnGoverned.duty/1)

    # |> IO.inspect()
    text = blacklist(governed, text)

    {_text, {dutyholders, duty_types}} =
      {text, {[], []}}
      # |> process_dutyholder(right, opts)
      |> process_dutyholder(duty, opts)

    if Enum.any?(actors, fn actor -> actor == "Org: Employer" end) and dutyholders == [] do
      # regex = Keyword.get(duty, :"Org: Employer")
      # IO.puts("DUTY REGEX: #{inspect(regex)}\nDutyholders: #{inspect(dutyholders)}\n#{text}")
      IO.puts(
        ~s/\nNOTE: The "Org: Employer" Actor did not result in a DUTY for this article\n#{text}/
      )
    end

    dedupe({dutyholders, duty_types})
  end

  def find_rightsholders(%{"Duty Type": ["Amendment"]}, _text, _opts), do: {[], []}
  def find_rightsholders(%{"Duty Actor": []}, _text, _opts), do: {[], []}

  def find_rightsholders(%{"Duty Actor": actors}, text, opts) when is_list(actors) do
    # A subset of the full 'governed' library of duty actors
    governed = ActorLib.custom_actor_library(actors, :governed)

    right = build_lib(governed, &DutyTypeDefnGoverned.right/1)

    text = blacklist(governed, text)

    {_text, {rightsholders, duty_types}} = process_rightsholder({text, {[], []}}, right, opts)

    dedupe({rightsholders, duty_types})
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
    modals = ~s/(?:shall|must|may[ ]only|may[ ]not)/

    [
      "area of the authority",
      "#{regex}may (?:be)",
      # Other subjects directly adjacent to the modal verb
      "said report (?:shall|must)|shall[ ]not[ ]apply",
      "may[ ]be[ ](?:approved|reduced|reasonably foreseeably|required)",
      "may[ ]reasonably[ ]require",
      "as[ ]the[ ]case[ ]may[ ]be",
      "as may reasonably foreseeably",
      "and[ ]#{modals}"
    ]
  end

  @spec build_lib(list(), function()) :: keyword()
  def build_lib(governed, f) do
    Enum.map(governed, fn
      {actor, regex} -> {actor, f.(regex)}
    end)
    |> List.flatten()
    |> Enum.reverse()

    # |> IO.inspect(label: "BUILD LIB: ")
  end

  def process_dutyholder(collector, library, opts) do
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

            case File.open(
                   ~s[lib/legl/countries/uk/at_article/taxa/taxa_dutyholder/_results/#{opts."Name"}.txt],
                   [:append]
                 ) do
              {:ok, file} ->
                IO.binwrite(
                  file,
                  ~s/\nDUTYHOLDER: #{actor}\nMATCH: #{match}\nREGEX: #{regex}\nDUTY TYPE: #{inspect(duty_type)}\n/
                )

                File.close(file)

              {:error, :enoent} ->
                :ok
            end

            case is_list(duty_type) do
              true -> {text, {[actor | dutyholders], duty_type ++ duty_types}}
              false -> {text, {[actor | dutyholders], [duty_type | duty_types]}}
            end

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

  def process_rightsholder(collector, library, opts) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn regex, {text, {rightsholders, duty_types}} = acc2 ->
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

            IO.puts(~s/RIGHTSHOLDER: #{actor}/)
            IO.puts(~s/MATCH: #{inspect(match)}/)
            IO.puts(~s/REGEX: #{regex}\n/)

            case File.open(
                   ~s[lib/legl/countries/uk/at_article/taxa/taxa_rightsholder/_results/#{opts."Name"}.txt],
                   [:append]
                 ) do
              {:ok, file} ->
                IO.binwrite(
                  file,
                  ~s/\nRIGHTSHOLDER: #{actor}\nMATCH: #{match}\nREGEX: #{regex}\n/
                )

                File.close(file)

              {:error, :enoent} ->
                :ok
            end

            {text, {[actor | rightsholders], ["Right" | duty_types]}}

          nil ->
            # IO.puts(~s/"#{regex}" did not match "#{text}"/)
            acc2

          match ->
            IO.puts(
              "ERROR process_rightsholder/3:\nText:\n#{text}\nRegex:\n#{regex}\nMATCH:\n#{inspect(match)}"
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
