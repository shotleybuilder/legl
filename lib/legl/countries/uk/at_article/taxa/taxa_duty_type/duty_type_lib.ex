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

  @doc """
  Function find role holders
  """

  @spec find_role_holders(atom(), %LATTaxa{}, article_text(), opts()) ::
          {dutyholders(), duty_types()} | {[], []}
  def find_role_holders(_, %{"Duty Type": ["Amendment"]}, _text, _opts), do: {[], []}
  def find_role_holders(_, %{"Duty Actor": [], "Duty Actor Gvt": []}, _text, _opts), do: {[], []}

  def find_role_holders(role, %{"Duty Actor": []}, _, _) when role in [:duty, :right],
    do: {[], []}

  def find_role_holders(role, %{"Duty Actor Gvt": []}, _, _)
      when role in [:responsibility, :power],
      do: {[], []}

  def find_role_holders(role, %{"Duty Actor": actors}, text, opts) when role in [:duty, :right],
    do: find_role_holders(role, actors, text, opts)

  def find_role_holders(role, %{"Duty Actor Gvt": actors}, text, opts)
      when role in [:responsibility, :power],
      do: find_role_holders(role, actors, text, opts)

  def find_role_holders(role, actors, text, opts)
      when is_list(actors) and role in [:duty, :right, :responsibility, :power] do
    #
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

    text = blacklist(actors_regex, text)

    opts =
      Map.put(
        opts,
        :role_holder,
        label: String.upcase(Atom.to_string(role))
      )

    case role_holder_run_regex({text, []}, regex, opts) do
      [] ->
        {[], []}

      role_holders ->
        {Enum.uniq(role_holders), role |> Atom.to_string() |> String.capitalize() |> List.wrap()}
    end
  end

  def role_holder_run_regex(collector, library, %{role_holder: [label: label]} = opts) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn regex, {text, role_holders} = acc2 ->
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

            IO.puts(~s/#{label}: #{actor}/)
            IO.puts(~s/MATCH: #{inspect(match)}/)
            IO.puts(~s/REGEX: #{regex}\n/)

            case File.open(
                   ~s[lib/legl/countries/uk/at_article/taxa/taxa_rightsholder/_results/#{opts."Name"}.txt],
                   [:append]
                 ) do
              {:ok, file} ->
                IO.binwrite(
                  file,
                  ~s/\n#{label}: #{actor}\nMATCH: #{match}\nREGEX: #{regex}\n/
                )

                File.close(file)

              {:error, :enoent} ->
                :ok
            end

            {text, [actor | role_holders]}

          nil ->
            # IO.puts(~s/"#{regex}" did not match "#{text}"/)
            acc2

          match ->
            IO.puts(
              "ERROR role_holder_run_regex/3:\nText:\n#{text}\nRegex:\n#{regex}\nMATCH:\n#{inspect(match)}"
            )
        end
      end)
    end)
    |> elem(1)
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
    |> process(DutyTypeDefn.power_conferred())
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
