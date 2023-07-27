defmodule Legl.Countries.Uk.AtArticle.Original.Latest do
  alias Legl.Countries.Uk.AtArticle.Original.TraverseAndUpdate, as: TU

  @main ~s[lib/legl/data_files/html/main.html] |> Path.absname()
  @schedules ~s[lib/legl/data_files/html/schedules.html] |> Path.absname()
  @processed ~s[lib/legl/data_files/html/processed.html] |> Path.absname()

  def process(document) do
    IO.write("Legl.Countries.Uk.AtArticle.Original.Latest.process/1")
    #
    # Container DIVs need removing so that we have a flat list of nodes

    # IO.puts("#{Enum.count(Floki.children(Floki.find(document, ".DocContainer")))} .DocContainer")
    # IO.puts("#{Floki.find(document, "div.DocContainer")} div.DocContainer")
    # IO.puts("#{Floki.find(document, "div.DocContainer")}")
    # IO.puts("#{Floki.find(document, "div.DocContainer")}")

    document =
      cond do
        # <div xmlns:atom="http://www.w3.org/2005/Atom" class="DocContainer">
        Floki.find(document, ".DocContainer") != [] ->
          [{_ele, _attr, children}] = Floki.find(document, ".DocContainer")
          children
      end

    # Remove Explantory Notes
    document =
      Enum.take_while(document, fn x ->
        # <a class="LegAnchorID" id="Legislation-ExNote">
        x != {"a", [{"class", "LegAnchorID"}, {"id", "Legislation-ExNote"}], []}
      end)

    # IO.inspect(document, limit: :infinity)

    # Split the HTML between MAIN and SCHEDULE
    main =
      Enum.take_while(document, fn x ->
        schedule_markers(x)
      end)

    # Floki.find(snippet, "div#viewLegSnippet")
    schedules =
      Enum.drop_while(document, fn x ->
        schedule_markers(x)
      end)

    File.write(@main, Floki.raw_html(main, pretty: true))
    File.write(@schedules, Floki.raw_html(schedules, pretty: true))

    main = TU.traverse_and_update(main) |> TU.traverse_and_update(:main)

    schedules = TU.traverse_and_update(schedules) |> TU.traverse_and_update(:schedules)

    # ++ schedules
    processed = main ++ schedules

    File.write(@processed, Floki.raw_html(processed, pretty: true))

    IO.puts("...complete")

    Floki.text(processed, sep: "\n")
  end

  defp schedule_markers(x) do
    # {"a", [{"class", "LegAnchorID"}, {"id", "schedule-1"}], []}
    # <a class="LegAnchorID" id="schedule">
    case x do
      x
      when x in [
             {"a", [{"class", "LegAnchorID"}, {"id", "schedule-1"}], []},
             {"a", [{"class", "LegAnchorID"}, {"id", "schedule"}], []}
           ] ->
        false

      _ ->
        true
    end
  end
end
