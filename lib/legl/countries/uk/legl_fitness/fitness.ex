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
  alias Legl.Countries.Uk.LeglFitness.FitnessProvisions, as: FP

  @type legal_fitness :: %__MODULE__{
          fit: String.t(),
          lrt: list(),
          rule: String.t(),
          pattern: list(),
          heading: list(),
          category: String.t(),
          scope: String.t(),
          ppp: String.t(),
          provision_number: list(),
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
  defstruct fit: "",
            record_id: nil,
            lrt: [],
            rule: nil,
            category: "",
            scope: nil,
            ppp: "",
            # Multi Selects are array values
            pattern: [],
            heading: [],
            provision_number: [],
            provision: [],
            person: [],
            process: [],
            place: [],
            # Single Selects are string values
            person_verb: nil,
            person_ii: nil,
            person_ii_verb: nil,
            property: nil,
            plant: nil

  @base_id "appq5OQW9bTHC1zO5"
  @table_id "tblJW0DMpRs74CJux"

  @default_opts %{base_id: @base_id, table_id: @table_id, fitness_type: []}
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
    |> Enum.map(&extract_fields(&1))
    |> Enum.map(fn lrt_record ->
      get_articles(lrt_record)
      |> (&transform_articles(&1)).()
      |> (&process_fitnesses(&1, opts.fitness_type)).()
      |> (&save_fitnesses(&1, lrt_record)).()
    end)
  end

  def get_articles(%{
        "Name" => name,
        "Title_EN" => title_en,
        "type_class" => type_class
      }) do
    IO.puts(~s/\nNAME: #{name} #{title_en}/)

    lat_opts =
      @lat_opts
      |> Map.put(:Name, name)
      |> Map.put(:type, set_type(type_class))

    Article.api_article(lat_opts)
    |> elem(1)
    |> tap(
      &Legl.Utility.save_structs_as_json(
        &1,
        Path.absname("lib/legl/data_files/json/parsed.json")
      )
    )
  end

  def process_fitnesses(
        fitnesses,
        fitness_type
      ) do
    # |> IO.inspect(label: "articles")

    # IO.inspect(fitnesses, label: "fitnesses")

    {lft_records, _fit?, _disfit?, _ext?} =
      Enum.reduce(fitnesses, {[], false, false, false}, fn
        %{category: "applies-to"} = fitness, {acc, fit?, disfit?, ext?} ->
          case :fit not in fitness_type do
            true ->
              case F.Parse.api_parse(fitness) do
                [] ->
                  {acc, fit?, disfit?, ext?}

                [%{unmatched_fitness: _text}] = fit ->
                  {acc ++ fit, fit?, disfit?, ext?}

                fit ->
                  fit =
                    fit
                    |> fit_field()
                    |> ppp_field()

                  {acc ++ fit, true, disfit?, ext?}
              end

            false ->
              {acc, fit?, disfit?, ext?}
          end

        %{category: "disapplies-to"} = fitness, {acc, fit?, disfit?, ext?} ->
          case :disfit not in fitness_type do
            true ->
              case F.Parse.api_parse(fitness) do
                [] ->
                  {acc, fit?, disfit?, ext?}

                [%{unmatched_fitness: _text}] = disfit ->
                  {acc ++ disfit, fit?, disfit?, ext?}

                disfit ->
                  disfit =
                    disfit
                    |> fit_field()
                    |> ppp_field()

                  {acc ++ disfit, fit?, true, ext?}
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

    extends_to? =
      Enum.reduce_while(lft_records, false, fn
        %Fitness{category: "extends-to", place: ["outside-gb"]}, _acc -> {:halt, true}
        _, acc -> {:cont, acc}
      end)

    if extends_to? == false,
      do: [F.ParseExtendsTo.does_not_extend_to() | lft_records],
      else: lft_records
  end

  def save_fitnesses(lft_records, %{
        "Name" => name,
        "record_id" => record_id
      }) do
    Enum.each(lft_records, fn
      %{unmatched_fitness: fitness} ->
        Logger.warning("Unmatched fitness\n#{fitness.category} #{fitness.rule}")

        Path.absname("lib/legl/countries/uk/legl_fitness/unmatched_text.txt")
        |> File.write!(name <> " : " <> fitness.rule <> "\n", [:append])

      %Fitness{} = lft_record ->
        case F.SaveFitness.save_fitness_record(record_id, lft_record) do
          :ok -> :ok
          :error -> {:error, record_id, lft_record}
        end
    end)
  end

  @doc """
  Creates a fitness struct with the given fitness value.

  ## Examples

      iex> fitness = make_fitness_struct(10)
      %Fitness{value: 10}

  """
  def make_fitness_struct(fitness, fitness_struct \\ %Fitness{}) do
    Enum.reduce(fitness, fitness_struct, fn
      {"fit", fit}, acc ->
        Map.put(acc, :fit, fit)

      {"record_id", record_id}, acc ->
        Map.put(acc, :record_id, record_id)

      {"lrt", lrt}, acc ->
        Map.put(acc, :lrt, lrt)

      {"rule", rule}, acc ->
        Map.put(acc, :rule, rule)

      {"pattern", pattern}, acc ->
        Map.put(acc, :pattern, pattern)

      {"heading", heading}, acc ->
        Map.put(acc, :heading, heading)

      {"ppp", ppp}, acc ->
        Map.put(acc, :ppp, ppp)

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
      {"provision_number", provision_number}, acc ->
        Map.put(acc, :provision_number, provision_number)

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

  def transform_articles(records) do
    heading_map = FP.build_heading_map(records)

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
            # IO.inspect(text, label: "text")
            # fitness_children are the secondary rules set in a parent rule
            fitnesses_children =
              text
              |> clean_rule_text()
              # |> IO.inspect(label: "clean_rule_text")
              |> (&Map.put(%{provision: []}, :rule, &1)).()
              |> separate_rules()
              |> clean_rules()
              # |> IO.inspect(label: "fitnesses_children")
              |> FP.api_get_list_of_article_numbers()
              # |> IO.inspect(label: "fitnesses_children_II")
              |> FP.api_get_provision(heading_map)

            # |> IO.inspect(label: "fitnesses_children")

            fitness =
              Enum.map(fitnesses_children, fn fitness_child ->
                fitness_template
                |> Map.merge(fitness_child)
                |> fitness_typer_disapplies_to()
                |> fitness_typer_applies_to()
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

  def clean_rule_text(text) do
    text
    # rm section / article number
    |> (&Regex.replace(~r/.*?([A-Z].*)/, &1, "\\1")).()
    |> (&Regex.replace(~r/[ ]?📌/m, &1, "\n")).()
    |> (&Regex.replace(~r/F\d+[ ]/, &1, "")).()
    |> (&Regex.replace(~r/(?:\[| ?\] ?)/, &1, "")).()
    # Footnote marks
    |> (&Regex.replace(~r/\(fn\d+\) ?/, &1, "")).()
    # Weird punc marks
    |> (&Regex.replace(~r/–/, &1, "—")).()
    |> (&Regex.replace(~r/’/, &1, "'")).()
    |> String.trim()
  end

  defp clean_rules(fitnesses) when is_list(fitnesses),
    do: Enum.map(fitnesses, &clean_rules/1)

  defp clean_rules(%{rule: rule} = fitness) do
    rule
    |> end_period()
    |> (&Regex.replace(~r/_but_/, &1, "but")).()
    # |> such_clause()
    |> (&Map.put(fitness, :rule, &1)).()
  end

  def separate_rules(fitnesses) when is_list(fitnesses) do
    Enum.map(fitnesses, &separate_rules/1)
    |> List.flatten()
    |> Enum.uniq()
  end

  def separate_rules(%{provision: _provision, rule: _rule} = fitness) do
    # IO.inspect(fitness, label: "fitness")

    with [fitness] <- such(fitness),
         [_] <- but(fitness),
         [_] <- split(fitness),
         [_] <- save_that(fitness),
         [fitness] <- as_respects_any(fitness),
         [_] <- except(fitness) do
      [fitness]
    else
      fitnesses ->
        # IO.inspect(fitnesses, label: "fitnesses")
        separate_rules(fitnesses)
    end
  end

  def but(%{rule: rule} = fitness) do
    case String.contains?(rule, " but ") do
      true ->
        but_clause(fitness)

      false ->
        [fitness]
    end
  end

  defp but_clause(%{rule: rule} = fitness) do
    case everything_before_the_rule(rule) do
      [_, subject, rule] ->
        Enum.map(
          String.split(rule, ~r/,? but /, parts: 2),
          fn text ->
            Map.put(fitness, :rule, subject <> " " <> String.trim(text))
            |> parse_regulation_references()
          end
        )

      nil ->
        [fitness]
    end
  end

  def split(%{provision: _provision, rule: rule} = fitness) do
    case String.split(rule, "—\n", parts: 2) do
      # Single rule not broken by a new line
      [_h] ->
        [fitness]

      # Multiple rules with a leader paragraph
      [h | [t]] ->
        case String.split(t, ~r/[^—]\n\([a-z]\) /) do
          [_rule] ->
            {t, tail_qualifier} =
              case Regex.run(~r/\n([^\(].*)$/, t, capture: :all_but_first) do
                [tail_qualifier] ->
                  t = Regex.replace(~r/\n#{tail_qualifier}/, t, "")
                  {t, tail_qualifier}

                nil ->
                  {t, ""}
              end

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
                  |> (&Regex.replace(~r/(?:;|,) o$|(?:;|,) an$/, &1, "")).()
                end)

                # Break apart rules with 'unless' clause. Returns a list of rules
                |> unless()
                |> combine_rules(Map.merge(fitness, %{rule: h}))
                |> tail_qualifier(tail_qualifier)
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
    case String.split(rule, ~r/,? except (?:that )?/, parts: 2) do
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

  def save_that(%{rule: rule} = fitness) do
    case String.match?(
           rule,
           ~r/(?:save|except) that/
         ) do
      true ->
        save_that_clause(fitness)

      false ->
        [fitness]
    end
  end

  defp save_that_clause(%{rule: rule} = fitness) do
    case Regex.named_captures(
           ~r/(?<provision>.*?) (?:shall|does) not apply to a (?<subject>.*?),? (?:save|except) that/,
           rule,
           capture: :all_names
         ) do
      %{"provision" => provision, "subject" => subject} ->
        such_a_subject =
          Regex.run(~r/apply?i?e?s? to (?:any )?such (?:a )?(.*?)[ \.]/, rule,
            capture: :all_but_first
          )

        [defn] =
          Regex.run(~r/#{such_a_subject} (.*)/, subject, capture: :all_but_first)

        # Surround any 'but' in the definition with underscores to avoid it being processed as a 'but' clause
        defn = Regex.replace(~r/but/, defn, "_but_")

        IO.puts(
          ~s/\nrule: #{rule}\nprovision: #{provision}\nsubject: #{subject}\nsuch_a_subject: #{such_a_subject}\ndefn: #{defn}/
        )

        # Split on the 'save that' term.  The head is the main rule, the tail is the exception
        [h, t] = String.split(rule, ~r/,? (?:save|except) that /, parts: 2)

        # Use of 'it' in the exception rule indicates a provision
        t =
          case Regex.match?(~r/apply to it/, t) do
            true ->
              Regex.replace(~r/it/, t, "#{provision}", global: false)

            false ->
              # Rebuild the exception rule
              Regex.replace(~r/to such a #{such_a_subject}/, t, "to a #{such_a_subject} #{defn}")
          end

        [
          Map.put(fitness, :rule, h),
          Map.put(fitness, :rule, t)
        ]
        |> Enum.map(&initial_capitalisation(&1))

      _ ->
        # Logger.error("No 'save that' clause found in rule: #{rule}")
        [fitness]
    end
  end

  def as_respects_any(%{rule: rule} = fitness) do
    case String.match?(rule, ~r/As respects any .*? to (?:any )?such (?:a )?/) do
      true ->
        as_respects_any_clause(fitness)

      false ->
        [fitness]
    end
  end

  defp as_respects_any_clause(%{rule: rule} = fitness) do
    subject =
      Regex.run(~r/apply?i?e?s? to (?:any )?such (?:a )?(.*?)[ \.]/, rule,
        capture: :all_but_first
      )

    # IO.inspect(subject, label: "subject")

    [defn] =
      Regex.run(~r/As respects any #{subject} (.*?) regulation/, rule, capture: :all_but_first)

    # Surround any 'but' in the definition with underscores to avoid it being processed as a 'but' clause
    defn = Regex.replace(~r/but/, defn, "_but_")

    # IO.inspect(defn, label: "defn")

    [_h, t] = String.split(rule, ~r/regulation/, parts: 2)
    # IO.inspect(t, label: "t")
    t =
      "Regulation" <>
        Regex.replace(~r/to (?:any )?such (?:a )?#{subject}/, t, "to a #{subject} #{defn}")

    # IO.inspect(t, label: "t")

    [
      Map.put(fitness, :rule, t)
      # |> parse_regulation_references()
    ]
    |> Enum.map(&initial_capitalisation(&1))

    # |> IO.inspect(label: "as_respects_any_clause")
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

  def parse_regulation_references(fitness), do: fitness

  def parse_regulation_references(%{rule: rule, provision: []} = fitness) do
    # under regulation 5 (information and training) do not extend to persons who
    # Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply

    # Take everything before the rule
    case everything_before_the_rule(rule) do
      [_, refs, rest] ->
        # Regulation headings are in brackets and each stored in the 'provision' field

        case Regex.scan(~r/\(([a-z, ]{3,})\)/, refs, capture: :all_but_first) do
          [] ->
            case Regex.run(~r/(?:Regulation|Regulations) (\d+)/, refs) do
              [_, _ref] ->
                Map.merge(fitness, %{
                  rule: rest |> String.trim() |> initial_capitalisation(),
                  scope: "Part"
                })

              nil ->
                Map.put(fitness, :rule, fitness.rule |> String.trim() |> initial_capitalisation())
            end

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
        Map.put(fitness, :rule, fitness.rule |> String.trim() |> initial_capitalisation())
    end
  end

  def parse_regulation_references(fitness), do: fitness

  defp everything_before_the_rule(rule) do
    Regex.run(
      ~r/(.*?)((?: (?:shall|doe?s?) not| (?:shall|does)|, to the)? (?:extend?t?|apply)[\s\S]*)/,
      rule
    )
  end

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

  defp initial_capitalisation(%{rule: rule} = fitness) do
    Map.put(fitness, :rule, initial_capitalisation(rule))
  end

  defp initial_capitalisation(text) when is_binary(text) do
    text
    |> String.split_at(1)
    |> Tuple.to_list()
    |> then(fn
      [h, t] -> String.upcase(h) <> t
      _ -> text
    end)
  end

  defp initial_capitalisation(text) do
    String.capitalize(text)
  end

  defp tail_qualifier(fitnesses, "") when is_list(fitnesses), do: fitnesses

  defp tail_qualifier(fitnesses, tail_qualifier) when is_list(fitnesses) do
    Enum.map(fitnesses, &tail_qualifier(&1, tail_qualifier))
  end

  defp tail_qualifier(%{rule: rule} = fitness, tail_qualifier) do
    Map.put(fitness, :rule, rule <> " " <> tail_qualifier)
  end

  # End rule with a period
  defp end_period(fitnesses) when is_list(fitnesses) do
    Enum.map(fitnesses, &end_period(&1))
  end

  defp end_period(fitness) when is_map(fitness) do
    Map.update!(fitness, :rule, &end_period/1)
  end

  defp end_period(rule) when is_binary(rule) do
    rule
    |> String.trim_trailing(".")
    |> (&(&1 <> ".")).()
  end

  def such(%{rule: rule} = fitness) do
    case Regex.match?(~r/(?:apply|extend only) to such/, rule) do
      true ->
        such_clause(rule)
        |> (&Map.put(fitness, :rule, &1)).()
        |> List.wrap()

      false ->
        [fitness]
    end
  end

  @doc """
    Function to rewrites a rule to replace a 'such' clause

    #Example
    "in respect of work equipment shall apply to such equipment" ->
    "in respect of work equipment shall apply to work equipment"
  """
  def such_clause(rule) do
    # Find the abbreviated subjects

    case Regex.named_captures(
           ~r/(?:apply|extend only) to such (?:a )?(?<subject1>.*?) (or (?<subject2>.*?) )?/,
           rule
         ) do
      %{"subject1" => s1, "subject2" => s2} ->
        subject = if s2 != "", do: "#{s1} or #{s2}", else: s1
        regex = ~r/(?:any|in respect of)(.*?#{s1}.*?),? shall (?:apply|extend only)/

        clause =
          Regex.run(regex, rule, capture: :all_but_first)
          |> List.first()
          |> String.trim()

        # Logger.info(~s/\nSUCH CLAUSE\nrule: #{rule}\nsubject: #{subject}\nclause: #{clause}/)

        Regex.replace(
          ~r/such (a )?#{subject}/m,
          rule,
          "\\1#{clause}"
        )

      nil ->
        Logger.error("No 'such' clause found in rule: #{rule}")
        rule
    end
  end

  defp fitness_typer_applies_to(%{rule: text, category: ""} = fitness) do
    # Sets the fitness type based on the RULE text
    Enum.reduce_while(Legl.Countries.Uk.LeglFitness.ParseDefs.applies_regex(), fitness, fn regex,
                                                                                           acc ->
      case Regex.match?(regex, text) do
        true ->
          {:halt, Map.put(acc, :category, "applies-to")}

        false ->
          {:cont, acc}
      end
    end)
  end

  defp fitness_typer_applies_to(f), do: f

  defp fitness_typer_disapplies_to(%{rule: text, category: ""} = fitness) do
    # Sets the fitness type based on the RULE text
    Enum.reduce_while(
      Legl.Countries.Uk.LeglFitness.ParseDefs.disapplies_regex(),
      fitness,
      fn regex, acc ->
        case Regex.match?(regex, text) do
          true ->
            {:halt, Map.put(acc, :category, "disapplies-to")}

          false ->
            {:cont, acc}
        end
      end
    )
  end

  defp fitness_typer_disapplies_to(f), do: f

  defp fitness_typer(%{category: "extends-to"} = f), do: f

  defp fitness_typer(text) do
    # Sets the fitness type based on the HEADING text
    # A course first filter that picks rules occuring in 3 different sections:
    # Extension, Disapplication and Duties Under/Application
    cond do
      Regex.match?(~r/Extension/, text) ->
        %Fitness{category: "extends-to", heading: transform_heading(text)}

      Regex.match?(~r/[Dd]isapplication/, text) ->
        %Fitness{heading: transform_heading(text)}

      Regex.match?(~r/Duties [Uu]nder|[Aa]pplication/, text) ->
        %Fitness{heading: transform_heading(text)}

      true ->
        false
    end
  end

  def transform_heading(heading),
    do: heading |> rm_efs() |> String.trim() |> String.downcase() |> List.wrap()

  defp rm_efs(text) do
    text
    |> (&Regex.replace(~r/\[/, &1, "")).()
    |> (&Regex.replace(~r/\]/, &1, "")).()
    |> (&Regex.replace(~r/F\d+/, &1, "")).()
  end

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

  defp fit_field(fit) when is_list(fit) do
    Enum.map(fit, &fit_field/1)
  end

  defp fit_field(%{pattern: pattern} = fit) do
    # Builder for the 'fit' field in AT
    Enum.reduce(pattern, [], fn p, acc ->
      Regex.run(~r/<(.+)>/, p, capture: :all_but_first)
      |> List.first()
      |> String.to_atom()
      |> (&Map.get(fit, &1)).()
      |> case do
        x when is_list(x) -> Enum.join(x, ":") |> (&[&1 | acc]).()
        x -> [x | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.join("|")
    |> (&Kernel.<>(~s/#{fit.category}|/, &1)).()
    |> (&Map.put(fit, :fit, &1)).()
  end

  defp ppp_field(fit) when is_list(fit) do
    Enum.map(fit, &ppp_field/1)
  end

  defp ppp_field(%{pattern: pattern} = fit) do
    # Builder for the 'ppp' field in AT
    Enum.reduce(pattern, [], fn p, acc ->
      Regex.run(~r/<(.+)>/, p, capture: :all_but_first)
      |> List.first()
      |> String.to_atom()
      |> (&Map.get(fit, &1)).()
      |> (&[~s/#{p}: #{inspect(&1)}/ | acc]).()
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> (&Kernel.<>(~s/category: #{fit.category}\n/, &1)).()
    |> (&Map.put(fit, :ppp, &1)).()
  end
end
