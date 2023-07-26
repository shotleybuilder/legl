defmodule Legl.Parser do
  @moduledoc false

  # @emojis Legl.named_emojis()
  # @x_join_emojis Legl.emojis()

  alias Types.Component
  # @components Component.components()

  # def components_for_regex() do
  #  Legl.components_for_regex()
  # end

  def rm_top_line(binary),
    do: Regex.replace(~r/^[ \t]*(?:\r\n|\n)+/, binary, "")

  def rm_empty_lines(binary),
    do:
      Regex.replace(
        ~r/(?:\r\n|\n)+[ \t]*(?:\r\n|\n)+/m,
        binary,
        "\n"
      )

  @doc """
  Join lines unless they are 'marked-up'

  Google translate for Finnish misses some pushpin_emoji.  Therefore,
  these are seperated with spaces

  Regex uses the negative lookahead (?!).
  Matches the line return before the component and replaces with the pushpin emoji.
  """
  def join(binary, country \\ nil)

  def join(binary, "UK") do
    IO.write("Legl.Parser.join/2")

    binary =
      Regex.replace(
        ~r/(?:\r\n|\n)(?!\[::)/m,
        binary,
        "#{Legl.pushpin_emoji()}"
      )

    IO.puts("...complete")
    binary
  end

  def join(binary, _country) do
    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{Component.components_for_regex_or()})/mu,
      binary,
      " #{Legl.pushpin_emoji()} "
    )
    |> (&Regex.replace(
          ~r/\n#{Component.mapped_components_for_regex().table_row}/,
          &1,
          " #{Legl.pushpin_emoji()} "
        )).()
  end

  def rm_leading_tabs(binary),
    do:
      Regex.replace(
        ~r/^[[:blank:]]+/m,
        binary,
        ""
      )

  @doc """
  Remove tabs because this conflicts with Airtables use of tabs to separate into fields
  """
  def rm_tabs(binary),
    do:
      Regex.replace(
        ~r/\t/m,
        binary,
        "     "
      )

  @doc """
  Removes two or more underline characters

  Underline is used to make underlines in text docs
  """
  def rm_underline_characters(binary) do
    Regex.replace(~r/_{3,}/m, binary, "__")
  end

  @doc """
  Removes everything after and including the `term` that appears at the beginning of a line
  """
  def rm_footer(binary, term),
    do: Regex.replace(~r/^#{term}[\s\S]+/m, binary, "")
end
