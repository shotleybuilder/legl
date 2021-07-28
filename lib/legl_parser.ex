defmodule Legl.Parser do
  @moduledoc false

  @emojis Legl.named_emojis()
  @x_join_emojis Legl.emojis()

  @components Legl.components()

  def components_for_regex() do
    Legl.components_for_regex()
  end

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
  """
  def join(binary, country \\ nil)

  def join(binary, "UK") do
    components = Enum.join(components_for_regex(), "|")

    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{components})/mu,
      binary,
      "#{Legl.pushpin_emoji()}"
    )
  end

  def join(binary, _country) do
    components = Enum.join(components_for_regex(), "|")

    Regex.replace(
      ~r/(?:\r\n|\n)(?!#{components})/mu,
      binary,
      " #{Legl.pushpin_emoji()} "
    )
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
