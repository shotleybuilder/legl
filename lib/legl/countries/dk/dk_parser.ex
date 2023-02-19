defmodule DK.Parser do
  @components %Types.Component{}
  @approvers ~s(
  Arbejdstilsynet
  Beskæftigelsesministeriet
  Sundhedsministeriet
  Miljøministeriet
  Klima-, Energi- og Forsyningsministeriet
  Givet på Christiansborg Slot
  Færdselsstyrelsen
  Miljø- og Fødevareministeriet
  Søfartsstyrelsen
  Trafik-, Bygge- og Boligstyrelsen
  Transport-, Bygnings- og Boligministeriet
  Miljøstyrelsen
  Erhvervs- og Vækstministeriet
  Ministeriet for Sundhed og Forebyggelse
  Statens Luftfartsvæsen
  Arbejdsministeriet
  Direktoratet for Arbejdstilsynet
  )
  @regex_approvers Enum.join(String.split(@approvers), "|")
  @roman_numerals Regex.replace(~r/[ ]/, Legl.roman(), "|")

  @doc false
  @spec clean_original(String.t()) :: String.t()
  def clean_original("CLEANED\n" <> binary) do
    binary
    |> (&IO.puts("cleaned: #{String.slice(&1, 0, 10)}...")).()

    binary
  end

  def clean_original(binary) do
    binary =
      binary
      |> (&Kernel.<>("CLEANED\n", &1)).()
      |> Legl.Parser.rm_empty_lines()
      |> rm_header()
      |> rm_footer()
      |> Legl.Parser.rm_leading_tabs()

    Legl.txt("clean")
    |> Path.absname()
    |> File.write(binary)

    clean_original(binary)
  end

  def rm_header(binary) do
    Regex.replace(
      ~r/.*?Yderligere oplysninger/s,
      binary,
      ""
    )
  end

  def rm_footer(binary) do
    binary
    |> (&Regex.replace(
          ~r/\nOm\n.*/s,
          &1,
          ""
        )).()
  end

  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> get_annex()
    |> get_notes()
    |> join_annex()
    |> get_chapter()
    |> get_section()
    |> get_article()
    |> get_approval()
    |> join_approval()
    |> Legl.Parser.join()
  end

  def get_chapter(binary) do
    Regex.replace(
      ~r/^Kapitel[ ](\d+)\n(.*)/m,
      binary,
      "#{@components[:chapter]}\\g{1} Kapitel \\g{1} \\g{2}"
    )
  end

  def get_section(binary) do
    Regex.replace(
      ~r/^([^\[].*[a-z]\n)§/m,
      binary,
      "#{@components[:section]} \\g{1}§"
    )
  end

  def get_article(binary) do
    Regex.replace(
      ~r/^§[ ](\d+).*/m,
      binary,
      "#{@components[:article]}\\g{1} \\0"
    )
  end

  def get_approval(binary) do
    Regex.replace(
      ~r/^(#{@regex_approvers}).*/m,
      binary,
      fn m ->
        IO.puts("approval")
        "#{@components[:approval]} #{m}"
      end
    )
  end

  def join_approval(binary) do
    Regex.replace(
      ~r/(\[::approval::\].*)([\s\S]*?)(?=\[::|$)/,
      binary,
      fn _m, a, p ->
        "#{a} #{Legl.Parser.join(p)}\n"
      end
    )
  end

  def get_annex(binary) do
    Regex.replace(
      ~r/^Bilag[ ]?(\d*)\n(.*)/m,
      binary,
      fn
        _m, "", heading -> "#{@components[:annex]}1 Bilag #{heading}"
        _m, number, heading -> "#{@components[:annex]}#{number} Bilag #{number} #{heading}"
      end
    )
    |> (&Regex.replace(
          ~r/^Bilag[ ](#{@roman_numerals})\n(.*)/m,
          &1,
          fn m, n, t ->
            "#{@components[:annex]}#{Legl.conv_roman_numeral(n)} #{m} #{t}"
          end
        )).()
  end

  def join_annex(binary) do
    Regex.replace(
      ~r/(\[::annex::\].*)([\s\S]*?)(?=\[::|$)/,
      binary,
      fn _m, a, p ->
        cond do
          String.length(p) > 5000 ->
            "#{a}\n"

          true ->
            "#{a} #{Legl.Parser.join(p)}\n"
        end
      end
    )
  end

  def get_notes(binary) do
    Regex.replace(
      ~r/^Officielle[ ]noter.*/ms,
      binary,
      fn m ->
        cond do
          String.length(m) > 5000 ->
            "#{@components[:note]} Officielle noter"

          true ->
            "#{@components[:note]} #{m}"
        end
      end
    )
  end
end
