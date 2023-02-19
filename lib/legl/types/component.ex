defmodule Types.Component do
  @components ~s(
    title
    content
    part
    chapter
    section
    sub_section
    heading
    article
    sub_article
    para
    sub
    numbered_para
    amendment
    annex
    signed
    footnote
    approval
    forms
    form
    table
    note
  )

  def components, do: @components

  def components_as_list, do: Enum.map(String.split(@components), fn x -> x end)

  _doc = """
  A map of components as atoms

  [:content, :part, :chapter, :section, :heading, :article, :sub_article,
  :numbered_para, :amendment, :annex, :signed, :footnote, :approval, :forms,
  :form]
  """

  @component_keys Enum.map(String.split(@components), fn x -> String.to_atom(x) end)

  _doc = """
  A map of components with annotations

  ["[::content::]", "[::part::]", "[::chapter::]", "[::section::]",
   "[::heading::]", "[::article::]", "[::sub_article::]", "[::numbered_para::]",
   "[::amendment::]", "[::annex::]", "[::signed::]", "[::footnote::]",
   "[::approval::]", "[::forms::]", "[::form::]"]
  """

  @component_tags Enum.map(String.split(@components), fn x -> "[::" <> x <> "::]" end)

  @typedoc """
    The components of a piece of law and the tags used to
    mark-up each component when the law is parsed.

    %Types.Component{
      amendment: "[::amendment::]",
      annex: "[::annex::]",
      approval: "[::approval::]",
      article: "[::article::]",
      chapter: "[::chapter::]",
      content: "[::content::]",
      footnote: "[::footnote::]",
      form: "[::form::]",
      forms: "[::forms::]",
      heading: "[::heading::]",
      note: "[::note::]",
      numbered_para: "[::numbered_para::]",
      para: "[::para::]",
      part: "[::part::]",
      section: "[::section::]",
      signed: "[::signed::]",
      sub: "[::sub::]",
      sub_article: "[::sub_article::]",
      table: "[::table::]",
      title: "[::title::]"
    }
  """
  @type t :: %__MODULE__{
          amendment: String.t(),
          annex: String.t(),
          approval: String.t(),
          article: String.t(),
          chapter: String.t(),
          content: String.t(),
          footnote: String.t(),
          form: String.t(),
          forms: String.t(),
          heading: String.t(),
          note: String.t(),
          numbered_para: String.t(),
          para: String.t(),
          part: String.t(),
          section: String.t(),
          signed: String.t(),
          sub: String.t(),
          sub_article: String.t(),
          table: String.t(),
          title: String.t()
        }

  defstruct Enum.zip(@component_keys, @component_tags)

  @doc """
  Escaped for inclusion in regexes

  ["\\[::content::\\]", "\\[::part::\\]", "\\[::chapter::\\]",
   "\\[::section::\\]", "\\[::heading::\\]", "\\[::article::\\]",
   "\\[::sub_article::\\]", "\\[::numbered_para::\\]", "\\[::amendment::\\]",
   "\\[::annex::\\]", "\\[::signed::\\]", "\\[::footnote::\\]",
   "\\[::approval::\\]", "\\[::forms::\\]", "\\[::form::\\]"]
  """
  def components_for_regex() do
    @component_tags
    |> Enum.map(&Elixir.Regex.escape(&1))
  end

  @doc """
  The components for a Regex "OR" statement.

  "\\[::title::\\]|\\[::content::\\]|\\[::part::\\]|\\[::chapter::\\]|\\[::section::\\]|\\[::heading::\\]|\\[::article::\\]|\\[::sub_article::\\]|\\[::para::\\]|\\[::sub::\\]|\\[::numbered_para::\\]|\\[::amendment::\\]|\\[::annex::\\]|\\[::signed::\\]|\\[::footnote::\\]|\\[::approval::\\]|\\[::forms::\\]|\\[::form::\\]|\\[::table::\\]|\\[::note::\\]"
  """
  def components_for_regex_or() do
    Enum.join(components_for_regex(), "|")
  end

  @doc """
    %{
    amendment: "\\[::amendment::\\]",
    annex: "\\[::annex::\\]",
    approval: "\\[::approval::\\]",
    article: "\\[::article::\\]",
    chapter: "\\[::chapter::\\]",
    content: "\\[::content::\\]",
    footnote: "\\[::footnote::\\]",
    form: "\\[::form::\\]",
    forms: "\\[::forms::\\]",
    heading: "\\[::heading::\\]",
    note: "\\[::note::\\]",
    numbered_para: "\\[::numbered_para::\\]",
    para: "\\[::para::\\]",
    part: "\\[::part::\\]",
    section: "\\[::section::\\]",
    signed: "\\[::signed::\\]",
    sub: "\\[::sub::\\]",
    sub_article: "\\[::sub_article::\\]",
    table: "\\[::table::\\]",
    title: "\\[::title::\\]"
    }
  """
  def mapped_components_for_regex() do
    Enum.zip(@component_keys, components_for_regex())
    |> Enum.reduce(%{}, fn {x, y}, acc -> Map.put(acc, x, y) end)
  end
end
