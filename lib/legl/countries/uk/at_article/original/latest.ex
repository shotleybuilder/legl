defmodule Legl.Countries.Uk.AtArticle.Original.Latest do
  @txt ~s[lib/legl/data_files/txt/original.txt] |> Path.absname()
  @main ~s[lib/legl/data_files/html/main.html] |> Path.absname()
  @schedules ~s[lib/legl/data_files/html/schedules.html] |> Path.absname()
  @processed ~s[lib/legl/data_files/html/processed.html] |> Path.absname()

  def process(document) do
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

    # There are no Footnotes or Explanantory Notes for the latest versions of Secondary Legislation
    # Split the HTML between MAIN and SCHEDULE

    main =
      Enum.take_while(document, fn x ->
        x != {"a", [{"class", "LegAnchorID"}, {"id", "schedule-1"}], []}
      end)

    # Floki.find(snippet, "div#viewLegSnippet")
    schedules =
      Enum.drop_while(document, fn x ->
        x != {"a", [{"class", "LegAnchorID"}, {"id", "schedule-1"}], []}
      end)

    File.write(@main, Floki.raw_html(main, pretty: true))
    File.write(@schedules, Floki.raw_html(schedules, pretty: true))

    main = traverse_and_update(main) |> traverse_and_update(:main)

    schedules = traverse_and_update(schedules) |> traverse_and_update(:schedules)

    # ++ schedules
    processed = main ++ schedules

    File.write(@processed, Floki.raw_html(processed, pretty: true))

    text =
      Floki.text(processed, sep: "\n")
      # rm <<194, 160>> and replace with space
      |> (&Regex.replace(~r/[ ]+/m, &1, " ")).()
      # rm space before period and other punc marks at end of line
      |> (&Regex.replace(~r/[ ]+([\.\];])$/m, &1, "\\g{1}")).()
      # replace carriage returns
      |> (&Regex.replace(~r/\r/m, &1, "\n")).()
      |> (&Regex.replace(~r/\n{2,}/m, &1, "\n")).()
      # rm space after [::region::]
      |> (&Regex.replace(~r/\[::region::\][ ]/m, &1, "[::region::]")).()
      # rm space after ef bracket
      |> (&Regex.replace(~r/\[[ ]F/m, &1, "[F")).()
      # rm spaces before and after quotes
      |> (&Regex.replace(~r/“[ ]/m, &1, "“")).()
      |> (&Regex.replace(~r/[ ]”/m, &1, "”")).()
      # put in -1 for those articles & paras
      |> (&Regex.replace(
            ~r/(\[::article::\]|\[::paragraph::\])(\d+[A-Z]*)(.*?—.*?\(([A-Z]?1)\))/m,
            &1,
            "\\g{1}\\g{2}-\\g{4}\\g{3}"
          )).()
      # rm spaces before or after sub-para hyphen
      |> (&Regex.replace(~r/(?:\.[ ]—|\.—[ ]+)/m, &1, ".—")).()
      |> (&Regex.replace(~r/\.—[ ]\(/m, &1, ".—(")).()
      # rm multi-spaces
      |> (&Regex.replace(~r/[ ]{2,}/m, &1, " ")).()
      # rm space at end of line
      |> (&Regex.replace(~r/[ ]$/m, &1, "")).()

      # replace £ sign
      |> (&Regex.replace(~r/<<163>>/m, &1, "£")).()

    IO.puts("#{inspect(Regex.scan(~r/fine not exceeding.*?20,000/m, text))}")

    File.write(@txt, text)
  end

  defp traverse_and_update(content, :main) do
    Floki.traverse_and_update(content, fn
      # Regulation
      {"p", [{"class", "LegP1ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}] = attr, children} ->
        x = Regex.run(~r/\d+[A-Z]*$/, id)

        concat(children, " ")
        |> (&{"span", attr, [~s/[::article::]#{x} #{&1}/]}).()

      # Sub-Regulation

      {"p", [{"class", "LegP2ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(
              ~r/(.*?)\((\d+[A-Z]*)\)(.*)/,
              &1,
              "[::sub_article::]\\g{2} \\g{1} \\g{2} \\g{3}"
            )).()
        |> (&{"p", attr, [&1]}).()

      # INTRO TEXT

      {"p", [{"class", "LegText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      # SIGNED SECTION

      {"div", [{"class", "LegClearFix LegSignedSection"}] = attr, children} ->
        concat(children, "\n")
        |> (&Kernel.<>("[::signed::]", &1)).()
        |> (&{"div", attr, [&1]}).()

      {"div", [{"class", "LegClearFix LegSignee"}] = attr, children} ->
        concat(children, "\n")
        |> (&{"div", attr, [&1]}).()

      other ->
        other
    end)
  end

  defp traverse_and_update(content, :schedules) do
    Floki.traverse_and_update(content, fn
      # Schedules

      {"h" <> _h = ele, [{"class", "LegSchedule" <> _c}] = attr, children} ->
        concat(children, " ")
        |> move_region_to_end(prefix: "[::annex::]", upcase: true)
        |> (&{ele, attr, [&1 <> "\r"]}).()

      {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [child]} ->
        n = Regex.run(~r/\d+$/, child)
        {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [~s/#{n} #{child}/]}

      # Paragraph

      {"p", [{"class", "LegP1ParaText LegExtentContainer"}, {"id", _id}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegP1ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}] = attr, children} ->
        x = Regex.run(~r/\d+[A-Z]*$/, id)

        concat(children, " ")
        |> (&{"span", attr, [~s/[::paragraph::]#{x} #{&1}/]}).()

      # Sub-Paragraph

      {"p", [{"class", "LegP2ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(
              ~r/^\((\d+[A-Z]?)\)/,
              &1,
              "[::sub_paragraph::]\\g{1} (\\g{1})"
            )).()
        |> (&{"p", attr, [&1]}).()

      other ->
        other
    end)
  end

  defp traverse_and_update(content) do
    Floki.traverse_and_update(content, fn
      # PART.  Includes a Region
      {"h" <> h, [{"class", "LegPart" <> _c}] = attr, child} ->
        x = Floki.children({"h" <> h, attr, child})

        concat(x, " ")
        |> (&Regex.replace(
              ~r/^PART[ ](\d+[A-Z]?)[ ](\[::region::\][ ].*?)[ ](.*)/,
              &1,
              fn _, n, geo, txt ->
                "[::part::]#{n} PART #{n} #{String.upcase(txt)} #{geo}"
              end
            )).()
        # |> (&Regex.replace(regex, &1, "[::part::]\\g{1} PART \\g{1} \\g{3} \\g{2}")).()
        |> (&{"h" <> h, attr, [&1]}).()

      {"span", [{"class", "LegExtentRestriction"}, {"title", "Applies to "}] = attr, children} ->
        x = Floki.children({"span", attr, children})

        concat(x, "")
        |> (&{"span", attr, ["[::region::] " <> &1]}).()

      # HEADING

      {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child} ->
        {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child}

      {"h" <> _h = ele, [{"class", "LegP1GroupTitle" <> _c}] = attr, children} ->
        concat(children, " ")
        |> (&{ele, attr, ["[::heading::] " <> &1 <> "\r"]}).()

      # AMENDMENT

      {"p", [{"class", "LegAnnotationsGroupHeading"}] = attr, children} ->
        concat(children, "")
        |> amendment_title()
        |> (&{"p", attr, [&1]}).()

      {"div", [{"class", "LegAnnotations"}] = attr, children} ->
        txt = concat(children, "\n")

        (amendment_heading(txt) <> txt)
        |> (&{"div", attr, [&1]}).()

      {"div", [{"class", "LegCommentaryItem"}, {"id", "commentary" <> _id}] = attr, children} ->
        txt = concat(children, " ")
        tag = amendment_type(txt)
        {"div", attr, [tag <> " " <> txt]}

      # LIST ITEM

      {"div", [{"class", "LegListItem"}] = attr, children} ->
        concat(children, " ")
        |> (&{"div", attr, [&1]}).()

      # P NODE with SPANS

      {"p", [{"class", "LegP2Text"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      # CONTENT OF REGS / PARAS

      {"p", [{"class", "LegClearFix LegP3Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegP4Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegP5Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      # NOT SURE

      {"p", [{"class", "LegListTextStandard LegLevel3"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      # IMG

      {"div", [{"id", "fig" <> _fig}] = attr, children} ->
        concat(children, " ")
        |> (&{"div", attr, [&1]}).()

      {"a", [{"href", href}, {"target", _target}, {"class", "previewImg"}] = attr, _children} ->
        {"a", attr, ["#{href}"]}

      # TABLE

      {"div", [{"class", "LegTabular"}, {"id", _id}] = attr, children} ->
        concat(children, "\n")
        |> (&{"div", attr, ["[::table::]" <> &1]}).()

      {"tbody", attr, children} ->
        concat(children, "\n")
        |> (&{"tbody", attr, [&1]}).()

      {"td", attr, children} ->
        concat(children, " ")
        |> (&{"tr", attr, [&1]}).()

      {"tr", attr, children} ->
        concat(children, "\t")
        |> (&{"tr", attr, [&1]}).()

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

  @default_opts %{
    upcase: false,
    prefix: ""
  }

  defp move_region_to_end(text, opts \\ []) do
    opts = Enum.into(opts, @default_opts)
    regex = ~r/^(.*?)[ ](\d+[A-Z]?)[ ](\[::region::\][ ].*?)[ ](.*)/

    text
    |> (&Regex.replace(
          regex,
          &1,
          fn _, type, n, geo, txt ->
            txt = if opts.upcase == true, do: String.upcase(txt), else: txt
            "#{opts.prefix}#{n} #{type} #{n} #{txt} #{geo}"
          end
        )).()
  end

  defp amendment_title(text) do
    cond do
      String.contains?(text, "Modifications etc. (not altering text)") == true ->
        "[::modification_heading]" <> text

      true ->
        text
    end
  end

  defp amendment_type(text) do
    cond do
      Regex.match?(~r/^[ ]?C\d+/, text) ->
        amendment_type(~r/C\d+/, text, "[::modification::]")

      Regex.match?(~r/^[ ]?F\d+/, text) ->
        amendment_type(~r/F\d+/, text, "[::amendment::]")

      Regex.match?(~r/^[ ]?I\d+/, text) ->
        amendment_type(~r/I\d+/, text, "[::commencement::]")

      Regex.match?(~r/^[ ]?E\d+/, text) ->
        amendment_type(~r/E\d+/, text, "[::extent::]")
    end
  end

  defp amendment_type(regex, text, tag) do
    [match] = Regex.run(regex, text)
    tag <> match
  end

  defp amendment_heading(text) do
    cond do
      Regex.match?(~r/^\[::amendment::\]/, text) ->
        "[::amendment_heading::]Amendments\n"

      true ->
        ""
    end
  end
end
