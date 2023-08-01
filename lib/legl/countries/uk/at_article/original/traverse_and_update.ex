defmodule Legl.Countries.Uk.AtArticle.Original.TraverseAndUpdate do
  @moduledoc """
  Functions to Parse HTML of laws returned from legislation.gov.uk
  """
  def traverse_and_update(content) do
    Floki.traverse_and_update(content, fn
      # PART.  Includes a Region
      {"h" <> h, [{"class", "LegPart" <> _c}] = attr, children} ->
        txt =
          concat(children, " ")
          |> (&Regex.replace(~r/ /, &1, " ")).()

        txt =
          txt
          |> (&Regex.replace(
                ~r/^(?:PART|Part)[ ](\d+[A-Z]?)|(?:PART|Part)[ ](X|IX|VIII|VII|VI|V|IV|III|II|I)/,
                &1,
                fn _, n, rn ->
                  cn = Legl.conv_roman_numeral(rn)
                  "[::part::]#{n}#{cn} PART #{n}#{rn}"
                end
              )).()

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

      {"span", [{"class", "LegExtentRestriction"}, {"title", "Applies to " <> _t}] = attr,
       children} ->
        concat(children, "")
        |> (&{"span", attr, ["[::region::] " <> &1]}).()

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

          x when is_binary(x) ->
            {"a", attr, [x]}
        end

      # HEADING

      {"h" <> _h = ele, [{"class", "LegPblock" <> _}] = attr, children} ->
        concat(children, " ")
        |> (&{ele, attr, ["[::heading::] " <> &1 <> "\r"]}).()

      {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}] = attr, child} ->
        {"h" <> h, attr, child}

      {"h" <> _h = ele, [{"class", "LegP1GroupTitle" <> c}] = attr, children} ->
        txt = concat(children, " ")

        cond do
          c == "BelowFirstC1Amend" ->
            txt |> (&{ele, attr, [&1]}).()

          true ->
            txt |> (&{ele, attr, ["[::heading::] " <> &1 <> "\r"]}).()
        end

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

            true ->
              IO.puts("ERROR: amendment_type/1 no matching condition for #{inspect(txt)}")
          end

        if tag != "[::marginal_citation]", do: {"div", attr, [tag <> " " <> txt]}, else: nil

      # Amendings

      {"p", [{"class", "LegClearFix LegP3Container LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"h" <> h, attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegP1ParaText LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"p", [{"class", "LegP2ParaText LegAmend"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1 <> "\r"]}).()

      {"span", [{"class", "LegAmendingText"}] = attr, children} ->
        concat(children, "")
        |> (&{"span", attr, [&1]}).()

      # LIST ITEM

      {"div", [{"class", "LegListItem"}] = attr, children} ->
        concat(children, " ")
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

  def traverse_and_update(content, :main) do
    Floki.traverse_and_update(content, fn
      # Enacting text

      {"h1", [{"class", "LegNo"}] = attr, children} ->
        concat(children, " ")
        |> (&{"h1", attr, [&1]}).()

      {"div", [{"class", "LegEnactingText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"div", attr, [&1]}).()

      {"p", [{"class", "LegLongTitleScottish"}] = attr, children} ->
        concat(children, "")
        |> (&{"p", attr, [&1]}).()

      # Regulation
      {"p", [{"class", "LegP1ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}] = attr, children} ->
        x =
          case Regex.run(~r/(?:regulation-|article-)(\d+[A-Z]*)_?/, id) do
            [_, x] -> x
            _ -> IO.puts("ERROR: t&u :main #{id}")
          end

        concat(children, " ")
        |> (&{"span", attr, [~s/[::article::]#{x} #{&1}/]}).()

      # Sub-Section || Sub-Regulation

      {"p", [{"class", "LegP2ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(
              ~r/(.*?)\((\d+[A-Z]*)\)(.*)/,
              &1,
              "[::sub_article::]\\g{2} \\g{1} \\g{2} \\g{3}"
            )).()
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegDS LegLHS LegP2No"}, {"id", id}] = attr, children} ->
        id = Regex.run(~r/\d[A-Z]?$/, id)

        concat(children, " ")
        |> (&{"span", attr, [~s/[::sub_section::]#{id} #{&1}/]}).()

      # Signed Section

      {"div", [{"class", "LegClearFix LegSignedSection"}] = attr, children} ->
        concat(children, "\n")
        |> (&Kernel.<>("[::signed::]", &1)).()
        |> (&{"div", attr, [&1]}).()

      {"div", [{"class", "LegClearFix LegSignee"}] = attr, children} ->
        concat(children, "\n")
        |> (&{"div", attr, [&1]}).()

      # {"div", [{"class", "LegClearFix LegSignatory"}], children} ->
      #  x = Floki.children({"div", [{"class", "LegClearFix LegSignatory"}], children})
      #
      #  concat(x, "")
      #  |> (&{"div", [{"class", "LegClearFix LegSignatory"}], [&1]}).()

      other ->
        other
    end)
  end

  def traverse_and_update(content, :schedules) do
    Floki.traverse_and_update(content, fn
      # Schedules
      # Works with SCHEDULE and SCHEDULE 1 ...

      {"h" <> h = ele, [{"class", "LegSchedule" <> c}] = attr, children} ->
        txt =
          concat(children, " ")
          |> (&Regex.replace(~r/ /, &1, " ")).()

        txt =
          case h do
            x when x in ["1", "2"] ->
              n =
                case c do
                  "First" ->
                    "1"

                  _ ->
                    [_, x] = Regex.run(~r/(?:SCHEDULE.+?)(\d+[A-Z]?)/, txt)
                    x
                end

              ~s/#{n} #{txt}/
              |> move_region_to_end(upcase: true)
              |> (&Kernel.<>("[::annex::]", &1)).()
              |> (&Kernel.<>(&1, "\r")).()

            _ ->
              txt
          end

        IO.puts("#{txt}")
        {ele, attr, [txt]}

      # Paragraph

      {"p", [{"class", "LegClearFix LegSP1Container LegExtentContainer"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      {"p", [{"class", "LegClearFix LegSP2Container LegExtentContainer"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      {"p", [{"class", "LegClearFix LegSP3Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      {"p", [{"class", "LegClearFix LegSP4Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/#{&1}/]}).()

      {"p", [{"class", "LegP1ParaText LegExtentContainer"}, {"id", _id}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/[::paragraph::]#{&1}/]}).()

      {"p", [{"class", "LegP1ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/[::paragraph::]#{&1}/]}).()

      {"span", [{"class", "LegDS LegP1No"}, {"id", id}] = attr, children} ->
        id = String.split(id, "-") |> anchorID()
        # [_, x] = Regex.run(~r/(?:paragraph-)([\d\.]+[A-Z]*)_?/, id)

        concat(children, " ")
        |> (&{"span", attr, [~s/#{id} #{&1}/]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}] = attr, children} ->
        id = String.split(id, "-") |> anchorID()
        # [_, x] = Regex.run(~r/(?:paragraph-)([\d\.]+[A-Z]*)_?/, id)

        concat(children, " ")
        |> (&{"span", attr, [~s/#{id} #{&1}/]}).()

      {"span", [{"class", "LegP1No"}] = attr, children} ->
        txt = concat(children, " ")
        x = Regex.run(~r/\d+[A-Z]*/, txt)

        {"span", attr, [~s/#{x} #{txt}/]}

      # Sub-Paragraph

      {"p", [{"class", "LegClearFix LegSP2Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"p", [{"class", "LegClearFix LegSP3Container"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegDS LegSN1No"}, {"id", _id}] = _attr, _children} ->
        nil

      {"span", [{"class", "LegDS LegSN2No"}, {"id", id}] = attr, children} ->
        {para, sub} = String.split(id, "-") |> anchorID()

        concat(children, " ")
        |> (&{"span", attr, [~s/[::paragraph::]#{para}-#{sub} #{para} #{&1}/]}).()

      {"span", [{"class", "LegDS LegLHS LegP2No"}, {"id", id}] = attr, children} ->
        {_, sub} = String.split(id, "-") |> anchorID()

        concat(children, " ")
        |> (&{"span", attr, [~s/[::sub_paragraph::]#{sub} #{&1}/]}).()

      {"p", [{"class", "LegP2ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&Regex.replace(
              ~r/^\((\d+[A-Z]?)\)/,
              &1,
              "[::sub_paragraph::]\\g{1} (\\g{1})"
            )).()
        |> (&{"p", attr, [&1]}).()

      # Schedule Reference

      {"p", [{"class", "LegArticleRef"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/\r#{&1}\r/]}).()

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
    upcase: false
  }

  defp move_region_to_end(text, opts \\ []) do
    case text =~ "[::region::]" do
      true ->
        opts = Enum.into(opts, @default_opts)
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

  # defp anchorID(["part", id]), do: ~s/[::part::]#{id}/
  defp anchorID(["part", _, "chapter", id]), do: ~s/[::chapter::]#{id}/
  defp anchorID(["section", id]), do: ~s/[::section::]#{id}/
  defp anchorID(["schedule", _, "paragraph", id]), do: ~s/[::paragraph::]#{id}/
  defp anchorID(["schedule", _, "paragraph", para, sub]), do: {para, sub}
  defp anchorID(_), do: nil
end
