defmodule UKParser do
  # mix test test/legl/countries/uk/uk_parser.exs:10

  use ExUnit.Case
  alias Types.Component
  @components %Component{}

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

      s = UK.Parser.rm_header(hdr)
      assert s == "Statutory Instruments\n"
    end

    test "uc rm_explanatory_note/1" do
      binary = ~s"""
      EXPLANATORY NOTE
      ()
      1. Foo
      2. Bar
      """

      s = UK.rm_explanatory_note(binary)
      assert s == ""
    end

    test "lc rm_explanatory_note/1" do
      binary = ~s"""
      Explanatory Note
      ()
      1. Foo
      2. Bar
      """

      s = UK.rm_explanatory_note(binary)
      assert s == ""
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

  describe "heading/2" do
    test "⭐1 Foobar" do
      binary = ~s/#{Legl.heading_emoji()}1 Foobar/

      record = %{
        flow: "",
        type: "",
        chapter: "",
        subchapter: "",
        article: "",
        para: "",
        sub: 0,
        str: ""
      }

      s = UK.heading(binary, record)

      assert s ==
               %{
                 article: "1",
                 chapter: "",
                 flow: "",
                 para: "",
                 sub: 0,
                 str: "Foobar",
                 subchapter: "",
                 type: "article, heading"
               }
    end
  end

  describe "get_A_heading/2" do
    test "get_A_heading/2 :act" do
      data = [
        "[::heading::][F6522  [::region::]U.K.After Schedule 13 to the Taxes"
      ]
    end
  end

  describe "get_section/2" do
    test "section with no region" do
      binary = ~s/6(1)Section 103 of the Utilities Act 2000/

      assert UK.Parser.get_section(binary, :act) ==
               ~s/[::section::]6 6(1) Section 103 of the Utilities Act 2000/
    end
  end

  describe "get_sub_section/2" do
    test "acts" do
      binary = ~s/[(1)]Schedule 2 to this Act shall have effect for enabling provision\n/

      assert UK.Parser.get_sub_section(binary, :act) ==
               ~s/[::section::]6 6(1) Section 103 of the Utilities Act 2000/
    end
  end

  describe "get_annex/1" do
    # SCHEDULES Schedules
    test "SCHEDULES" do
      binary = ~s/SCHEDULES U.K.\nSchedules E+W+S\nSCHEDULESU.K.\nSCHEDULES\nSchedules\n/
      s = UK.Parser.get_annex(binary)

      assert s ==
               ~s/[::annex::] SCHEDULES [::region::]U.K.\n[::annex::] Schedules [::region::]E+W+S\n[::annex::] SCHEDULES [::region::]U.K.\n[::annex::] SCHEDULES\n[::annex::] Schedules\n/
    end

    test "SCHEDULE 1" do
      binary = ~s/SCHEDULE 1 U.K.Name\nSCHEDULE 1Name\nSCHEDULE2Name\nSchedule3 Name\n/
      s = UK.Parser.get_annex(binary)

      assert s ==
               ~s/[::annex::]1 SCHEDULE 1 Name [::region::]U.K.\n[::annex::]1 SCHEDULE 1 Name\n[::annex::]2 SCHEDULE 2 Name\n[::annex::]3 Schedule 3 Name\n/
    end

    test "[F1SCHEDULE 1" do
      binary = ~s/[F1SCHEDULE 1U.K.Name\n[F2Schedule 2AE+WName\n/
      s = UK.Parser.get_annex(binary)

      assert s ==
               ~s/[::annex::]1 [F1 SCHEDULE 1 Name [::region::]U.K.\n[::annex::]2A [F2 Schedule 2A Name [::region::]E+W\n/
    end

    test "Schedules" do
      binary =
        ~s/SCHEDULE 1 U.K.The Committee on Climate Change\nSCHEDULE 2 U.K.Trading schemes\nSCHEDULE 3 U.K.Trading schemes regulations: further provisions\nSCHEDULE 4 U.K.Trading schemes: powers to require information\nF31SCHEDULE 5E+WWaste reduction schemes\nSCHEDULE 6 E+W+N.I.Charges for [F11single use carrier bags][F11carrier bags]\nSCHEDULE 7 U.K.Renewable transport fuel obligations\nSCHEDULE 8 E+W+SCarbon emissions reduction targets/

      s = UK.Parser.get_annex(binary)

      assert s ==
               "[::annex::]1 SCHEDULE 1 The Committee on Climate Change [::region::]U.K.\n[::annex::]2 SCHEDULE 2 Trading schemes [::region::]U.K.\n[::annex::]3 SCHEDULE 3 Trading schemes regulations: further provisions [::region::]U.K.\n[::annex::]4 SCHEDULE 4 Trading schemes: powers to require information [::region::]U.K.\n[::annex::]5 F31SCHEDULE 5 Waste reduction schemes [::region::]E+W\n[::annex::]6 SCHEDULE 6 Charges for [F11single use carrier bags][F11carrier bags] [::region::]E+W+N.I.\n[::annex::]7 SCHEDULE 7 Renewable transport fuel obligations [::region::]U.K.\n[::annex::]8 SCHEDULE 8 Carbon emissions reduction targets [::region::]E+W+S"
    end
  end

  describe "get_signed_section/1" do
    test "Signed section" do
      binary = ~s/Signed by authority\nMike Penning\nMinister/
      s = UK.get_signed_section(binary)
      assert s == ~s/#{Legl.signed_emoji()}Signed by authority\nMike Penning\nMinister/
    end
  end

  describe "part_chapter_numeric/2" do
    test "PART 2 INFORMATION" do
      binary = ~s/PART 2 INFORMATION/
      s = UK.get_part(binary)
      assert s == ~s/#{Legl.part_emoji()}2 PART 2 INFORMATION/
    end
  end

  describe "part_chapter_roman/2" do
    test "part" do
      binary =
        [
          ~s/PART IITEST/,
          ~s/PART IINFORMATION/,
          ~s/PART IIINFORMATION/,
          ~s/PART IIGENERAL/,
          ~s/PART IVTEST/,
          ~s/PART IVISION/,
          ~s/Part IIS The Water Industry Commissioner for Scotland/
        ]
        |> Enum.join("\n")

      params = ["PART|Part", @components.part]
      result = UK.Parser.part_chapter_roman(binary, params)

      desired = ""

      assert result == desired
    end
  end

  describe "article/2" do
    test "💚1.—(1)" do
      binary = "💚1.—(1) FooBar"
      record = %{type: "", chapter: "", subchapter: "", article: "", para: 0, str: ""}
      s = UK.article(binary, record)

      assert s ==
               %{
                 article: "1",
                 chapter: "",
                 para: "1",
                 str: "1.—(1) FooBar",
                 subchapter: "",
                 type: "article, sub-article"
               }
    end

    test "💚1." do
      binary = "💚1. FooBar"
      record = %{type: "", chapter: "", flow: "", subchapter: "", article: "", para: 0, str: ""}
      s = UK.article(binary, record)

      assert s ==
               %{
                 article: "",
                 chapter: "",
                 flow: "",
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

  describe "incremenet_string/1" do
    test "empty string" do
      s = UK.increment_string("")
      assert s == "1"
    end

    test "1" do
      s = UK.increment_string("1")
      assert s == "2"
    end
  end
end
