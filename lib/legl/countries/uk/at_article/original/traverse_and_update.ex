defmodule Legl.Countries.Uk.AtArticle.Original.TraverseAndUpdate do
  @moduledoc """
  Functions to Parse HTML of laws returned from legislation.gov.uk
  """
  def traverse_and_update(content) do
    Floki.traverse_and_update(content, fn
      # PART.  Includes a Region
      {"h" <> h, [{"class", "LegPart" <> _c}] = attr, children} when h in ["1", "2", "3"] ->
        txt =
          concat(children, " ")
          |> (&Regex.replace(~r/ /, &1, " ")).()

        # txt =
        #  txt
        #  |> (&Regex.replace(
        #        ~r/^(?:PART|Part)[ ](\d+[A-Z]?)|(?:PART|Part)[ ](X|IX|VIII|VII|VI|V|IV|III|II|I)/,
        #        &1,
        #        fn _, n, rn ->
        #          cn = Legl.conv_roman_numeral(rn)
        #          "[::part::]#{n}#{cn} PART #{n}#{rn}"
        #        end
        #      )).()

        case String.contains?(txt, "[::region::]") do
          true ->
            txt
            |> (&Regex.replace(
                  ~r/^(.*)(\[::region::\][ ].*?)[ ](.*)/,
                  &1,
                  fn _, prt, geo, txt ->
                    IO.puts("#{prt} #{String.upcase(txt)} #{geo}")
                    "#{prt} #{String.upcase(txt)} #{geo}"
                  end
                )).()
            |> (&{"h" <> h, attr, [&1]}).()

          false ->
            txt
            |> (&Regex.replace(
                  ~r/^(.*)[ ](.*)/,
                  &1,
                  fn _, prt, txt ->
                    IO.puts("#{prt} #{String.upcase(txt)}")
                    "#{prt} #{String.upcase(txt)}"
                  end
                )).()
            |> (&{"h" <> h, attr, [&1]}).()
        end

      # Encloses amending clauses
      {"h4", [{"class", "LegPartFirst"}] = attr, children} ->
        concat(children, "")
        |> (&{"h4", attr, [&1]}).()

      {"span", [{"class", "LegExtentRestriction"}, {"title", "Applies to " <> _t}] = attr,
       children} ->
        concat(children, "")
        |> (&{"span", attr, ["[::region::]" <> &1]}).()

      # CHAPTER.  Includes a Region
      {"h" <> h, [{"class", "LegChapter" <> _c}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(
              ~r/^(.*)(\[::region::\][ ].*)/,
              &1,
              fn _, txt, geo ->
                IO.puts("#{String.upcase(txt)} #{geo}")
                "#{String.upcase(txt)} #{geo}"
              end
            )).()
        |> (&{"h" <> h, attr, [&1]}).()

      {"a", [{"class", "LegAnchorID"}, {"id", id}] = attr, children} ->
        id = String.split(id, "-") |> anchorID()

        case id do
          nil ->
            {"a", attr, children}

          {para, sub_para} ->
            {"a", attr, children}

          x when is_binary(x) ->
            {"a", attr, [x]}
        end

      # HEADING

      {"span", [{"class", "LegPblockTitle"}] = attr, children} ->
        concat(children, " ")
        |> (&{"span", attr, ["[::heading::] " <> &1 <> "\r"]}).()

      {"h3" = ele, [{"class", "LegPblock" <> _}] = attr, children} ->
        txt = concat(children, " ")

        case Regex.run(~r/SUB-PART ([A-Z])/, txt) do
          [_, id] ->
            id
            |> String.to_atom()
            |> (&Map.get(Legl.Utility.alphabet_to_numeric_map_base(), &1)).()
            |> Integer.to_string()
            |> (&{ele, attr, [~s/[::chapter::]#{&1} #{txt}\r/]}).()

          nil ->
            txt |> (&{ele, attr, [&1]}).()
        end

      {"h4" = ele, [{"class", "LegPblock" <> _}] = attr, children} ->
        concat(children, " ")
        |> (&{ele, attr, ["[::heading::] " <> &1 <> "\r"]}).()

      {"h" <> h = ele, [{"class", "LegP1GroupTitleFirst"}], children}
      when h in ["1", "2", "3", "4"] ->
        traverse_and_update({ele, [{"class", "LegP1GroupTitle"}], children})

      {"h" <> h = ele, [{"class", "LegP1GroupTitle"}, {"id", _id}], children}
      when h in ["1", "2", "3", "4"] ->
        traverse_and_update({ele, [{"class", "LegP1GroupTitle"}], children})

      {"h" <> h = ele, [{"class", "LegP1GroupTitle"}] = attr, children}
      when h in ["1", "2", "3", "4"] ->
        ("[::heading::]" <> String.trim(concat(children, " ")))
        # 'heading' with no text prefixes region for an article
        |> (&Regex.replace(~r/\[::heading::\][ ]*\[::region::\]/, &1, "[::region::]")).()
        |> (&{ele, attr, [&1]}).()

      # {"h4", [{"class", "LegP1GroupTitle"}] = attr, children} ->
      #  concat(children, "")
      #  |> String.trim()
      #  |> (&{"h4", attr, [&1]}).()

      # AMENDMENT

      {"p", [{"class", "LegAnnotationsGroupHeading"}] = attr, children} ->
        concat(children, "")
        |> amendment_title()
        |> (&{"p", attr, [&1]}).()

      {"div", [{"class", "LegAnnotations"}] = attr, children} ->
        txt = concat(children, "\n")

        (amendment_heading(txt) <> txt)
        |> (&{"div", attr, [&1]}).()

      # {"a", [{"class", "LegCommentaryLink"}, {"href", _href}, {"title", _title}, {"id", _id}], _} ->
      #  nil

      {"div", [{"class", "LegCommentaryItem"}, {"id", "commentary" <> _id}] = attr, children} ->
        txt = concat(children, " ")

        tag =
          cond do
            Regex.match?(~r/^[ ]?C\d+/, txt) ->
              amendment_type(~r/C\d+/, txt, "[::modification::]")

            Regex.match?(~r/^[ ]?F\d+/, txt) ->
              amendment_type(~r/F\d+/, txt, "[::amendment::]")

            Regex.match?(~r/^[ ]?I\d+/, txt) ->
              amendment_type(~r/I\d+/, txt, "[::commencement::]")

            Regex.match?(~r/^[ ]?E\d+/, txt) ->
              amendment_type(~r/E\d+/, txt, "[::extent::]")

            Regex.match?(~r/^[ ]?M\d+/, txt) ->
              amendment_type(~r/M\d+/, txt, "[::marginal_citation::]")

            Regex.match?(~r/^[ ]?P\d+/, txt) ->
              amendment_type(~r/P\d+/, txt, "[::subordinate::]")

            Regex.match?(~r/^[ ]?X\d+/, txt) ->
              amendment_type(~r/X\d+/, txt, "[::editorial::]")

            true ->
              IO.puts("ERROR: amendment_type/1 no matching condition for #{inspect(txt)}")
          end

        if tag != nil, do: {"div", attr, [tag <> " " <> txt]}, else: nil

      # Amendings

      {"h" <> _h = ele, [{"class", "LegP1GroupTitleFirst LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(~r/\[::.*?::\]/m, &1, "")).()
        |> (&{ele, attr, [&1 <> "\r"]}).()

      {"h" <> _h = ele, [{"class", "LegP1GroupTitle LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(~r/\[::.*?::\]/m, &1, "")).()
        |> (&{ele, attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegClearFix LegP2Container LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegClearFix LegP3Container LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegClearFix LegSP2Container LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegP1ParaText LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(~r/\[::.*?::\]/m, &1, "")).()
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegP2ParaText LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegListTextStandard LegLevel3Amend"}] = attr, children} ->
        concat(children, "")
        |> (&{"p", attr, [&1]}).()

      # {"p", [{"class", "LegTextAmend"}] = attr, children} ->
      #  concat(children, "")
      #  |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegAmendingText"}] = attr, children} ->
        concat(children, "")
        |> (&{"span", attr, [&1]}).()

      # {"span", [{"class", "LegDS LegRHS LegP3TextAmend"}] = attr, children} ->
      #  concat(children, "")
      #  |> (&{"span", attr, [&1]}).()

      # LIST ITEM

      {"div", [{"class", "LegListItem"}] = attr, children} ->
        concat(children, " ")
        |> String.replace("\r", "\n")
        |> (&{"div", attr, [&1]}).()

      # P NODE with SPANS

      {"p", [{"class", "LegRHS LegP1Text" <> _}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegRHS LegP2Text"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegRHS LegP3Text" <> _}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegP2Text"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      # CONTENT OF REGS / PARAS
      {"h" <> _h = ele, [{"class", "LegClearFix LegP1Container" <> _}] = attr, children} ->
        concat(children, " ")
        |> (&{ele, attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegP1Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegP2Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegP3Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegP4Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegP5Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"div", [{"id", "Legislation" <> _}] = attr, children} ->
        concat(children, " ")
        |> (&{"div", attr, [&1]}).()

      # NOT SURE

      {"p", [{"class", "LegListTextStandard LegLevel3"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      # IMG

      {"div", [{"id", "fig" <> _fig}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(~r/\[::.*?::\].*?[ ]/, &1, "")).()
        |> (&{"div", attr, [~s/[::figure::]#{&1}/]}).()

      {"a", [{"href", href}, {"target", _target}, {"class", "previewImg"}] = attr, _children} ->
        {"a", attr, ["#{href}"]}

      # TABLE

      # {"div", [{"class", "LegTabular"}, {"id", _id}] = attr, children} ->
      #  concat(children, "\n")
      #  |> (&{"div", attr, ["[::table::]" <> &1]}).()

      {"div", [{"class", "LegClearFix LegTableContainer LegAmend"}] = attr, children} ->
        concat(children, "\n")
        |> (&{"div", attr, [&1]}).()

      {"div", [{"class", "LegClearFix LegTableContainer"}] = attr, children} ->
        concat(children, "\n")
        |> (&{"div", attr, ["[::table::]" <> &1]}).()

      {"tbody", attr, children} ->
        concat(children, "\n")
        |> (&{"tbody", attr, [&1]}).()

      {"thead", attr, children} ->
        concat(children, "\n")
        |> (&{"thead", attr, [&1 <> "\n"]}).()

      {"th", attr, children} ->
        concat(children, " ") |> String.replace("\r", "") |> (&{"th", attr, [&1]}).()

      {"td", attr, children} ->
        concat(children, " ") |> String.replace("\r", "") |> (&{"td", attr, [&1]}).()

      {"tr", attr, children} ->
        concat(children, "\t")
        |> (&{"tr", attr, [&1]}).()

      # NOT YET IN FORCE

      {_ele, [{"class", "LegBlockNotYetInForce"}], _} ->
        nil

      # *********MAIN BODY***********

      # Enacting text

      {"h1", [{"class", "LegNo"}] = attr, children} ->
        concat(children, " ")
        |> (&{"h1", attr, [&1]}).()

      {"div", [{"class", "LegEnactingText"}] = attr, children} ->
        concat(children, " ")
        |> String.replace("\r ", "\n")
        |> String.replace("\n ", "\n")
        |> (&{"div", attr, [&1]}).()

      {"p", [{"class", "LegLongTitleScottish"}] = attr, children} ->
        concat(children, "")
        |> (&{"p", attr, [&1]}).()

      # Regulation

      {"p", [{"class", "LegP1ParaText LegExtentContainer"}, {"id", _}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegP1ParaText"}, {"id", _id}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegP1ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}] = attr, children} ->
        x = String.split(id, "-") |> anchorID()

        concat(children, " ")
        |> (&{"span", attr, [~s/#{x} #{&1}/]}).()

      {"span", [{"class", "LegP1No"}] = attr, children} ->
        txt = concat(children, " ")
        x = Regex.run(~r/\d+[A-Z]*/, txt)

        {"span", attr, [~s/#{x} #{txt}/]}

      # Sub-Section || Sub-Regulation || Sub-Paragraph

      {"p", [{"class", "LegP2ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(
              ~r/(.*?)\(([A-Z]?\d+[A-Z]*)\)(.*)/,
              &1,
              "[::sub::]\\g{2} \\g{1} (\\g{2}) \\g{3}"
            )).()
        |> (&{"p", attr, [&1]}).()

      # {"span", [{"class", "LegDS LegLHS LegP2No"}, {"id", "section-1-1"}], ["(1)"]}
      {"span", [{"class", "LegDS LegLHS LegP2No"}, {"id", id}] = attr, children} ->
        x = String.split(id, "-") |> anchorID()

        concat(children, " ")
        |> (&{"span", attr, [~s/#{x} #{&1}/]}).()

      # {"span", [{"class", "LegDS LegRHS LegP2Text"}] = attr, children} ->
      #  {"span", attr, children}

      # Signed Section

      {"div", [{"class", "LegClearFix LegSignedSection"}] = attr, children} ->
        concat(children, "\n")
        |> String.replace("\r", "\n")
        |> String.replace("\n ", "\n")
        |> (&Kernel.<>("[::signed::]", &1)).()
        |> (&{"div", attr, [&1]}).()

      {"div", [{"class", "LegClearFix LegSignee"}] = attr, children} ->
        concat(children, "\n")
        # SHAPE "Signed by authority of the Secretary of State for Work and
        # Pensions\n Justin Tomlinson\nParliamentary Under Secretary of
        # State,\nDepartment for Work and Pensions\n23rd June 2015"
        |> (&{"div", attr, [&1]}).()

      # **********SCHEDULES**********

      # Schedules
      # Works with SCHEDULE and SCHEDULE 1 ...

      # "SCHEDULES" title
      {"h" <> _h = ele, [{"class", "LegSchedulesTitle"}] = attr, _} ->
        {ele, attr, ["[::annex::]SCHEDULES"]}

      {"h" <> h = ele, [{"class", "LegScheduleFirst"}], children} when h in ["1", "2", "3"] ->
        traverse_and_update({ele, [{"class", "LegSchedule"}], children})

      {"h" <> h = ele, [{"class", "LegSchedule"}] = attr, children} when h in ["1", "2", "3"] ->
        txt = concat(children, " ")

        txt =
          case h do
            x when x in ["1", "2"] ->
              txt
              |> move_region_to_end(upcase: true)
              |> (&Kernel.<>(&1, "\r")).()

            _ ->
              txt
          end

        IO.puts("#{txt}")
        {ele, attr, [txt]}

      {"h4", [{"class", "LegScheduleFirst"}], children} ->
        traverse_and_update({"h4", [{"class", "LegSchedule"}], children})

      {"h4", [{"class", "LegSchedule"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(~r/\[::region::\][ ]?/, &1, "")).()
        |> (&{"p", attr, [&1]}).()

      {"h" <> _h = ele, [{"class", "LegSchedulePblockFirst"}], children} ->
        traverse_and_update([{ele, [{"class", "LegSchedulePblock"}], children}])

      {"h" <> _h = ele, [{"class", "LegSchedulePblock"}] = attr, children} ->
        concat(children, " ")
        |> (&{ele, attr, [&1]}).()

      # Paragraph

      {"p", [{"class", "LegClearFix LegSP1Container LegExtentContainer"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      {"p", [{"class", "LegClearFix LegSP2Container LegExtentContainer"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      {"p", [{"class", "LegClearFix LegSP1Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegSP2Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegSP3Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      {"p", [{"class", "LegClearFix LegSP4Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      # This will find unnumbered paragraphs that need to be concated into the
      # flow, but sometimes ...

      {"p", [{"class", "LegText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegDS LegP1No"}, {"id", id}] = attr, children} ->
        id = String.split(id, "-") |> anchorID()

        concat(children, " ")
        |> (&{"span", attr, [~s/#{id} #{&1}/]}).()

      # Sub-Paragraph

      {"span", [{"class", "LegDS LegSN1No"}, {"id", _id}] = _attr, _children} ->
        nil

      {"span", [{"class", "LegDS LegSN2No"}, {"id", id}] = attr, children} ->
        {para, sub} = String.split(id, "-") |> anchorID()

        concat(children, " ")
        |> (&{"span", attr, [~s/[::paragraph::]#{para}-#{sub} #{para} #{&1}/]}).()

      # Schedule Reference

      {"p", [{"class", "LegArticleRef"}] = attr, children} ->
        concat(children, "")
        |> (&{"p", attr, ["[::sRef::]" <> &1]}).()

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
    |> String.trim(" ")
  end

  defp move_region_to_end(text, opts) do
    case text =~ "[::region::]" do
      true ->
        regex = ~r/^(.*?)[ ](\d+[A-Z]?)[ ](\[::region::\][ ].*?)[ ](.*)/

        text
        |> (&Regex.replace(
              regex,
              &1,
              fn _, type, n, geo, txt ->
                txt = if opts.upcase == true, do: String.upcase(txt), else: txt
                "#{n} #{type} #{n} #{txt} #{geo}"
              end
            )).()

      false ->
        text
    end
  end

  defp amendment_title(text) do
    cond do
      String.contains?(text, "Modifications etc. (not altering text)") == true ->
        "[::modification_heading::]" <> text

      String.contains?(text, "Extent Information") == true ->
        "[::extent_heading::]" <> text

      String.contains?(text, "Commencement Information") == true ->
        "[::commencement_heading::]" <> text

      String.contains?(text, "Textual Amendments") == true ->
        "[::amendment_heading::]" <> text

      String.contains?(text, "Subordinate Legislation") == true ->
        "[::subordinate_heading::]" <> text

      true ->
        IO.puts("ERROR Missed Annotation #{text}")
        text
    end
  end

  defp amendment_type(_, _, "[::marginal_citation::]"), do: nil

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

  defp anchorID(["part", id]) do
    id = if id == "Preliminary", do: "1", else: id

    # Capture Part ID patterns such as VA
    id =
      case String.split_at(id, -1) do
        {"", x} ->
          Legl.conv_roman_numeral(x)

        {n, x} when x in ["A", "B", "C", "D"] ->
          Legl.conv_roman_numeral(n) <> x

        # eg {I, I}, {I, X}, {1, 0}
        {x, y} ->
          Legl.conv_roman_numeral(x <> y)
      end

    ~s/[::part::]#{id}/
  end

  defp anchorID(["part", _, "chapter", id]), do: anchorID(["chapter", id])

  defp anchorID(["chapter", id]) do
    id =
      case String.split(id, "n") do
        ["", y] -> y
        [x, "1"] -> ~s/#{x}-#{1}/
        [x, y] -> ~s/#{x}.#{y}/
        [x] -> x
      end

    id = Legl.Utility.numericalise_ordinal(id)

    id = Legl.conv_alphabetic_classes(id)
    ~s/[::chapter::]#{id}/
  end

  defp anchorID(["section", _, id]) do
    ~s/[::sub_section::]#{id}/
  end

  defp anchorID(["section", id]) do
    id = String.split(id, "_") |> List.first()
    ~s/[::section::]#{id}/
  end

  defp anchorID(["article", id]), do: ~s/[::article::]#{id}/

  defp anchorID(["regulation", ""]), do: nil

  defp anchorID(["regulation", id]) do
    id = String.split(id, "_") |> List.first()

    id =
      case String.split(id, "n") do
        ["", y] -> y
        [x, "1"] -> ~s/#{x}-#{1}/
        [x, y] -> ~s/#{x}.#{y}/
        [x] -> x
      end

    case String.first(id) |> Integer.parse() do
      :error -> nil
      _ -> ~s/[::article::]#{id}/
    end
  end

  # SCHEDULE

  defp anchorID(["schedule", id]) do
    id = Legl.Utility.numericalise_ordinal(id)
    ~s/[::annex::]#{id}/
  end

  defp anchorID(["schedule"]) do
    ~s/[::annex::]1/
  end

  defp anchorID(["schedule", _, "part", ""]), do: nil

  defp anchorID(["schedule", _, "part", id]), do: anchorID(["part", id])

  defp anchorID(["schedule", "part", id]), do: anchorID(["part", id])

  defp anchorID(["schedule", _, "part", _, "chapter", ""]), do: nil

  defp anchorID(["schedule", "part", _, "chapter", ""]), do: nil

  defp anchorID(["schedule", "part", _, "chapter", id]), do: anchorID(["chapter", id])

  defp anchorID(["schedule", _, "part", _, "chapter", id]), do: anchorID(["chapter", id])

  defp anchorID(["schedule", "part", _, "chapter", _, "paragraph", id]),
    do: anchorID(["paragraph", id])

  defp anchorID(["schedule", _, "part", _, "chapter", _, "paragraph", id]),
    do: anchorID(["paragraph", id])

  defp anchorID(["schedule", _, "part", _, "paragraph", id]), do: anchorID(["paragraph", id])

  defp anchorID(["schedule", _, "paragraph", "wrapper" <> id]) do
    id =
      case String.split(id, "n") do
        [x, y] -> ~s/#{x}.#{y}/
        [x] -> x
      end

    case String.first(id) |> Integer.parse() do
      :error -> nil
      _ -> ~s/[::paragraph::]#{id}/
    end
  end

  defp anchorID(["schedule", _, "paragraph", ""]), do: nil

  defp anchorID(["schedule", _, "paragraph", id]), do: anchorID(["paragraph", id])

  defp anchorID(["paragraph", id]) when id in [nil, ""], do: nil

  defp anchorID(["paragraph", id]) do
    id = String.split(id, "_") |> List.first()

    id =
      case String.split(id, "n") do
        [x, _] -> x
        [x] -> x
      end

    case String.first(id) |> Integer.parse() do
      :error -> nil
      _ -> ~s/[::paragraph::]#{id}/
    end
  end

  defp anchorID(["schedule", _, "paragraph", para, sub]), do: {para, sub}
  defp anchorID(_), do: nil
end
