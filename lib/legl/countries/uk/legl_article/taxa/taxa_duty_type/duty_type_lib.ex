defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyTypeLib do
  alias Legl.Countries.Uk.Article.Taxa.Actor.ActorLib
  alias Legl.Countries.Uk.Article.Taxa.LATTaxa
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGoverned
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefnGovernment
  alias Legl.Countries.Uk.AtArticle.Taxa.TaxaDutyType.DutyTypeDefn

  alias Legl.Countries.Uk.LeglInterpretation.Interpretation

  @type duty_types :: list()
  @type dutyholders :: list()
  @type dutyholders_gvt :: list()
  @type article_text :: binary()
  @type opts :: map()

  @doc """
  Function find role holders
  """

  @spec find_role_holders(atom(), %LATTaxa{}, article_text(), list(), opts()) ::
          {dutyholders(), duty_types(), binary()} | {[], [], binary(), binary()}
  def find_role_holders(_, %{"Duty Type": ["Amendment"]}, _, _, _), do: {[], [], "", []}

  def find_role_holders(_, %{"Duty Actor": [], "Duty Actor Gvt": []}, _text, regexes, _opts),
    do: {[], [], "", regexes}

  def find_role_holders(role, %{"Duty Actor": []}, _text, regexes, _opts)
      when role in [:duty, :right],
      do: {[], [], "", regexes}

  def find_role_holders(role, %{"Duty Actor Gvt": []}, _text, regexes, _opts)
      when role in [:responsibility, :power],
      do: {[], [], "", regexes}

  def find_role_holders(role, %{"Duty Actor": actors}, text, regexes, opts)
      when role in [:duty, :right],
      do: find_role_holders(role, actors, text, regexes, opts)

  def find_role_holders(role, %{"Duty Actor Gvt": actors}, text, regexes, opts)
      when role in [:responsibility, :power],
      do: find_role_holders(role, actors, text, regexes, opts)

  def find_role_holders(role, actors, text, regexes, opts)
      when is_list(actors) and role in [:duty, :right, :responsibility, :power] do
    actors_regex =
      case role do
        r when r in [:duty, :right] -> ActorLib.custom_actor_library(actors, :governed)
        _ -> ActorLib.custom_actor_library(actors, :government)
      end

    regex =
      case role do
        :duty -> build_lib(actors_regex, &DutyTypeDefnGoverned.duty/1)
        :responsibility -> build_lib(actors_regex, &DutyTypeDefnGovernment.responsibility/1)
        :right -> build_lib(actors_regex, &DutyTypeDefnGoverned.right/1)
        :power -> build_lib(actors_regex, &DutyTypeDefnGovernment.power_conferred/1)
      end

    text = blacklist(text)

    opts =
      Map.put(
        opts,
        :role_holder,
        label: String.upcase(Atom.to_string(role))
      )

    case role_holder_run_regex({text, [], [], regexes}, regex, opts) do
      {_, [], _, regexes} ->
        {[], [], "", regexes}

      {_, role_holders, matches, regexes} ->
        {
          Enum.uniq(role_holders),
          role |> Atom.to_string() |> String.capitalize() |> List.wrap(),
          matches |> Enum.uniq() |> Enum.map(&String.trim(&1)) |> Enum.join("\n"),
          regexes
        }
    end
  end

  def role_holder_run_regex(collector, library, %{role_holder: [label: label]} = _opts) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn regex, {text, role_holders, matches, reg_exs} = acc2 ->
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

            match = if String.valid?(match), do: match, else: Legl.Utility.to_utf8(match)

            """
            IO.puts(~s/#{label}: #{actor}/)
            IO.puts(~s/MATCH: #{inspect(match)}/)
            IO.puts(~s/REGEX: #{regex}\n/)
            """

            {
              text,
              [actor | role_holders],
              [~s/#{label}\n👤#{actor}\n📌#{match}\n/ | matches],
              [~s/#{label}: #{actor}\n#{regex}\n-> #{match}\n/ | reg_exs]
            }

          nil ->
            acc2

          match ->
            IO.puts(
              "ERROR role_holder_run_regex/3:\nText:\n#{text}\nRegex:\n#{regex}\nMATCH:\n#{inspect(match)}"
            )
        end
      end)
    end)
  end

  @spec blacklist(binary()) :: binary()
  def blacklist(text) do
    blacklist_regex = blacklist_regex()

    Enum.reduce(blacklist_regex, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/, acc, " ")
    end)
  end

  @spec blacklist_regex() :: list(binary())
  defp blacklist_regex() do
    modals = ~s/(?:shall|must|may[ ]only|may[ ]not)/

    [
      "[ ]area of the authority",
      # Other subjects directly adjacent to the modal verb
      "[ ]said report (?:shall|must)|shall[ ]not[ ]apply",
      "[ ]may[ ]be[ ](?:approved|reduced|reasonably foreseeably|required)",
      "[ ]may[ ]reasonably[ ]require",
      "[ ]as[ ]the[ ]case[ ]may[ ]be",
      "[ ]as may reasonably foreseeably",
      "[ ]and[ ]#{modals}"
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
    |> process(DutyTypeDefn.transitional_arrangement())
    |> process(DutyTypeDefn.charge_fee())
    |> process(DutyTypeDefn.offence())
    |> process(DutyTypeDefn.enforcement_prosecution())
    |> process(DutyTypeDefn.defence_appeal())
    |> process(DutyTypeDefn.power_conferred())
  end

  @spec process({article_text(), []}, list()) :: {article_text(), list()}
  def process(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, duty_type}, {text, duty_types} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          # #{text} #{duty_type}/)
          IO.puts(~s/#{regex}/)
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
