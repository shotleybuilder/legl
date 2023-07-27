defmodule Legl.Countries.Uk.AtArticle.Original.TraverseAndUpdate do
  @moduledoc """
  Functions to Parse HTML of laws returned from legislation.gov.uk
  """
  def traverse_and_update(content) do
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

      {"span", [{"class", "LegExtentRestriction"}, {"title", "Applies to " <> _t}] = attr,
       children} ->
        concat(children, "")
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

  def traverse_and_update(content, :main) do
    Floki.traverse_and_update(content, fn
      # Enacting text

      {"div", [{"class", "LegEnactingText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"div", attr, [&1]}).()

      # Regulation
      {"p", [{"class", "LegP1ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [&1]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}] = attr, children} ->
        [_, x] = Regex.run(~r/(?:regulation-)(\d+[A-Z]*)_?/, id)

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

      {"h" <> _h = ele, [{"class", "LegSchedule" <> c}] = attr, children} ->
        txt = concat(children, " ")

        n =
          case c do
            "First" ->
              "1"

            _ ->
              [_, x] = Regex.run(~r/(?:SCHEDULE )(\d+)/, txt)
              x
          end

        IO.puts("#{n} #{txt}")

        ~s/#{n} #{txt}/
        |> move_region_to_end(upcase: true)
        |> (&{ele, attr, ["[::annex::]" <> &1 <> "\r"]}).()

      # {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [child]} ->
      #  n = Regex.run(~r/\d+$/, child)
      #  {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [~s/#{n} #{child}/]}

      # Paragraph

      {"p", [{"class", "LegP1ParaText LegExtentContainer"}, {"id", _id}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/[::paragraph::]#{&1}/]}).()

      {"p", [{"class", "LegP1ParaText"}] = attr, children} ->
        concat(children, " ")
        |> (&{"p", attr, [~s/[::paragraph::]#{&1}/]}).()

      {"span", [{"class", "LegP1No"}, {"id", id}] = attr, children} ->
        [_, x] = Regex.run(~r/(?:paragraph-)(\d+[A-Z]*)_?/, id)

        concat(children, " ")
        |> (&{"span", attr, [~s/#{x} #{&1}/]}).()

      {"span", [{"class", "LegP1No"}] = attr, children} ->
        txt = concat(children, " ")
        x = Regex.run(~r/\d+[A-Z]*/, txt)

        {"span", attr, [~s/#{x} #{txt}/]}

      # Sub-Paragraph

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
