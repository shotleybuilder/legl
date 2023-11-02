defmodule DE_Article_Type_Conversion do
  defmodule TypeMapping do
    @type_de ~s/
  titel
  eingangsformel
  teil
  kapitel
  abschnitt
  unterabschnitt
  §
  paragraf
  fußnote
  anhang
  §§
  /

    @type_en ~s/
  title
  opening_formula
  part
  chapter
  section
  subsection
  article
  paragraph
  footnote
  annex
  §§
  /

    def type_mapping() do
      Enum.zip(String.split(@type_de), String.split(@type_en))
      |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, v) end)
    end
  end

  @type_mapping __MODULE__.TypeMapping.type_mapping()

  def convert() do
    Legl.txt("types")
    |> Path.absname()
    |> File.read!()
    |> String.split("\n")
    |> converter()

    # |> Legl.copy()
  end

  def converter(types) do
    types
    |> Enum.map(fn x ->
      String.split(x, ", ")
      |> Enum.map(fn x ->
        case x do
          "" -> []
          _ -> @type_mapping[x]
        end
      end)
      |> Enum.join(", ")
    end)
    |> Enum.join("\n")
    |> String.trim_trailing("\n")
  end
end
