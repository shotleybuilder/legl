defmodule Legl.Countries.Uk.AtArticle.Original.AsMade do
  @moduledoc """
  Functions to process Regulations from legislation.gov.uk in their 'as made' form
  """
  @txt ~s[lib/legl/data_files/txt/original.txt] |> Path.absname()
  @ex ~s[lib/legl/data_files/ex/original.ex] |> Path.absname()

  # The original downloaded from leg.gov.uk
  @original ~s[lib/legl/data_files/html/original.html] |> Path.absname()
  # Unwanted HTML Nodes removed from the original
  @snippet ~s[lib/legl/data_files/html/snippet.html] |> Path.absname()

  @main ~s[lib/legl/data_files/html/main.html] |> Path.absname()
  @schedules ~s[lib/legl/data_files/html/schedules.html] |> Path.absname()
  # Processed after changes to the Text
  @processed ~s[lib/legl/data_files/html/processed.html] |> Path.absname()
  def process(document) do
    content =
      case Floki.find(document, "div#content") do
        [] -> document
        content -> content
      end

    File.write(@original, Floki.raw_html(content, pretty: true))

    snippet =
      content
      # Extract the snippet w/o extraneous information
      # <div class="LegSnippet hasBlockAmends" id="viewLegSnippet">
      |> Floki.find("div#viewLegSnippet")
      # Filter out the footnotes
      # <div class="LegFootnotes">
      |> Floki.traverse_and_update(fn
        # rm Footnotes
        {"div", [{"class", "LegFootnotes"}], _child} -> nil
        # rm Explanatory Notes
        {"p", [{"class", "LegExpNote" <> _c}], _child} -> nil
        {"h" <> _h, [{"class", "LegExpNote" <> _c}], _child} -> nil
        {"p", [{"class", "LegCommentText"}], _child} -> nil
        {"a", [{"class", "LegAnchorID"}, {"id", "Legislation-ExNote"}], _child} -> nil
        # Keep all else
        other -> other
      end)
      |> List.first()
      # Filter out the enclosing DIV <div class="LegSnippet hasBlockAmends" id="viewLegSnippet">
      |> Floki.children()

    File.write(@snippet, Floki.raw_html(snippet, pretty: true))

    # Split the HTML between MAIN and SCHEDULE
    main =
      Enum.take_while(snippet, fn x ->
        x != {"a", [{"class", "LegAnchorID"}, {"id", "schedule-1"}], []}
      end)

    # Floki.find(snippet, "div#viewLegSnippet")
    schedules =
      Enum.drop_while(snippet, fn x ->
        x != {"a", [{"class", "LegAnchorID"}, {"id", "schedule-1"}], []}
      end)

    File.write(@main, Floki.raw_html(main, pretty: true))
    File.write(@schedules, Floki.raw_html(schedules, pretty: true))

    main =
      traverse_and_update(main)
      |> traverse_and_update("main")

    schedules =
      traverse_and_update(schedules)
      |> traverse_and_update("schedules")

    processed = main ++ schedules

    # |> IO.inspect()

    File.write(@processed, Floki.raw_html(processed, pretty: true))

    text =
      Floki.text(processed, sep: "\n")
      |> (&Regex.replace(~r/\r/m, &1, "\n")).()
      |> (&Regex.replace(~r/\n{2,}/m, &1, "\n")).()
      |> (&Regex.replace(~r/\(\n\d+\n\)(.*)/m, &1, "\\g{1}")).()
      |> (&Regex.replace(~r/^(\([a-z]+\))\n/m, &1, "\\g{1} ")).()
      |> (&Regex.replace(~r/(?:\.[ ]—|\.—[ ])/m, &1, ".—")).()
      |> (&Regex.replace(~r/\.[  ]{2,}/m, &1, ". ")).()
      |> (&Regex.replace(~r/“[ ]/m, &1, "“")).()
      |> (&Regex.replace(~r/\([ ]\d+[ ]\)/m, &1, "")).()
      |> (&Regex.replace(~r/[ ]”/m, &1, "”")).()
      |> (&Regex.replace(~r/[ ]\./m, &1, "\.")).()
      |> Legl.Parser.rm_empty_lines()
      |> (&Regex.replace(
            ~r/(\[::article::\]|\[::paragraph::\])(\d+[A-Z]?)[ ](\d+[A-Z]?\.—\(1\))/,
            &1,
            "\\g{1}\\g{2}-1 \\g{3}"
          )).()

    File.write(@ex, inspect(snippet, limit: :infinity))

    File.write(@txt, text)
  end

  defp traverse_and_update(content, "main") do
    Floki.traverse_and_update(content, fn
      # Regulation X—(1)
      {"p", [{"class", "LegP1ParaText"}], child} ->
        x = Floki.children({"p", [{"class", "LegP1ParaText"}], child})

        concat(x, " ")
        |> (&{"p", [{"class", "LegP1ParaText"}], [&1]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}], [child]} ->
        x = Regex.run(~r/\d+$/, id)
        {"span", [{"class", "LegP1No"}, {"id", id}], [~s/[::article::]#{x} #{child}/]}

      # Sub-Regulation

      {"p", [{"class", "LegP2ParaText"}], child} ->
        x = Floki.children({"p", [{"class", "LegP2ParaText"}], child})

        [_, n] = Regex.run(~r/^\((\d+[A-Z]?)\)/, List.first(x))

        x = List.replace_at(x, 0, ~s/[::sub_article::]#{n} #{List.first(x)}/)

        {"p", [{"class", "LegP2ParaText"}], x}

      # Signed Section

      {"div", [{"class", "LegClearFix LegSignedSection"}], child} ->
        x = Floki.children({"div", [{"class", "LegSignedSection"}], child})

        concat(x, "")
        |> (&Kernel.<>("[::signed::]", &1)).()
        |> (&{"div", [{"class", "LegClearFix LegSignedSection"}], [&1]}).()

      {"div", [{"class", "LegClearFix LegSignee"}], children} ->
        x = Floki.children({"div", [{"class", "LegClearFix LegSignee"}], children})

        concat(x, "\r")
        |> (&{"div", [{"class", "LegClearFix LegSignee"}], [&1]}).()

      {"div", [{"class", "LegClearFix LegSignatory"}], children} ->
        x = Floki.children({"div", [{"class", "LegClearFix LegSignatory"}], children})

        concat(x, "")
        |> (&{"div", [{"class", "LegClearFix LegSignatory"}], [&1]}).()

      other ->
        other
    end)
  end

  defp traverse_and_update(content, "schedules") do
    Floki.traverse_and_update(content, fn
      # Paragraph

      {"p", [{"class", "LegP1ParaText"}], child} ->
        x = Floki.children({"p", [{"class", "LegP1ParaText"}], child})

        concat(x, " ")
        |> (&{"p", [{"class", "LegP1ParaText"}], [&1]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}], [child]} ->
        x = Regex.run(~r/\d+$/, id)
        {"span", [{"class", "LegP1No"}, {"id", id}], [~s/[::paragraph::]#{x} #{child}/]}

      # Sub-Paragraph

      {"p", [{"class", "LegP2ParaText"}], child} ->
        x = Floki.children({"p", [{"class", "LegP2ParaText"}], child})

        [_, n] = Regex.run(~r/^\((\d+[A-Z]?)\)/, List.first(x))

        x = List.replace_at(x, 0, ~s/[::sub_paragraph::]#{n} #{List.first(x)}/)

        {"p", [{"class", "LegP2ParaText"}], x}

      # Schedule Reference

      {"p", [{"class", "LegArticleRef"}], [child]} ->
        {"p", [{"class", "LegArticleRef"}], [~s/\r#{child}\r/]}

      # Schedules

      {"h" <> h, [{"class", "LegSchedule" <> c}], child} ->
        x = Floki.children({"h" <> h, [{"class", "LegSchedule" <> c}], child})

        concat(x, " ")
        |> (&Kernel.<>("[::annex::]", &1)).()
        |> (&{"h" <> h, [{"class", "LegSchedule" <> c}], [&1 <> "\r"]}).()

      {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [child]} ->
        n = Regex.run(~r/\d+$/, child)
        {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [~s/#{n} #{child}/]}

      # Amendings

      {"p", [{"class", "LegClearFix LegP3Container LegAmend"}], child} ->
        x = Floki.children({"p", [{"class", "LegClearFix LegP3Container LegAmend"}], child})

        concat(x, " ")
        |> (&{"p", [{"class", "LegClearFix LegP3Container LegAmend"}], [&1 <> "\r"]}).()

      {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child} ->
        x = Floki.children({"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child})

        concat(x, " ")
        |> (&{"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], [&1 <> "\r"]}).()

      {"p", [{"class", "LegP1ParaText LegAmend"}], child} ->
        x = Floki.children({"p", [{"class", "LegP1ParaText LegAmend"}], child})

        concat(x, " ")
        |> (&{"p", [{"class", "LegP1ParaText LegAmend"}], [&1 <> "\r"]}).()

      {"p", [{"class", "LegP2ParaText LegAmend"}], child} ->
        x = Floki.children({"p", [{"class", "LegP2ParaText LegAmend"}], child})

        concat(x, " ")
        |> (&{"p", [{"class", "LegP2ParaText LegAmend"}], [&1 <> "\r"]}).()

      other ->
        other
    end)
  end

  defp traverse_and_update(content) do
    Floki.traverse_and_update(content, fn
      # PART
      {"h" <> h, [{"class", "LegPart" <> c}], child} ->
        x = Floki.children({"h" <> h, [{"class", "LegPart" <> c}], child})

        concat(x, " ")
        |> (&Kernel.<>("[::part::]", &1)).()
        |> (&{"h" <> h, [{"class", "LegPart" <> c}], [&1 <> "\r"]}).()

      {"span", [{"class", "LegPartNo"}], [child]} ->
        x = Regex.run(~r/\d+$/m, child)
        {"span", [{"class", "LegPartNo"}], ["#{x} #{child}"]}

      # CHAPTER
      {"h" <> h, [{"class", "LegChapter" <> c}], child} ->
        x = Floki.children({"h" <> h, [{"class", "LegChapter" <> c}], child})

        case c do
          "First" ->
            concat(x, " ")
            |> (&Kernel.<>("[::chapter::]1 ", &1)).()
            |> (&{"h" <> h, [{"class", "LegChapter" <> c}], [&1 <> "\r"]}).()

          _ ->
            concat(x, " ")
            |> (&Kernel.<>("[::chapter::]", &1)).()
            |> (&{"h" <> h, [{"class", "LegChapter" <> c}], [&1 <> "\r"]}).()
        end

      {"span", [{"class", "LegChapterNo"}], [child]} ->
        x = Regex.run(~r/\d+$/m, child)
        {"span", [{"class", "LegChapterNo"}], ["#{x} #{child}"]}

      # Heading

      {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child} ->
        {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child}

      {"h" <> h, [{"class", "LegP1GroupTitle" <> c}], [child]} ->
        {"h" <> h, [{"class", "LegP1GroupTitle" <> c}], ["[::heading::]" <> child <> "\r"]}

      # {"a", [{"class", "LegFootnoteRef"}, _, _, _]} -> :delete

      other ->
        other
    end)
  end

  defp concat(children, joiner) do
    Enum.reduce(children, [], fn
      x, acc when is_binary(x) -> [x | acc]
      {_, _, [x]}, acc when is_binary(x) -> [x | acc]
      {_, _, n}, acc when is_list(n) -> concat(n, " ") |> (&[&1 | acc]).()
    end)
    |> Enum.reverse()
    |> Enum.join(joiner)
  end
end
