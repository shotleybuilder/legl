defmodule Types.AirtableSchema do
  @moduledoc false
  @type t :: %__MODULE__{
          part: String.t(),
          part_name: String.t(),
          chapter: String.t(),
          chapter_name: String.t(),
          section: String.t(),
          section_name: String.t(),
          heading: String.t(),
          heading_name: String.t(),
          article: String.t(),
          article_name: String.t(),
          sub_article: String.t(),
          sub_article_name: String.t(),
          para: String.t(),
          sub: String.t(),
          annex: String.t(),
          annex_name: String.t(),
          amendment: String.t(),
          amendment_name: String.t(),
          amending_sub_article_name: String.t()
        }
  @enforce_keys [:article, :article_name]
  defstruct part: "",
            part_name: "part",
            chapter: "",
            chapter_name: "chapter",
            section: "",
            section_name: "section",
            heading: "",
            heading_name: "heading",
            article: "",
            article_name: "article",
            sub_article: "",
            sub_article_name: "sub-article",
            para: "",
            sub: "",
            annex: "",
            annex_name: "",
            amendment: "",
            amendment_name: "",
            amending_sub_article_name: ""
end
