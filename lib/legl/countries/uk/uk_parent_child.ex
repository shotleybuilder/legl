defmodule Legl.Countries.Uk.UkParentChild do

  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Services.Airtable.Records
  alias Legl.Services.LegislationGovUk.RecordEnactingText

  def get_child_process(base_name) do
    with {:ok, recordset} <- get_at_records_with_empty_child(base_name),
      {:ok, recordset} <- get_child_laws_from_leg_gov_uk(recordset),
      {:ok, count } <- make_csv(recordset)
    do
      IO.puts("csv saved with #{count} records")
      :ok
    else
      {:error, error} -> IO.puts("#{error}")
    end
  end

  def get_at_records_with_empty_child(base_name) do
    with(
      {:ok, {base_id, table_id}} <- AtBasesTables.get_base_table_id(base_name),
      params = %{
        base: base_id,
        table: table_id,
        options:
          %{
          fields: ["Name", "Title_EN", "Type", "Year", "Number", "Child of"],
          formula: ~s/{Child of}=""/}
        },
      {:ok, {_, recordset}} <- Records.get_records({[],[]}, params)
    ) do
      IO.puts("Records returned from Airtable")
      IO.inspect(recordset)
      {:ok, recordset}
    else
      {:error, error} -> {:error, error}
    end
  end

  def get_child_laws_from_leg_gov_uk(records) do
    #records =
      Enum.into(records, [],
        fn %{"fields" => %{"Type" => type, "Year" => year, "Number" => number}} = x ->
          path = introduction_path(type, year, number)
          enacting_text =
            case get_parent(path) do
              {:ok, enacting_text} -> enacting_text |> IO.inspect(label: "leg.gov.uk: ")
              {:error, error} ->
                IO.inspect(error, label: "leg.gov.uk: ERROR: ")
                "ERROR #{error}"
            end
          fields = Map.put_new(x["fields"], :enacting_text, enacting_text)
          %{x | "fields" => fields}
          #[x | acc]
      end)
    #{:ok, records}
    |> (&{:ok, &1}).()
  end
  @doc """
    Parses xml containing clauses with the following patterns:

    The Secretary of State, in exercise of the powers conferred by sections 38 and 51(1)
    of the Fisheries Act 2020 <FootnoteRef Ref="f00001"/>, makes the following Regulations.

    The Secretary of State makes the following Order in exercise of the powers conferred by
    regulation 143(1) of the Conservation of Habitats and Species Regulations 2017 <FootnoteRef Ref="f00001"/>
    (“<Term id="term-the-2017-regulations">the 2017 Regulations</Term>”) and section 22(5)(a) of the
    Wildlife and Countryside Act 1981 <FootnoteRef Ref="f00002"/> (“<Term id="term-the-act">the Act</Term>”).

    The key elements being the phrase "conferred by" and the footnote references.
  """
  def get_parent(path) do
    case RecordEnactingText.enacting_text(path) do
      {:ok, :xml, %{enacting_text: text}} ->
        {:ok, text}
      {:ok, :html} -> {:ok, "not found"}
      {:error, _code, error} -> {:error, error}
    end
  end

  def introduction_path(type, year, number) do
     "/#{type}/#{year}/#{number}/introduction/made/data.xml"
  end

  def make_csv(records) do

  end

end
