defmodule Legl.Countries.Uk.LeglFitness.Fitness do
  @moduledoc """
  The applicability and appropriateness of UK-specific legislation.


  """
  alias Legl.Services.Airtable.Get
  alias Legl.Countries.Uk.LeglRegister.Crud.Read
  alias Legl.Countries.Uk.LeglArticle.Article
  alias Legl.Countries.Uk.LeglFitness.SaveFitness

  @type legal_fitness :: %__MODULE__{
          lrt: list(),
          rule: any(),
          heading: any(),
          category: any(),
          subject: any(),
          scope: any(),
          person: any(),
          process: any(),
          place: any()
        }

  # @derive [Enumerable]
  defstruct lrt: [],
            rule: nil,
            heading: nil,
            category: nil,
            subject: nil,
            scope: nil,
            person: nil,
            process: nil,
            place: nil

  @base_id "appq5OQW9bTHC1zO5"
  @table_id "tblJW0DMpRs74CJux"

  @default_opts %{base_id: @base_id, table_id: @table_id}
  @lat_opts %{
    article_workflow_name: :"Original -> Clean -> Parse -> Airtable",
    html?: true,
    pbs?: true,
    country: :uk
  }

  def api_fitness(opts \\ []) do
    opts =
      opts
      |> Enum.into(@default_opts)
      |> Read.api_read_opts()

    Get.get(opts.base_id, opts.table_id, opts)
    |> elem(1)
    |> process_fitness()
  end

  def process_fitness(lrt_records) do
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
        IO.puts(~s/\n#{name} #{title_en}/)

        lat_opts =
          @lat_opts
          |> Map.put(:Name, name)
          |> Map.put(:type, set_type(type_class))

        {fitness_clauses, _} =
          Article.api_article(lat_opts)
          |> elem(1)
          |> filter_fitness_sections()

        lft_records =
          Enum.reduce(fitness_clauses, [], fn
            %{fitness_type: :ext, text: text}, acc ->
              [Legl.Countries.Uk.LeglFitness.ParseExtendsTo.parse_extends_to(text) | acc]

            _, acc ->
              acc
          end)

        Enum.each(lft_records, fn
          lft_record -> SaveFitness.save_fitness_record(record_id, lft_record)
        end)
    end)
  end

  defp extract_fields(%{"id" => id} = record) do
    Map.put(record["fields"], :record_id, id)
  end

  def filter_fitness_sections(records) do
    {fit, rest} =
      Enum.reduce(records, {{[], []}, false}, fn
        %{type: "heading", text: text}, {acc, _} ->
          {acc, fitness_typer(text)}

        %{type: "section", text: text}, {acc, _} ->
          {acc, fitness_typer(text)}

        %{type: type, text: text} = record, {{fit, rest} = acc, fitness_type}
        when type in ["article", "sub-article", "sub-section"] ->
          case excluded_text?(text) do
            true ->
              {acc, fitness_type}

            _ ->
              record =
                Map.put(
                  record,
                  :text,
                  Regex.replace(~r/[ ]?📌/m, text, "\n")
                )

              case fitness_type do
                false ->
                  {{fit, [record | rest]}, fitness_type}

                _ ->
                  record = Map.put(record, :fitness_type, fitness_type)
                  {{[record | fit], rest}, fitness_type}
              end
          end

        _, acc ->
          acc
      end)
      |> elem(0)

    {Enum.reverse(fit), Enum.reverse(rest)}
  end

  defp fitness_typer(text) do
    cond do
      Regex.match?(~r/Duties [Uu]nder/, text) -> :fit
      Regex.match?(~r/[Aa]pplication/, text) -> :fit
      Regex.match?(~r/[Dd]isapplication/, text) -> :disfit
      Regex.match?(~r/Extension/, text) -> :ext
      true -> false
    end
  end

  defp excluded_text?(_), do: false

  defp set_type("Act"), do: :act
  defp set_type(_), do: :regulation
end
