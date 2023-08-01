defmodule Types.AirtableSchema do
  @moduledoc false

  @fields [
    :flow,
    :type,
    :part,
    :chapter,
    :section,
    :article,
    :para,
    :sub,
    :text
  ]

  @number_fields [
    :part,
    :chapter,
    :section,
    :article,
    :para,
    :sub
  ]

  @type t :: %__MODULE__{
          country: :atom,
          fields: [],
          number_fields: [],
          title_name: String.t(),
          part: String.t(),
          part_name: String.t(),
          chapter: String.t(),
          chapter_name: String.t(),
          section: String.t(),
          section_name: String.t(),
          sub_section: String.t(),
          sub_section_name: String.t(),
          sub_paragraph: String.t(),
          sub_paragraph_name: String.t(),
          heading: String.t(),
          heading_name: String.t(),
          article: String.t(),
          article_name: String.t(),
          sub_article: String.t(),
          sub_article_name: String.t(),
          para: String.t(),
          para_name: String.t(),
          paragraph: String.t(),
          paragraph_name: String.t(),
          sub: String.t(),
          sub_name: String.t(),
          annex: String.t(),
          annex_name: String.t(),
          amendment: String.t(),
          amendment_name: String.t(),
          modification: String.t(),
          modification_name: String.t(),
          commencement: String.t(),
          commencement_name: String.t(),
          amending_sub_article_name: String.t(),
          form: String.t(),
          form_name: String.t(),
          approval_name: String.t(),
          note: String.t(),
          note_name: String.t(),
          footnote_name: String.t(),
          signed_name: String.t()
        }
  @enforce_keys []
  defstruct country: nil,
            fields: @fields,
            number_fields: @number_fields,
            title_name: "title",
            part: ~s/^(\\d+|[A-Z])[ ](.*)/,
            part_name: "part",
            chapter: ~s/^(\\d+[A-Z]?)[ ](.*)/,
            chapter_name: "chapter",
            section: ~s/^(\\d+[a-zA-Z]*)[ ](.*)/,
            section_name: "section",
            sub_section: ~s/^(\\d+)[ ](.*)/,
            sub_section_name: "sub-section",
            sub_paragraph: ~s/^(\\d+)[ ](.*)/,
            sub_paragraph_name: "sub-paragraph",
            heading: ~s/^(\\d+[a-z]*)[ ](.*)/,
            heading_name: "heading",
            article: "",
            article_name: "article",
            sub_article: "",
            sub_article_name: "sub-article",
            para: ~s/^(\\d+)[ ](.*)/,
            para_name: "article, paragraph",
            paragraph: ~s/^(\\d+[a-zA-Z]*)[ ](.*)/,
            paragraph_name: "paragraph",
            sub: ~s/^(\\d+)_(\\d+)_(\\d+)[ ](.*)/,
            sub_name: "article, paragraph, sub-paragraph",
            annex: ~s/(\\d*)[ ](.*)/,
            annex_name: "annex",
            amendment: "",
            amendment_heading: ~s/.*/,
            amendment_name: "amendment",
            modification: ~s/^([A-Z])(\\d+)(.*)/,
            modification_heading: ~s/.*/,
            modification_name: "modification",
            commencement: ~s/^([A-Z])(\\d+)(.*)/,
            commencement_heading: ~s/.*/,
            commencement_name: "commencement",
            extent: ~s/^([A-Z])(\\d+)(.*)/,
            extent_heading: ~s/.*/,
            extent_name: "extent",
            editorial: ~s/^([A-Z])(\\d+)(.*)/,
            editorial_heading: ~s/.*/,
            editorial_name: "editorial",
            subordinate: ~s/^([A-Z])(\\d+)(.*)/,
            subordinate_heading: ~s/.*/,
            subordinate_name: "subordinate",
            amending_sub_article_name: "",
            form: "",
            form_name: "form",
            approval_name: "approval",
            table: ~s/.*/,
            sub_table: ~s/^(\\d+)[ ](.*)/,
            table_name: "table",
            sub_table_name: "sub-table",
            note: ~s/[ ](.*)/,
            note_name: "note",
            footnote_name: "footnote",
            signed_name: "signed"
end
