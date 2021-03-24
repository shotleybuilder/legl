defmodule FIN.Parser do
  @moduledoc false

  import Legl,
    only: [
      chapter_emoji: 0,
      # sub_chapter_emoji: 0,
      article_emoji: 0
      # sub_article_emoji: 0,
      # numbered_para_emoji: 0,
      # amendment_emoji: 0,
      # annex_emoji: 0,
      # pushpin_emoji: 0
      # no_join_emoji: 0
    ]

  # Finnish alphabet: Å, å, Ä, ä, Ä, ä

  @spec parser(String.t()) :: String.t()
  def parser(binary) do
    binary
    |> Legl.Parser.rm_empty_lines()
    |> rm_header()
    |> Legl.Parser.rm_footer("Sisällysluettelo")
    |> get_chapter()
    |> get_article()
    |> Legl.Parser.join()
    |> Legl.Parser.rm_tabs()
  end

  def rm_header(binary),
    do:
      Regex.replace(
        ~r/[[:space:][:print:]åäö›®]+^Katso tekijänoikeudellinen huomautus käyttöehdoissa\.\n/m,
        binary,
        ""
      )

  def rm_footer(binary),
    do: Regex.replace(~r/^Sisällysluettelo[\s\S]+/m, binary, "")

  @doc """
  Parse the chapters of Regulations.

  ## Formats
  1 luku
  """
  def get_chapter(binary),
    do:
      Regex.replace(
        ~r/^(\d+[ ]luku.*)\n(.*)/m,
        binary,
        "#{chapter_emoji()}\\g{1} \\g{2}"
      )

  @doc """
  Parse the articles of Regulations.

  ## Formats
  1 §
  """
  def get_article(binary),
    do:
      Regex.replace(
        ~r/^(\d+[ ]§.*)\n(.*)/m,
        binary,
        "#{article_emoji()}\\g{1} \\g{2}"
      )
end
