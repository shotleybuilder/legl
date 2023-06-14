defmodule Legl.Legl.LeglPrint do
  @airtable_columns [
                      "ID",
                      "UK",
                      "Flow",
                      "Record_Type",
                      "Part",
                      "Chapter",
                      "Heading",
                      "Section||Regulation",
                      "Sub_Section||Sub_Regulation",
                      "Paragraph",
                      "Dupe",
                      "Amendment",
                      "paste_text_here",
                      "Region",
                      "Changes",
                      "ID_QA"
                    ]
                    |> Enum.join(",")

  def to_csv(records, opts) do
    file = open_file(opts)

    Enum.each(records, fn record ->
      copy_to_csv(file, record)
    end)

    File.close(file)
  end

  defp open_file(opts) do
    filename = ~s/airtable_#{Atom.to_string(opts.type)}.csv/

    {:ok, csv} =
      "lib/legl/data_files/csv/#{filename}" |> Path.absname() |> File.open([:utf8, :write])

    IO.puts(
      csv,
      @airtable_columns
    )

    csv
  end

  defp copy_to_csv(
         file,
         %{
           id: id,
           name: name,
           flow: flow,
           type: record_type,
           part: part,
           chapter: chapter,
           heading: heading,
           section: section,
           sub_section: sub_section,
           para: para,
           sub_para: sub_para,
           amendment: amendment,
           region: region,
           text: text,
           changes: changes
         } = _record
       ) do
    changes =
      changes
      |> Enum.reverse()
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()

    [
      id,
      name,
      flow,
      record_type,
      part,
      chapter,
      heading,
      section,
      sub_section,
      para,
      sub_para,
      amendment,
      Legl.Utility.csv_quote_enclosure(text),
      region,
      changes,
      id
    ]
    # |> IO.inspect()
    |> Enum.join(",")
    |> (&IO.puts(file, &1)).()
  end
end
