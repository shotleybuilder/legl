defmodule NoTest do
  use ExUnit.Case

  describe "Norway.get_chapter/1" do

    test "Kapittel 1" do
      s = Norway.get_chapter( ~s/para.\nKapittel 1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.chapter_emoji()}Kapittel 1. Name\nPara/
    end

    test "Kapittel 1A" do
      s = Norway.get_chapter( ~s/para.\nKapittel 1A. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.chapter_emoji()}Kapittel 1A. Name\nPara/
    end

    test "Kapittel 1 A" do
      s = Norway.get_chapter( ~s/para.\nKapittel 1 A. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.chapter_emoji()}Kapittel 1 A. Name\nPara/
    end

    test "Kap 1." do
      s = Norway.get_chapter( ~s/para.\nKap. 1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.chapter_emoji()}Kap. 1. Name\nPara/
    end

    test "Kap. I." do
      s = Norway.get_chapter( ~s/para.\nKap. I. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.chapter_emoji()}Kap. I. Name\nPara/
    end

    test "Chapter 1" do
      s = Norway.get_chapter( ~s/para.\nChapter 1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.chapter_emoji()}Chapter 1. Name\nPara/
    end

    test "Chapter 1A" do
      s = Norway.get_chapter( ~s/para.\nChapter 1A. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.chapter_emoji()}Chapter 1A. Name\nPara/
    end

    test "Chapter 1A Name with an end period unmatched." do
      s = Norway.get_chapter( ~s/para.\nChapter 1A. Name.\nPara/ )
      assert s == ~s/para.\nChapter 1A. Name.\nPara/
    end
  end

  describe "Norway.get_sub_chapter/1" do

    test "I Name" do
      s = Norway.get_sub_chapter( ~s/para.\nIII. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.sub_chapter_emoji()}III. Name\nPara/
    end

  end

  describe "Norway.get_article/1" do

    test "§ 1. Name" do
      s = Norway.get_article( ~s/para.\n§ 1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.article_emoji()}§ 1. Name\nPara/
    end

    test "§ 1a-1.Name" do
      s = Norway.get_article( ~s/para.\n§ 1a-1.Name\nPara/ )
      assert s == ~s/para.\n#{Legl.article_emoji()}§ 1a-1. Name\nPara/
    end

    test "§ 1-1. Name" do
      s = Norway.get_article( ~s/para.\n§ 1-1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.article_emoji()}§ 1-1. Name\nPara/
    end

    test "§ 1 A-1. Name" do
      s = Norway.get_article( ~s/para.\n§ 1 A-1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.article_emoji()}§ 1 A-1. Name\nPara/
    end

    test "Section 2-3. Name" do
      s = Norway.get_article( ~s/para.\nSection 2-3. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.article_emoji()}Section 2-3. Name\nPara/
    end

    test "Section 2 A-1. Name" do
      s = Norway.get_article( ~s/para.\nSection 2 A-1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.article_emoji()}Section 2 A-1. Name\nPara/
    end

  end

  describe "Norway.get_sub_article/1" do

    test "§ 1 a.Name" do
      s = Norway.get_sub_article( ~s/para.\n§ 1 a.Name\nPara/ )
      assert s == ~s/para.\n#{Legl.sub_article_emoji()}§ 1 a. Name\nPara/
    end

    test "§ 1-1a.Name" do
      s = Norway.get_sub_article( ~s/para.\n§ 1-1a.Name\nPara/ )
      assert s == ~s/para.\n#{Legl.sub_article_emoji()}§ 1-1 a. Name\nPara/
    end

  end

  describe "Norway.get_numbered_paragraph/1" do

    test "(1)" do
      s = Norway.get_numbered_paragraph( ~s/para.\n(1) Name.\nPara/ )
      assert s == ~s/para.\n#{Legl.numbered_para_emoji()}(1) Name.\nPara/
    end

  end

  describe "Norway.get_annex/1" do

    test "Vedlegg 1. Name" do
      s = Norway.get_annex( ~s/para.\nVedlegg 1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.annex_emoji()}Vedlegg 1. Name\nPara/
    end

    test "Vedlegg X. Name" do
      s = Norway.get_annex( ~s/para.\nVedlegg X. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.annex_emoji()}Vedlegg X. Name\nPara/
    end

    test "Vedlegg. 2 Name" do
      s = Norway.get_annex( ~s/para.\nVedlegg. 2 Name\nPara/ )
      assert s == ~s/para.\n#{Legl.annex_emoji()}Vedlegg. 2 Name\nPara/
    end

    test "Vedlegg 1: Name" do
      s = Norway.get_annex( ~s/para.\nVedlegg 1: Name\nPara/ )
      assert s == ~s/para.\n#{Legl.annex_emoji()}Vedlegg 1: Name\nPara/
    end

    test "Annex 1. Name" do
      s = Norway.get_annex( ~s/para.\nAnnex 1. Name\nPara/ )
      assert s == ~s/para.\n#{Legl.annex_emoji()}Annex 1. Name\nPara/
    end

  end

  describe "Norway.remove_empty/1" do

    test "no space" do
      s = Norway.rm_empty( ~s/para.\n\nPara/ )
      assert s == ~s/para.\nPara/
    end

    test "space" do
      s = Norway.rm_empty( ~s/para.\n\t\s\nPara/ )
      assert s == ~s/para.\nPara/
    end

    test "multiple" do
      s = Norway.rm_empty( ~s/para.\n\t\s\n\n\nPara/ )
      assert s == ~s/para.\nPara/
    end

  end

  describe "Norway.join/1" do

    test "ignore chapter" do
      s = Norway.join( ~s/para.\nPara.\n#{Legl.chapter_emoji()}Para/ )
      assert s == ~s/para.#{Legl.pushpin_emoji()}Para.\n#{Legl.chapter_emoji()}Para/
    end

    test "ignore sub-chapter" do
      s = Norway.join( ~s/para.\nPara.\n#{Legl.sub_chapter_emoji()}Para/ )
      assert s == ~s/para.#{Legl.pushpin_emoji()}Para.\n#{Legl.sub_chapter_emoji()}Para/
    end

    test "ignore article" do
      s = Norway.join( ~s/para.\nPara.\n#{Legl.article_emoji()}Para/ )
      assert s == ~s/para.#{Legl.pushpin_emoji()}Para.\n#{Legl.article_emoji()}Para/
    end

    test "ignore sub-article" do
      s = Norway.join( ~s/para.\nPara.\n#{Legl.sub_article_emoji()}Para/ )
      assert s == ~s/para.#{Legl.pushpin_emoji()}Para.\n#{Legl.sub_article_emoji()}Para/
    end

    test "ignore numbered para" do
      s = Norway.join( ~s/para.\nPara.\n#{Legl.numbered_para_emoji()}Para/ )
      assert s == ~s/para.#{Legl.pushpin_emoji()}Para.\n#{Legl.numbered_para_emoji()}Para/
    end

    test "ignore annex" do
      s = Norway.join( ~s/para.\nPara.\n#{Legl.annex_emoji()}Para/ )
      assert s == ~s/para.#{Legl.pushpin_emoji()}Para.\n#{Legl.annex_emoji()}Para/
    end

    test "join amendments" do
      s = Norway.join( ~s/para.\nPara.\n#{Legl.amendment_emoji()}Para/ )
      assert s == ~s/para.#{Legl.pushpin_emoji()}Para.#{Legl.pushpin_emoji()}#{Legl.amendment_emoji()}Para/
    end

    test "join regex" do
      assert Regex.match?(~r/(?:\r\n|\n)(?=#{<<226, 153, 163>>})/m, ~s/\n#{Legl.amendment_emoji()}/) == true
      capture = Regex.replace(~r/(?:\r\n|\n)(?!#{<<226, 153, 163>>})/m, ~s/\n#{Legl.amendment_emoji()}Para/, "#{Legl.pushpin_emoji()}")
      assert capture == <<10, 226, 153, 163, 80, 97, 114, 97>>
      assert capture == "\n#{Legl.amendment_emoji()}Para"
    end

    test "look forward" do
      assert Regex.match?(~r/Jason[ ](?=#{<<87, 111, 111, 100, 114, 117, 102, 102>>})/, "Jason Woodruff") == true
      assert Regex.match?(~r/Jason[ ](?!#{<<240, 159, 135, 179, 240, 159, 135, 180, 239, 184, 143>>})/, "Jason 🇳🇴️") == false
    end

  end

  describe "Norway.schemas/4" do

    test "english" do
      parsed = ~s"""
        Title
        #{Legl.chapter_emoji}Chapter 1 Name
        #{Legl.sub_chapter_emoji}I. Subchapter
        #{Legl.article_emoji}Section 1. Name
        #{Legl.numbered_para_emoji}(1) Name
        #{Legl.annex_emoji()}Annex 1: Name
        """
      assert :ok == Norway.schemas(parsed, nil, false, true)
      txts = File.read!(Legl.txts()) |> String.split("\n", trim: true)
      assert hd(txts) == "title\t\t\t\t\tTitle"
      assert Enum.at(txts, 1) == "chapter\t1\t\t\t\tChapter 1 Name"
      assert Enum.at(txts, 2) == "sub-chapter\t1\t1\t\t\tI. Subchapter"
      assert Enum.at(txts, 3) == "article\t1\t1\t1\t\tSection 1. Name"
      assert Enum.at(txts, 4) == "para\t1\t1\t1\t1\t(1) Name"
      assert Enum.at(txts, 5) == "annex\t1\t1\t1\t1\tAnnex 1: Name"
    end

  end


end
