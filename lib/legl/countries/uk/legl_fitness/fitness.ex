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
  alias Legl.Countries.Uk.LeglFitness.Rule
  alias Legl.Countries.Uk.LeglFitness.RuleTransform, as: RT

  @type legal_fitness :: %__MODULE__{
          fit_id: String.t(),
          lrt: list(),
          lfrt: list(),
          rule: struct(),
          pattern: list(),
          category: String.t(),
          ppp: String.t(),
          person: list(),
          person_verb: String.t(),
          person_ii: String.t(),
          person_ii_verb: String.t(),
          process: list(),
          place: list(),
          property: String.t(),
          plant: String.t()
        }

  @derive Jason.Encoder
  defstruct fit_id: nil,
            record_id: nil,
            lrt: [],
            lfrt: [],
            rule: F.Rule.new(),
            category: nil,
            ppp: nil,
            # Multi Selects are array values
            pattern: [],
            person: [],
            process: [],
            place: [],
            # Single Selects are string values
            person_verb: nil,
            person_ii: nil,
            person_ii_verb: nil,
            property: nil,
            plant: nil

  @base_id "app5uSrszIH9LcZKI"
  @table_id "tbl8MeIOVOS9nP8zc"

  @default_opts %{base_id: @base_id, table_id: @table_id, fitness_type: []}
  @lat_opts %{
    article_workflow_name: :"Original -> Clean -> Parse -> Airtable",
    html?: true,
    pbs?: true,
    country: :uk,
    fitness_type: []
  }

  def new(), do: %__MODULE__{}

  @spec lft_fields() :: [String.t()]
  def lft_fields(),
    do:
      Fitness.new()
      |> Map.from_struct()
      |> Map.drop([:record_id, :rule])
      |> Enum.map(fn {k, _v} -> Atom.to_string(k) end)

  def api_fitness(opts \\ [])

  def api_fitness([from_file: true] = opts) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Read.api_read_opts()

    Get.get(opts.base_id, opts.table_id, opts)
    |> elem(1)
    |> Enum.map(&extract_fields(&1))
    |> Enum.map(fn lrt_record ->
      Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))
      # |> elem(1)
      |> process_records(lrt_record)
    end)
  end

  def api_fitness(opts) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Read.api_read_opts()

    Get.get(opts.base_id, opts.table_id, opts)
    |> elem(1)
    |> Enum.map(&extract_fields(&1))
    |> Enum.map(fn lrt_record ->
      get_articles(lrt_record)
      |> process_records(lrt_record)
    end)
  end

  defp process_records(records, lrt_record) do
    records
    |> (&RT.transform_rules(&1)).()
    |> (&make_fitness_structs(&1)).()
    |> (&process_fitnesses(&1)).()
    |> explicit_does_not_extend_outside_gb()
    |> (&save_fitnesses(&1, lrt_record)).()
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

  @spec process_fitnesses([legal_fitness]) :: [legal_fitness]
  def process_fitnesses(fitnesses) do
    Enum.reduce(fitnesses, [], fn
      %{category: category} = fitness, acc when category not in ["", nil] ->
        case F.Parse.api_parse(fitness) do
          [] ->
            acc

          [%{unmatched_fitness: _text}] = fit ->
            acc ++ fit

          [fit] ->
            fit =
              fit
              |> fit_field()
              |> ppp_field()
              |> rule_scope_field()

            acc ++ [fit]
        end

      _, acc ->
        acc
    end)
  end

  @spec explicit_does_not_extend_outside_gb([legal_fitness]) :: [legal_fitness]
  defp explicit_does_not_extend_outside_gb(lft_records) do
    extends_to? =
      Enum.reduce_while(lft_records, false, fn
        %Fitness{category: "extends-to", place: ["outside-gb"]}, _acc -> {:halt, true}
        _, acc -> {:cont, acc}
      end)

    if extends_to? == false,
      do: [F.ParseExtendsTo.does_not_extend_to() | lft_records],
      else: lft_records
  end

  @spec make_fitness_structs([Rule.t()]) :: [legal_fitness]
  def make_fitness_structs(rules) do
    rules
    |> Enum.map(&fitness_typer_disapplies_to/1)
    |> Enum.map(&fitness_typer_applies_to/1)
  end

  @spec fitness_typer_applies_to(Rule.t()) :: legal_fitness | Rule.t()
  defp fitness_typer_applies_to(%Rule{rule: text} = rule) do
    # Sets the fitness type based on the RULE text
    Enum.reduce_while(F.ParseDefs.applies_regex(), rule, fn regex, acc ->
      case Regex.match?(regex, text) do
        true ->
          {:halt, Map.merge(%__MODULE__{}, %{category: "applies-to", rule: rule})}

        false ->
          {:cont, acc}
      end
    end)
  end

  defp fitness_typer_applies_to(f), do: f

  @spec fitness_typer_disapplies_to(Rule.t()) :: legal_fitness | Rule.t()
  defp fitness_typer_disapplies_to(%Rule{rule: text} = rule) do
    # Sets the fitness type based on the RULE text
    Enum.reduce_while(F.ParseDefs.disapplies_regex(), rule, fn regex, acc ->
      case Regex.match?(regex, text) do
        true ->
          {:halt, Map.merge(%__MODULE__{}, %{category: "disapplies-to", rule: rule})}

        false ->
          {:cont, acc}
      end
    end)
  end

  defp fitness_typer_disapplies_to(f), do: f

  @spec save_fitnesses([legal_fitness], map) :: :ok | {:error, String.t(), legal_fitness}
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
          :ok -> save_rule(lft_record)
          :error -> {:error, record_id, lft_record}
        end
    end)
  end

  defp save_rule(lft_record) do
    case F.SaveRule.save_rule(lft_record) do
      :ok -> :ok
      :error -> {:error, lft_record}
    end
  end

  @doc """
  Creates a fitness struct with the given fitness value.

  ## Examples

      iex> fitness = make_fitness_struct(10)
      %Fitness{value: 10}

  """
  def make_fitness_struct(fitness, fitness_struct \\ %Fitness{}) do
    Enum.reduce(fitness, fitness_struct, fn
      {"fit_id", fit_id}, acc ->
        Map.put(acc, :fit_id, fit_id)

      {"record_id", record_id}, acc ->
        Map.put(acc, :record_id, record_id)

      {"lrt", lrt}, acc ->
        Map.put(acc, :lrt, lrt)

      {"rule", rule}, acc ->
        Map.put(acc, :rule, rule)

      {"pattern", pattern}, acc ->
        Map.put(acc, :pattern, pattern)

      {"ppp", ppp}, acc ->
        Map.put(acc, :ppp, ppp)

      # Single Selects
      {"category", category}, acc ->
        Map.put(acc, :category, category)

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

  # defp fitness_typer(%{category: "extends-to"} = f), do: f

  @spec rule_scope_field(legal_fitness) :: legal_fitness
  defp rule_scope_field(%{rule: %{provision_number: provision_number} = rule} = fitness)
       when provision_number in [nil, ""] do
    rule
    |> Map.put(:scope, "Whole")
    |> (&Map.replace!(fitness, :rule, &1)).()
  end

  defp rule_scope_field(fitness) do
    fitness.rule
    |> Map.put(:scope, "Part")
    |> (&Map.replace!(fitness, :rule, &1)).()
  end

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
    |> (&Map.put(fit, :fit_id, &1)).()
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
