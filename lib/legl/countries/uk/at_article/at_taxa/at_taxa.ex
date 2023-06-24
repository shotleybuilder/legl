defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxa do
  defstruct [
    :id,
    fields: %{
      ID: "",
      Record_Type: [],
      Text: "",
      Dutyholder: [],
      "Dutyholder Aggregate": [],
      "Duty Type (Script)": [],
      "Duty Type Aggregate (Script)": [],
      "POPIMAR (Script)": [],
      "POPIMAR Aggregate (Script)": []
    }
  ]

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.Dutyholder
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtDutyTypeTaxa.DutyType
  alias Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaPopimar.Popimar

  @at_id "UK_ukpga_1990_43_EPA"

  @default_opts %{
    base_name: "uk_e_environmental_protection",
    table_name: "Articles",
    view: "Taxa",
    at_id: @at_id,
    fields: ["ID", "Record_Type", "Text"],
    filesave?: true
  }

  @path ~s[lib/legl/countries/uk/at_article/at_taxa/taxa_source_records.json]
  @results_path ~s[lib/legl/countries/uk/at_article/at_taxa/records_results.json]

  @workflow_opts %{source: :file}

  def workflow(opts \\ []) do
    opts = Enum.into(opts, @workflow_opts)

    with(
      {:ok, records} <- get(opts.source, opts),
      {:ok, records} <- Dutyholder.process(records, filesave?: false),
      IO.inspect(records),
      {:ok, records} <- Dutyholder.aggregate(records),
      IO.inspect(records),
      {:ok, records, _} <- DutyType.process(records, filesave?: false),
      {:ok, records} <- DutyType.aggregate(records),
      # IO.inspect(records),
      {:ok, records, _} <- Popimar.process(records, filesave?: false),
      {:ok, records} <- Popimar.aggregate(records)
    ) do
      # patch(records)
      records
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def get(source, opts \\ [])

  def get(:file, _) do
    json = @path |> Path.absname() |> File.read!()
    %{records: records} = Jason.decode!(json, keys: :atoms)
    # IO.inspect(records)

    Enum.reduce(records, [], fn record, acc ->
      [struct(%__MODULE__{}, record) | acc]
    end)
    |> (&{:ok, &1}).()

    # {:ok, records}
  end

  def get(:web, opts) do
    opts = Enum.into(opts, @default_opts)

    opts =
      Map.put(
        opts,
        :formula,
        ~s/AND({UK}="#{opts.at_id}", OR({Record_Type}="section", {Record_Type}="sub-section"))/
      )

    with(
      {:ok, {base_id, table_id}} <-
        AtBasesTables.get_base_table_id(opts.base_name, opts.table_name),
      params = %{
        base: base_id,
        table: table_id,
        options: %{
          view: opts.view,
          fields: opts.fields,
          formula: opts.formula
        }
      },
      {:ok, {jsonset, _recordset}} <- Records.get_records({[], []}, params)
    ) do
      if opts.filesave? == true, do: Legl.Utility.save_at_records_to_file(~s/#{jsonset}/, @path)

      %{records: records} = Jason.decode!(jsonset, keys: :atoms)

      # IO.inspect(recordset)

      Enum.reduce(records, [], fn record, acc ->
        [struct(%__MODULE__{}, record) | acc]
      end)
      |> (&{:ok, &1}).()
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def process(records) do
  end

  def aggregate(records) do
  end

  def patch(results) do
  end
end
