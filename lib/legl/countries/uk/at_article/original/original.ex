defmodule Legl.Countries.Uk.AtArticle.Original.Original do
  @moduledoc """
  Functions to return the text of legislation from leg.gov.uk to the
  original.txt file and make it available for further processing
  """

  @txt ~s[lib/legl/data_files/txt/original.txt] |> Path.absname()
  @ex ~s[lib/legl/data_files/ex/original.txt] |> Path.absname()
  @html ~s[lib/legl/data_files/html/original.html] |> Path.absname()

  def get(url) do
    with %HTTPoison.Response{
           status_code: 200,
           body: body,
           headers: headers
         } <- HTTPoison.get!(url, [], follow_redirect: true),
         {:ok, document} <- Floki.parse_document(body),
         content <- Floki.find(document, "div#content") do
      {_, content_location} = Enum.find(headers, fn x -> elem(x, 0) == "Content-Location" end)

      case String.contains?(content_location, "made") do
        true -> IO.puts("Redirected")
        _ -> IO.puts("Latest")
      end

      # {_, string} = content(List.first(content), "")

      # IO.inspect(string)

      # {"a", [{"class", "LegFootnoteRef"}, {"href", "#f00015"}, {"title", "Go to footnote 15"}, {"id", "Backf00015"}], ["15"]}
      content =
        Floki.traverse_and_update(content, fn
          # PART
          {"h" <> h, [{"class", "LegPart" <> c}], child} ->
            x = Floki.children({"h" <> h, [{"class", "LegPart" <> c}], child})

            concat(x, " ")
            |> (&{"h" <> h, [{"class", "LegPart" <> c}], [&1 <> "\r"]}).()

          {"span", [{"class", "LegPartNo"}], [child]} ->
            {"span", [{"class", "LegPartNo"}], ["[::part::]" <> child]}

          # CHAPTER
          {"h" <> h, [{"class", "LegChapter" <> c}], child} ->
            x = Floki.children({"h" <> h, [{"class", "LegChapter" <> c}], child})

            case c do
              "First" ->
                concat(x, " ")
                |> (&Kernel.<>("[::chapter::]1 ", &1)).()
                |> (&{"h" <> h, [{"class", "LegChapter" <> c}], [&1]}).()

              _ ->
                concat(x, " ")
                |> (&Kernel.<>("[::chapter::]", &1)).()
                |> (&{"h" <> h, [{"class", "LegChapter" <> c}], [&1]}).()
            end

          {"span", [{"class", "LegChapterNo"}], [child]} ->
            x = Regex.run(~r/\d+$/m, child)
            {"span", [{"class", "LegChapterNo"}], ["#{x} #{child}"]}

          # Regulation X—(1)
          {"p", [{"class", "LegP1ParaText"}], child} ->
            x = Floki.children({"p", [{"class", "LegP1ParaText"}], child})

            concat(x, " ")
            |> (&{"p", [{"class", "LegP1ParaText"}], [&1]}).()

          {"span", [{"class", "LegP1No"}, {"id", id}], [child]} ->
            tag =
              case child do
                "schedule" <> _x -> "[::paragraph::]"
                _ -> "[::regulation::]"
              end

            x = Regex.run(~r/\d+$/, id)
            {"span", [{"class", "LegP1No"}, {"id", id}], [~s/#{tag}#{x}-1 #{child}/]}

          # Sub-Regulation

          {"p", [{"class", "LegP2ParaText"}], child} ->
            x = Floki.children({"p", [{"class", "LegP2ParaText"}], child})

            [_, n] = Regex.run(~r/^\((\d+[A-Z]?)\)/, List.first(x))

            x = List.replace_at(x, 0, ~s/[::sub-regulation::]#{n} #{List.first(x)}/)

            {"p", [{"class", "LegP2ParaText"}], x}

          # Heading

          {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child} ->
            {"h" <> h, [{"class", "LegP1GroupTitleFirst LegAmend"}], child}

          {"h" <> h, [{"class", "LegP1GroupTitle" <> c}], [child]} ->
            {"h" <> h, [{"class", "LegP1GroupTitle" <> c}], ["[::heading::]" <> child]}

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

          # Schedule Reference

          {"p", [{"class", "LegArticleRef"}], [child]} ->
            {"p", [{"class", "LegArticleRef"}], [~s/\r#{child}\r/]}

          # Schedules
          {"h" <> h, [{"class", "LegSchedule" <> c}], child} ->
            x = Floki.children({"h" <> h, [{"class", "LegSchedule" <> c}], child})

            concat(x, " ")
            |> (&Kernel.<>("[::schedule::]", &1)).()
            |> (&{"h" <> h, [{"class", "LegSchedule" <> c}], [&1 <> "\r"]}).()

          {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [child]} ->
            n = Regex.run(~r/\d+$/, child)
            {"span", [{"class", "LegScheduleNo LegHeadingRef"}], [~s/#{n} #{child}/]}

          # {"a", [{"class", "LegFootnoteRef"}, _, _, _]} -> :delete

          other ->
            other
        end)

      # |> IO.inspect()

      text =
        Floki.text(content, sep: "\n")
        |> (&Regex.replace(~r/\(\n\d+\n\)(.*)/m, &1, "\\g{1}")).()
        |> (&Regex.replace(~r/^(\([a-z]+\))\n/m, &1, "\\g{1} ")).()
        |> (&Regex.replace(~r/\.[ ]—/m, &1, ".—")).()
        |> (&Regex.replace(~r/\.[  ]{2,}/m, &1, ". ")).()
        |> (&Regex.replace(~r/(?:\h*\n)/m, &1, "")).()

      File.write(@ex, inspect(content))
      File.write(@html, Floki.raw_html(content, pretty: true))
      File.write(@txt, text)
    else
      %HTTPoison.Error{reason: error} ->
        IO.puts("#{error}")
    end
  end

  def concat(children, joiner) do
    Enum.reduce(children, [], fn
      x, acc when is_binary(x) -> [x | acc]
      {_, _, [x]}, acc when is_binary(x) -> [x | acc]
    end)
    |> Enum.reverse()
    |> Enum.join(joiner)
  end
end
