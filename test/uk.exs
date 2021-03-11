defmodule UKTest do
  use ExUnit.Case

  describe "rm" do
    test "rm_header/1" do
      hdr = ~s"""
      Skip to main content
      Skip to navigation

      CoronavirusSee Coronavirus legislation
      on legislation.gov.ukGet Coronavirus guidance from GOV.UK
      Get further guidance for Scotland | Wales | Northern Ireland
      Legislation.gov.uk
      Back to full view
      The Acetylene Safety (England and Wales and Scotland) Regulations 2014

      PreviousNext

      Statutory Instruments
      """

      s = UK.rm_header(hdr)
      assert s == "Statutory Instruments\n"
    end

    test "rm_explanatory_note/1" do
      binary = ~s"""
      EXPLANATORY NOTE
      ()
      1. Foo
      2. Bar
      """

      s = UK.rm_explanatory_note(binary)
      assert s == ""
    end
  end

  describe "join_empty_numbered/1" do
    test "removes \n" do
      binary = ~s/(a)\nFoo\n(b)\nBar\n(i)\nFoo\n(ii)\nBar/

      s = UK.join_empty_numbered(binary)
      assert s == "(a) Foo\n(b) Bar\n(i) Foo\n(ii) Bar"
    end
  end

  describe "get_article/1" do
    test "1.  " do
      binary = ~s/para\.\n1.  Name\nPara/
      s = UK.get_article(binary)
      assert s == ~s/para\.\n#{Legl.article_emoji()}1.  Name\nPara/
    end

    test "1.—(1)" do
      binary = ~s/para.\n1.#{<<226, 128, 148>>}(1) Name/
      s = UK.get_article(binary)
      assert s == ~s/para.\n#{Legl.article_emoji()}1.—(1) Name/
    end
  end

  describe "get_sub_article" do
    test "(1) Name" do
      binary = ~s/para.\n(1) Foo\n(2) Bar/
      s = UK.get_sub_article(binary)

      assert s ==
               ~s/para.\n#{Legl.sub_article_emoji()}(1) Foo\n#{Legl.sub_article_emoji()}(2) Bar/
    end
  end

  describe "get_heading/1" do
    test "capture heading" do
      binary = ~s"""
      Heading
      #{Legl.article_emoji()}1. Name-
      (a)
      """

      s = UK.get_heading(binary)
      assert s == ~s/#{Legl.heading_emoji()}1 Heading\n#{Legl.article_emoji()}1. Name-\n(a)\n/
    end

    test "don't capture sentence with period" do
      binary = ~s"""
      Heading.
      #{Legl.article_emoji()}1. Name-
      (a)
      """

      s = UK.get_heading(binary)
      assert s == ~s/Heading.\n#{Legl.article_emoji()}1. Name-\n(a)\n/
    end
  end

  describe "get_schedule/1" do
    test "SCHEDULE 1" do
      binary = ~s/\nSCHEDULE 1Name\n/
      s = UK.get_schedule(binary)
      assert s == ~s/\n#{Legl.annex_emoji()}SCHEDULE 1 Name\n/
    end
  end

  describe "article/2" do
    test "💚1.—(1)" do
      binary = "💚1.—(1) FooBar"
      record = %{type: "", chapter: "", subchapter: "", article: "", para: 0, str: ""}
      s = UK.article(binary, record)

      assert s ==
               %{
                 article: "",
                 chapter: "",
                 para: "1",
                 str: "1.—(1) FooBar",
                 subchapter: "",
                 type: "article, sub-article"
               }
    end

    test "💚1." do
      binary = "💚1. FooBar"
      record = %{type: "", chapter: "", subchapter: "", article: "", para: 0, str: ""}
      s = UK.article(binary, record)

      assert s ==
               %{
                 article: "",
                 chapter: "",
                 para: " ",
                 str: "1. FooBar",
                 subchapter: "",
                 type: "article"
               }
    end
  end

  describe "sub_article/2" do
    test "❤(1) Foobar" do
      binary = ~s/#{Legl.sub_article_emoji()}(1) Foobar/
      record = %{type: "", chapter: "", subchapter: "", article: "", para: 0, str: ""}
      s = UK.sub_article(binary, record)

      assert s ==
               %{
                 article: "",
                 chapter: "",
                 para: "1",
                 str: "(1) Foobar",
                 subchapter: "",
                 type: "sub-article"
               }
    end
  end

  describe "heading/2" do
    test "⭐1 Foobar" do
      binary = ~s/#{Legl.heading_emoji()}1 Foobar/
      record = %{type: "", chapter: "", subchapter: "", article: "", sub: 0, str: ""}
      s = UK.heading(binary, record)

      assert s ==
               %{
                 article: "1",
                 chapter: "",
                 sub: 0,
                 str: "Foobar",
                 subchapter: "",
                 type: "article, article-heading"
               }
    end
  end
end
