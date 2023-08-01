defmodule Legl.Countries.Uk.AtArticle.Original.AsMade do
  @moduledoc """
  Functions to process Regulations from legislation.gov.uk in their 'as made' form
  """
  alias Legl.Countries.Uk.AtArticle.Original.TraverseAndUpdate, as: TU

  # Unwanted HTML Nodes removed from the original
  @snippet ~s[lib/legl/data_files/html/snippet.html] |> Path.absname()

  @main ~s[lib/legl/data_files/html/main.html] |> Path.absname()
  @schedules ~s[lib/legl/data_files/html/schedules.html] |> Path.absname()
  # Processed after changes to the Text
  @processed ~s[lib/legl/data_files/html/processed.html] |> Path.absname()
  def process(document) do
    IO.puts("Legl.Countries.Uk.AtArticle.Original.AsMade.process/1")

    document =
      cond do
        # <div xmlns:atom="http://www.w3.org/2005/Atom" class="DocContainer">
        Floki.find(document, ".DocContainer") != [] ->
          [{_ele, _attr, children}] = Floki.find(document, ".DocContainer")
          children

        Floki.find(document, "div#viewLegSnippet") != [] ->
          [{_ele, _attr, children}] = Floki.find(document, "div#viewLegSnippet")
          children
      end

    document =
      document
      # Filter out the footnotes
      # <div class="LegFootnotes">
      |> Floki.traverse_and_update(fn
        # rm Footnotes
        {"div", [{"class", "LegFootnotes"}], _child} -> nil
        # Keep all else
        other -> other
      end)

    # Remove Explantory Notes
    document =
      Enum.take_while(document, fn x ->
        # <a class="LegAnchorID" id="Legislation-ExNote">
        x != {"a", [{"class", "LegAnchorID"}, {"id", "Legislation-ExNote"}], []}
      end)

    File.write(@snippet, Floki.raw_html(document, pretty: true))

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

    main =
      TU.traverse_and_update(main)
      |> TU.traverse_and_update(:main)

    schedules =
      TU.traverse_and_update(schedules)
      |> TU.traverse_and_update(:schedules)

    processed = main ++ schedules

    # |> IO.inspect()

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
