defmodule Legl.Countries.Uk.LeglFitness.Fitness do
  @moduledoc """
  The applicability and appropriateness of UK-specific legislation.


  """
  require Logger

  alias __MODULE__
  alias Legl.Services.Airtable.Get
  alias Legl.Countries.Uk.LeglRegister.Crud.Read
  alias Legl.Countries.Uk.LeglArticle.Article
  alias Legl.Countries.Uk.LeglFitness, as: F

  @type legal_fitness :: %__MODULE__{
          lrt: list(),
          rule: String.t(),
          heading: list(),
          category: String.t(),
          scope: String.t(),
          provision: list(),
          person: list(),
          person_verb: String.t(),
          person_ii: String.t(),
          person_ii_verb: String.t(),
          process: list(),
          place: list(),
          property: String.t(),
          plant: String.t()
        }

  # @derive [Enumerable]
  @derive Jason.Encoder
  defstruct record_id: nil,
            # Multi Selects are array values
            lrt: [],
            heading: [],
            category: nil,
            scope: nil,
            provision: [],
            person: [],
            process: [],
            place: [],
            # Single Selects are string values
            rule: nil,
            person_verb: nil,
            person_ii: nil,
            person_ii_verb: nil,
            property: nil,
            plant: nil

  @base_id "appq5OQW9bTHC1zO5"
  @table_id "tblJW0DMpRs74CJux"

  @default_opts %{base_id: @base_id, table_id: @table_id}
  @lat_opts %{
    article_workflow_name: :"Original -> Clean -> Parse -> Airtable",
    html?: true,
    pbs?: true,
    country: :uk,
    fitness_type: []
  }

  def api_fitness(opts \\ []) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Read.api_read_opts()

    Get.get(opts.base_id, opts.table_id, opts)
    |> elem(1)
    |> process_fitness(opts.fitness_type)
  end

  def process_fitness(lrt_records, fitness_type) do
    lrt_records
    |> Enum.map(&extract_fields(&1))
    |> Enum.map(fn
      %{
        "Name" => name,
        "record_id" => record_id,
        "Title_EN" => title_en,
        "type_class" => type_class,
        "type_code" => _type_code
      } ->
        IO.puts(~s/\nNAME: #{name} #{title_en}/)

        lat_opts =
          @lat_opts
          |> Map.put(:Name, name)
          |> Map.put(:type, set_type(type_class))

        fitnesses =
          Article.api_article(lat_opts)
          |> elem(1)
          # |> IO.inspect(label: "articles")
          |> filter_fitness_sections()

        IO.inspect(fitnesses, label: "fitnesses")

        {lft_records, _fit?, _disfit?, ext?} =
          Enum.reduce(fitnesses, {[], false, false, false}, fn
            %{category: "applies-to"} = fitness, {acc, fit?, disfit?, ext?} ->
              case :fit not in fitness_type do
                true ->
                  case F.Parse.api_parse(fitness) do
                    [] -> {acc, fit?, disfit?, ext?}
                    [%{unmatched_text: _text}] = fit -> {acc ++ fit, fit?, disfit?, ext?}
                    fit -> {acc ++ fit, true, disfit?, ext?}
                  end

                false ->
                  {acc, fit?, disfit?, ext?}
              end

            %{category: "disapplies-to"} = fitness, {acc, fit?, disfit?, ext?} ->
              case :disfit not in fitness_type do
                true ->
                  case F.Parse.api_parse(fitness) do
                    [] -> {acc, fit?, disfit?, ext?}
                    [%{unmatched_text: _text}] = disfit -> {acc ++ disfit, fit?, disfit?, ext?}
                    disfit -> {acc ++ disfit, fit?, true, ext?}
                  end

                false ->
                  {acc, fit?, disfit?, ext?}
              end

            # [Legl.Countries.Uk.LeglFitness.ParseDisapplies.parse_disapplies(text) | acc]

            %{category: "extends-to", rule: text}, {acc, fit?, disfit?, ext?} ->
              case :ext not in fitness_type do
                true ->
                  case F.ParseExtendsTo.parse_extends_to(text) do
                    {:error, _error} -> {acc, fit?, disfit?, ext?}
                    ext -> {[ext | acc], fit?, disfit?, true}
                  end

                false ->
                  {acc, fit?, disfit?, ext?}
              end

            _, acc ->
              acc
          end)

        # IO.inspect(lft_records, label: "lft_records")

        lft_records =
          if ext? == false and :ext not in fitness_type,
            do: [F.ParseExtendsTo.does_not_extend_to() | lft_records],
            else: lft_records

        # IO.inspect(lft_records, label: "lft_records")

        Enum.each(lft_records, fn
          %{unmatched_text: text} ->
            Logger.warning("Unmatched text\n#{text}")

            Path.absname("lib/legl/countries/uk/legl_fitness/unmatched_text.txt")
            |> File.write!(name <> " : " <> text <> "\n", [:append])

          %Fitness{} = lft_record ->
            case F.SaveFitness.save_fitness_record(record_id, lft_record) do
              :ok -> :ok
              :error -> {:error, record_id, lft_record}
            end
        end)
    end)
  end

  @doc """
  Creates a fitness struct with the given fitness value.

  ## Examples

      iex> fitness = make_fitness_struct(10)
      %Fitness{value: 10}

  """
  def make_fitness_struct(fitness, finess_struct \\ %Fitness{}) do
    Enum.reduce(fitness, finess_struct, fn
      {"record_id", record_id}, acc ->
        Map.put(acc, :record_id, record_id)

      {"lrt", lrt}, acc ->
        Map.put(acc, :lrt, lrt)

      {"rule", rule}, acc ->
        Map.put(acc, :rule, rule)

      {"heading", heading}, acc ->
        Map.put(acc, :heading, heading)

      # Single Selects
      {"category", category}, acc ->
        Map.put(acc, :category, category)

      {"scope", scope}, acc ->
        Map.put(acc, :scope, scope)

      {"person_verb", person_verb}, acc ->
        Map.put(acc, :person_verb, person_verb)

      {"person_ii_verb", person_ii_verb}, acc ->
        Map.put(acc, :person_ii_verb, person_ii_verb)

      {"person_ii", person_ii}, acc ->
        Map.put(acc, :person_ii, person_ii)

      {"property", property}, acc ->
        Map.put(acc, :property, property)

      {"plant", plant}, acc ->
        Map.put(acc, :plant, plant)

      # Multi Selects
      {"provision", provision}, acc ->
        Map.put(acc, :provision, provision)

      {"person", person}, acc ->
        Map.put(acc, :person, person)

      {"process", process}, acc ->
        Map.put(acc, :process, process)

      {"place", place}, acc ->
        Map.put(acc, :place, place)

      _, acc ->
        acc
    end)
  end

  defp extract_fields(%{"id" => id} = record) do
    Map.put(record["fields"], :record_id, id)
  end

  def filter_fitness_sections(records) do
    Enum.reduce(records, {[], false}, fn
      %{type: type, text: text}, {fitnesses, _} when type in ["heading", "section"] ->
        case fitness_typer(text) do
          false ->
            {fitnesses, false}

          %Fitness{} = fitness ->
            {fitnesses, fitness}
        end

      %{type: type, text: text} = _record, {fitnesses, fitness_template} = acc
      when type in ["article", "sub-article", "sub-section"] and fitness_template != false ->
        case excluded_text?(text) do
          true ->
            acc

          _ ->
            # fitness_children are the secondary rules set in a parent rule
            fitnesses_children =
              text
              |> clean_rule_text()
              # |> IO.inspect(label: "clean_rule_text")
              |> (&Map.put(%{provision: []}, :rule, &1)).()
              # Deals with a 2-layer deep hierarchy of sub-rules (a) (i) etc.
              |> separate_rules()
              |> Enum.map(&separate_rules(&1))
              |> List.flatten()

            # |> IO.inspect(label: "fitness_children")

            fitness =
              Enum.map(fitnesses_children, fn fitness_child ->
                fitness_template
                |> Map.merge(fitness_child)
                |> fitness_typer()
                |> scope_typer()
              end)

            {fitnesses ++ fitness, fitness_template}
        end

      _, acc ->
        acc
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp clean_rule_text(text) do
    text
    |> (&Regex.replace(~r/[ ]?📌/m, &1, "\n")).()
    |> (&Regex.replace(~r/.*?([A-Z].*)/, &1, "\\1")).()
    |> (&Regex.replace(~r/F\d+[ ]/, &1, "")).()
    |> (&Regex.replace(~r/(?:\[|\])/, &1, "")).()
    |> (&Regex.replace(~r/’/, &1, "'")).()
    |> String.trim()
  end

  def separate_rules(%{provision: _provision, rule: rule} = fitness) do
    # IO.inspect(fitness, label: "fitness")

    case String.split(rule, "—\n", parts: 2) do
      # Single rule not broken by a new line
      [_h] ->
        fitness
        |> except()

      # Multiple rules with a leader paragraph
      [h | [t]] ->
        case String.split(t, ~r/[^—]\n\([a-z]\) /) do
          [_rule] ->
            # Secondary rules (i), (ii), (iii) etc.
            case String.split(t, ~r/[^—]\n\([ivx]+\) /) do
              [_rule] ->
                [fitness]

              rules ->
                Enum.map(rules, fn rule ->
                  rule
                  # (a) rule -> rule
                  |> (&Regex.replace(~r/^\([ivx]+\)[ ]/, &1, "")).()
                  # rule; or -> rule. || rule; and -> rule.
                  |> (&Regex.replace(~r/(?:;|,) o$|(?:;|,) an$/, &1, "\.")).()
                end)

                # Break apart rules with 'unless' clause. Returns a list of rules
                |> unless()
                |> combine_rules(Map.merge(fitness, %{rule: h}))
                |> end_period()
            end

          rules ->
            Enum.map(rules, fn rule ->
              rule
              # (a) rule -> rule
              |> (&Regex.replace(~r/^\([a-z]\)[ ]/, &1, "")).()
              # rule; or -> rule. || rule; and -> rule.
              |> (&Regex.replace(~r/; o$|; an$/, &1, "\.")).()
            end)

            # Break apart rules with 'unless' clause
            |> unless()
            |> combine_rules(Map.merge(fitness, %{rule: h}))
            |> end_period()
        end
    end
  end

  def unless(rules) when is_list(rules) do
    Enum.reduce(rules, [], fn text, acc ->
      case String.contains?(text, "unless") do
        true ->
          case Regex.run(~r/(.*?(?:shall|do) not extend to)/, text) do
            [_, rule] ->
              rule_opp =
                case String.contains?(rule, "shall not") do
                  true -> String.replace(rule, "shall not", "shall")
                  false -> String.replace(rule, "do not", "does")
                end

              # Split into LHS the 'rule' and RHS the 'unless' exception to the rule
              [h | [t]] = String.split(text, ~r/,? unless/, parts: 2)

              # Add the rule and the opposite exception to the rule to the accumulator
              [h, rule_opp <> t] ++ acc

            nil ->
              Logger.error("No 'unless' rule clause found in rule: #{text}")
              [text | acc]
          end

        _ ->
          [text | acc]
      end
    end)
  end

  defp except(%{rule: rule} = fitness) do
    case String.split(rule, ~r/,? except /, parts: 2) do
      [_h] ->
        [fitness]

      [h, t] ->
        [
          Map.put(fitness, :rule, h) |> parse_regulation_references(),
          Map.put(fitness, :rule, t) |> parse_regulation_references()
        ]

      _ ->
        Logger.error("Multiple 'except' clauses found in rule: #{fitness.rule}")
        [fitness]
    end
  end

  defp combine_rules(rules, fitness) when is_list(rules) do
    # Combine the rules
    # Exceptions mean the leader paragraph is a separate rule
    case String.contains?(fitness.rule, "except") do
      # W/O 'except' the children are appended to the parent rule
      false ->
        template = parse_regulation_references(fitness)

        Enum.map(rules, fn rule ->
          Map.put(template, :rule, template.rule <> " " <> rule)
        end)

      # When 'except' we treat all children as distinct rules
      true ->
        # Drop the 'except ... —' from the end of the parent rule
        fitness =
          fitness.rule
          |> String.split(~r/,? except /)
          |> List.first()
          |> (&Map.put(fitness, :rule, &1)).()

        fitness_children =
          Enum.map(rules, &parse_regulation_references(Map.merge(fitness, %{rule: &1})))

        [fitness | fitness_children]
    end
  end

  def parse_regulation_references(%{rule: rule, provision: []} = fitness) do
    # under regulation 5 (information and training) do not extend to persons who
    # Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply

    # Take everything before the rule
    case Regex.run(
           ~r/(.*?)((?: (?:shall|do) not| (?:shall|does)|, to the) (?:extend?t?|apply).*)/,
           rule
         ) do
      [_, refs, rest] ->
        # Regulation headings are in brackets and each stored in the 'provision' field

        case Regex.scan(~r/\(([a-z, ]{3,})\)/, refs, capture: :all_but_first) do
          [] ->
            fitness

          result ->
            provision =
              result
              |> List.flatten()
              |> Enum.map(&split_and(&1))
              |> List.flatten()

            # Rebuild to create a generic rule w/o Regulation references
            rule =
              provision
              |> Enum.join(", ")
              |> (&(&1 <> rest)).()
              |> initial_capitalisation()

            Map.merge(fitness, %{
              rule: rule,
              provision: Enum.map(provision, &String.replace(&1, " ", "-")),
              scope: "Part"
            })
        end

      nil ->
        Logger.error("No regulation references found in rule: #{rule}")
        fitness
    end
  end

  def parse_regulation_references(fitness), do: fitness

  def split_and(text) do
    # 'Something of foo and bar' should become 'something of foo' and 'something of bar'
    # 'foo and bar' becomes 'foo' and 'bar'

    case String.split(text, " and ") do
      [h] ->
        [h]

      ["which relate respectively to " <> h | t] ->
        String.split(h, ", ")
        |> (&Kernel.++(&1, t)).()

      [h | [t]] ->
        case String.contains?(h, " of ") do
          true ->
            [lead] = Regex.run(~r/.*? of/, h)
            [h, lead <> " " <> t]

          false ->
            String.split(h, ", ")
            |> (&Kernel.++(&1, [t])).()
        end
    end
  end

  defp initial_capitalisation(text) do
    text
    |> String.slice(0..0)
    |> String.upcase()
    |> (&(&1 <> String.slice(text, 1..-1))).()
  end

  defp end_period(fitnesses) do
    # End rule with a period
    Enum.map(fitnesses, fn fitness ->
      fitness
      |> Map.update!(:rule, &String.trim_trailing(&1, "."))
      |> Map.update!(:rule, &(&1 <> "."))
    end)
  end

  @disapplies [
    Regex.compile!(~s/(?:shall|doe?s?) not (?:extend to|apply)/)
  ]

  defp fitness_typer(%{category: "extends-to"} = f), do: f

  defp fitness_typer(%{rule: text} = fitness) do
    # Sets the fitness type based on the RULE text
    Enum.reduce_while(@disapplies, [], fn regex, acc ->
      case Regex.match?(regex, text) do
        true ->
          {:halt, [Map.put(fitness, :category, "disapplies-to") | acc]}

        false ->
          {:cont, acc}
      end
    end)
    |> case do
      [] ->
        fitness
        |> Map.put(:category, "applies-to")

      [h | _] ->
        h
    end
  end

  defp fitness_typer(text) do
    # Sets the fitness type based on the HEADING text
    cond do
      Regex.match?(~r/Extension/, text) ->
        %Fitness{category: "extends-to", heading: heading(text)}

      Regex.match?(~r/[Dd]isapplication/, text) ->
        %Fitness{category: "disapplies-to", heading: heading(text)}

      Regex.match?(~r/Duties [Uu]nder|[Aa]pplication/, text) ->
        %Fitness{category: "applies-to", heading: heading(text)}

      true ->
        false
    end
  end

  defp heading(heading), do: heading |> String.trim() |> String.downcase() |> List.wrap()

  @part_scope [
    Regex.compile!(~s/[Rr]egulations \\d+.*?apply/)
  ]

  defp scope_typer(%{rule: text} = fitness) do
    # Sets the SCOPE type based on the RULE text
    Enum.reduce_while(@part_scope, [], fn regex, acc ->
      case Regex.match?(regex, text) do
        true ->
          fitness =
            fitness
            |> Map.put(:scope, "Part")

          {:halt, [fitness | acc]}

        false ->
          {:cont, acc}
      end
    end)
    |> case do
      [] ->
        fitness
        |> Map.put(:scope, "Whole")

      [h | _] ->
        h
    end
  end

  defp excluded_text?(_), do: false

  defp set_type("Act"), do: :act
  defp set_type(_), do: :regulation
end
