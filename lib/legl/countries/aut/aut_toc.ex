defmodule AUT.TOC do
  @moduledoc """
  Parsing the table of contents sometimes found in AUT law


  """
  import Legl,
    only: [
      content_emoji: 0
      # chapter_emoji: 0,
      # section_emoji: 0,
      # article_emoji: 0,
      # sub_article_emoji: 0,
      # numbered_para_emoji: 0,
      # amendment_emoji: 0,
      # annex_emoji: 0
      # pushpin_emoji: 0
      # no_join_emoji: 0
    ]

  @doc """
  Removes the TOC rather than parsing the contents
  """
  def rm_toc(binary) do
    Regex.replace(
      ~r/^(?:INHALTSVERZEICHNIS|Inhaltsverzeichnis)[\s\S]+^(Text)/mU,
      binary,
      "\\g{1}"
    )
  end

  @doc """
  Extract toc for separate parsing

  """
  def toc?(binary) do
    case Regex.match?(~r/^#{content_emoji()}Inhaltsverzeichnis|^Inhaltsverzeichnis/m, binary) do
      false ->
        {binary, false}

      true ->
        [_, toc] =
          Regex.run(
            ~r/([#{content_emoji()}]?Inhaltsverzeichnis[\s\S]+)Text/,
            binary
          )

        {binary, toc, true}
    end
  end

  @doc false

  def parse_table_of_contents({binary, false}), do: binary

  def parse_table_of_contents({binary, toc, true}) do
    cond do
      Regex.match?(~r/^Inhaltsverzeichnis/m, toc) ->
        Regex.replace(
          ~r/^(Inhaltsverzeichnis)/m,
          toc,
          "#{Legl.content_emoji()}\\g{1}"
        )
        |> (&parse_table_of_contents({binary, &1, true})).()

      # multi line Abschnitt
      # 1. Abschnitt: Heading
      Regex.match?(~r/^#{content_emoji()}.*\n\d+\.[ ]Abschnitt/m, toc) ->
        IO.puts("matching Abschnitt")

        Regex.replace(
          ~r/^(#{content_emoji()}.*\n)(\d+\.[ ]Abschnitt)\n(.*)/m,
          toc,
          "\\g{1}\n#{content_emoji()}\\g{2} \\g{3}"
        )
        |> (&parse_table_of_contents({binary, &1, true})).()

      # put the parsed toc back into binary
      true ->
        Regex.replace(
          ~r/^(Inhaltsverzeichnis[\s\S]+)Text/,
          binary,
          toc
        )
    end
  end

  def mark_up_contentz(binary) do
    cond do
      # single line §
      # § 1. Heading
      Regex.match?(
        ~r/^#{content_emoji()}.*\n§[ ]\d+\.?[ ][[:upper:]ÄÖÜ]/m,
        binary
      ) ->
        Regex.replace(
          ~r/^(#{content_emoji()}.*)\n(§[ ]\d+\.?[ ][[:upper:]ÄÖÜ].*)/m,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2}"
        )
        |> mark_up_contentz()

      # multi line §
      # § 1.
      # Heading
      Regex.match?(
        ~r/^#{content_emoji()}.*\n§[ ]\d+\.\n[[:upper:]ÄÖÜ]/m,
        binary
      ) ->
        Regex.replace(
          ~r/^(#{content_emoji()}.*)\n(§[ ]\d+\.)\n(.*)/m,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2} \\g{3}"
        )
        |> mark_up_contentz()

      # single line Abschnitt
      # 1. Abschnitt: Heading
      Regex.match?(
        ~r/^#{content_emoji()}.*\n\d+\.[ ]Abschnitt:[ ].*/m,
        binary
      ) ->
        Regex.replace(
          ~r/^(#{content_emoji()}.*)\n(\d+\.[ ]Abschnitt:[ ].*)/m,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2}"
        )
        |> mark_up_contentz()

      # single line Anhang
      # Anhang 1: Heading
      Regex.match?(
        ~r/^(#{content_emoji()}.*)\n(Anhang[ ]?\d?:[ ][A-Z])/m,
        binary
      ) ->
        Regex.replace(
          ~r/^(#{content_emoji()}.*)\n(Anhang[ ]?\d?:[ ][A-Z].*)/m,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2}"
        )
        |> mark_up_contentz()

      # twin line Anhang
      # Anhang 1: Heading
      Regex.match?(
        ~r/^(#{content_emoji()}.*)\n(Anhang[ ][A-Z]:)\n(.*[a-z])[^,](?!$)/m,
        binary
      ) ->
        Regex.replace(
          ~r/^(#{content_emoji()}.*)\n(Anhang[ ][A-Z]:)\n(.*)/ms,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2} \\g{3}"
        )
        |> mark_up_contentz()

      # multi line Anhang
      # Anhang 1: Heading
      Regex.match?(
        ~r/^#{content_emoji()}.*\nAnhang[ ][A-Z]:/m,
        binary
      ) ->
        Regex.replace(
          ~r/^(#{content_emoji()}.*)\n(Anhang[ ][A-Z]:.*)\n.*(?<!,)$/ms,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2}"
        )
        |> mark_up_contentz()

      # Inhaltsverzeichnis
      Regex.match?(
        ~r/^(Inhaltsverzeichnis.*|INHALTSVERZEICHNIS.*)/m,
        binary
      ) ->
        Regex.replace(
          ~r/^(Inhaltsverzeichnis.*|INHALTSVERZEICHNIS.*)/m,
          binary,
          "#{content_emoji()}\\g{1}"
        )
        |> mark_up_contentz()

      true ->
        binary
    end
  end

  def mark_up_contents(binary) do
    case Regex.match?(
           ~r/^(#{content_emoji()}[§|\d|Inhaltsverzeichnis|INHALTSVERZEICHNIS].*)\n(§[ ]\d+\.?|Anhang[ ]\d+|\d+\.[ ]Abschnitt.*|Anlage[ ][A-Z]+)\n§/m,
           binary
         ) do
      true ->
        Regex.replace(
          ~r/^(#{content_emoji()}[§|\d|Inhaltsverzeichnis|INHALTSVERZEICHNIS].*)\n(§[ ]\d+\.?|Anhang[ ]\d+|\d+\.[ ]Abschnitt|Anlage[ ][A-Z]+)(.*)/m,
          binary,
          "\\g{1}\n#{content_emoji()}\\g{2} \\g{3}"
        )
        |> mark_up_contents()

      false ->
        case Regex.match?(
               ~r/^(#{content_emoji()}[§|\d|Inhaltsverzeichnis|INHALTSVERZEICHNIS].*)\n(§[ ]\d+\.?|Anhang[ ]\d+|[2-9]+\.[ ]Abschnitt|Anlage[ ][A-Z]+)\n(.*)/m,
               binary
             ) do
          true ->
            Regex.replace(
              ~r/^(#{content_emoji()}[§|\d|Inhaltsverzeichnis|INHALTSVERZEICHNIS].*)\n(§[ ]\d+\.?|Anhang[ ]\d+|[2-9]+\.[ ]Abschnitt|Anlage[ ][A-Z]+)\n(.*)/m,
              binary,
              "\\g{1}\n#{content_emoji()}\\g{2} \\g{3}"
            )
            |> mark_up_contents()

          false ->
            case Regex.match?(
                   ~r/^(#{content_emoji()}[Anlage|Teil].*)\n(?:(Anlage[ ][A-Z]+)\n(.*)|(Teil[ ]\d+:)(.*))/m,
                   binary
                 ) do
              true ->
                Regex.replace(
                  ~r/^(#{content_emoji()}[Anlage|Teil].*)\n(?:(Anlage[ ][A-Z]+)\n(.*)|(Teil[ ]\d+:)(.*))/m,
                  binary,
                  "\\g{1}\n#{content_emoji()}\\g{2}\\g{4} \\g{3}\\g{5}"
                )
                |> mark_up_contents()

              false ->
                binary
            end
        end
    end
  end
end
