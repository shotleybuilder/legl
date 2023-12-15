defmodule Legl.Countries.Uk.AtArticle.Models do
  @moduledoc """
  Functions to store data models for Articles
  """

  @record_type ~w[
    title
    part
    chapter
    section
    sub-section
    heading
    article
    sub-article
    para
    signed
    schedule
    amendment
    textual
    modification
    commencement
    extent
    editorial
    content
    annex
    paragraph
  ]
  def record_type, do: @record_type
end
