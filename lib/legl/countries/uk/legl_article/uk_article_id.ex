defmodule Legl.Countries.Uk.AirtableArticle.UkArticleId do
  @moduledoc """
  Creates the ID (Name, Key) field value and assigns to :id of the record map
  """

  def make_id(%{flow: ""} = r), do: make_id(%{r | flow: "main"})

  def make_id(%{flow: "pre", name: name} = r),
    do: %{r | id: ~s/#{name}#{make_numeric_id(r)}#{region_code(r)}#{annotation_code(r)}/}

  def make_id(%{flow: "main", name: name} = r),
    do: %{r | id: ~s/#{name}_#{make_numeric_id(r)}#{region_code(r)}#{annotation_code(r)}/}

  def make_id(%{flow: "post", name: name} = r),
    do: %{r | id: ~s/#{name}-#{make_numeric_id(r)}#{region_code(r)}#{annotation_code(r)}/}

  def make_id(%{flow: "signed", name: name} = r), do: %{r | id: ~s/#{name}#{region_code(r)}/}

  # Schedules flow name is the number of the schedule
  def make_id(%{flow: flow, name: name} = r),
    do: %{r | id: ~s/#{name}-#{flow}_#{make_numeric_id(r)}#{region_code(r)}#{annotation_code(r)}/}

  defp make_numeric_id(r),
    do: ~s/#{r.part}_#{r.chapter}_#{r.heading}_#{r.section}_#{r.sub_section}_#{r.para}/

  defp region_code(%{region: "U.K."} = _record), do: "_UK"
  defp region_code(%{region: "E+W+S"} = _record), do: "_GB"
  defp region_code(%{region: "E+W+N.I."} = _record), do: "_EWNI"
  defp region_code(%{region: "E+W"} = _record), do: "_EW"
  defp region_code(%{region: "S+N.I."} = _record), do: "_SNI"
  defp region_code(%{region: "E"} = _record), do: "_E"
  defp region_code(%{region: "W"} = _record), do: "_W"
  defp region_code(%{region: "S"} = _record), do: "_S"
  defp region_code(%{region: "N.I."} = _record), do: "_NI"
  defp region_code(_record), do: ""

  defp annotation_code(%{type: ~s/"amendment,heading"/} = _record), do: "_a"
  defp annotation_code(%{type: ~s/"amendment,textual"/, amendment: a} = _record), do: "_ax_" <> a
  defp annotation_code(%{type: ~s/"extent,heading"/} = _record), do: "_e"
  defp annotation_code(%{type: ~s/"extent,content"/, amendment: e} = _record), do: "_ex_" <> e
  defp annotation_code(%{type: ~s/"modification,heading"/} = _record), do: "_m"

  defp annotation_code(%{type: ~s/"modification,content"/, amendment: m} = _record),
    do: "_mx_" <> m

  defp annotation_code(%{type: ~s/"commencement,heading"/} = _record), do: "_c"

  defp annotation_code(%{type: ~s/"commencement,content"/, amendment: c} = _record),
    do: "_cx_" <> c

  defp annotation_code(%{type: ~s/"editorial,heading"/} = _record), do: "_x"

  defp annotation_code(%{type: ~s/"editorial,content"/, amendment: x} = _record),
    do: "_xx_" <> x

  defp annotation_code(%{type: ~s/"subordinate,heading"/} = _record), do: "_p"

  defp annotation_code(%{type: ~s/"subordinate,content"/, amendment: p} = _record),
    do: "_px_" <> p

  defp annotation_code(%{type: "table"} = _record), do: "_tbl"
  defp annotation_code(%{type: ~s/note/} = _record), do: "_nt"

  defp annotation_code(_), do: ""

  @doc """
  dupes is the list of duplicate IDs (as strings)

  Enumerate the record IDs until a match is made with the duplicate ID
  With each match the accumulator (fm_acc) increments by 1
  This is assigned to the equivalent letter and put in the sub_para field
  The ID is regenerated and assigned to the record
  """
  def make_record_duplicates_uniq(dupes, records) when is_list(records) do
    Enum.reduce(dupes, records, fn dupe, acc ->
      refactor_id(dupe, acc)
    end)
  end

  defp refactor_id(dupe, records) when is_list(records) do
    {acc, _} =
      Enum.flat_map_reduce(records, 1, fn record, fm_acc ->
        case dupe == record.id do
          true ->
            n = letter_from_number(fm_acc)
            id = record.id <> "_#{n}"
            record = %{record | sub_para: n, id: id}
            {[record], fm_acc + 1}

          _ ->
            {[record], fm_acc}
        end
      end)

    acc
  end

  defp letter_from_number(number) do
    alpha = Legl.Utility.alphabet_map()
    alpha[:"#{number}"]
  end
end
