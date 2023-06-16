defmodule UKAnnotations do
  # mix test test/legl/countries/uk/uk_annotations.exs:7

  use ExUnit.Case
  import Legl.Countries.Uk.AirtableArticle.UkAnnotations
  import Legl.Countries.Uk.AirtableArticle.UkEfCodes

  describe "tag_txt_amend_efs/1" do
    test "act txt amend efs" do
      binary =
        [
          "F578 By S. I.",
          "F438Definition substituted by Agriculture Act 1986",
          "F535 Sch. ZA1 inserted",
          "F537Entry in Sch",
          "F903Para reference (a)",
          "F54In s. 1(7) the definition of \"local authority\"",
          "F121964 c. 29."
        ]
        |> Enum.join("\n")

      fresult = tag_txt_amend_efs(binary)

      test =
        [
          "🔻F578🔻 By S.I.",
          "🔻F438🔻 Definition substituted by Agriculture Act 1986",
          "🔻F535🔻 Sch. ZA1 inserted",
          "🔻F537🔻 Entry in Sch",
          "🔻F903🔻 Para reference (a)",
          "🔻F54🔻 In s. 1(7) the definition of \"local authority\"",
          "🔻F12🔻 1964 c. 29."
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "part_efs/1" do
    test "act part efs" do
      binary =
        [
          "[F508Part 2AU.K.Regulation of provision of infrastructure",
          "F902[PART IIIAE+W Promotion of the Efficient Use of Water",
          "[F1472Part 7AU.K.Further provision about regulation]"
        ]
        |> Enum.join("\n")

      fresult = part_efs(binary)

      test =
        [
          "[::part::][F508 Part 2A Regulation of provision of infrastructure [::region::]U.K.",
          "[::part::]F902 [PART IIIA Promotion of the Efficient Use of Water [::region::]E+W",
          "[::part::][F1472 Part 7A Further provision about regulation] [::region::]U.K."
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "chapter_efs/1" do
    test "act chapter efs" do
      binary =
        [
          "[F141CHAPTER 1AE+W [F142Water supply licences and sewerage licences]",
          "[F690CHAPTER 2AE+W[F691Supply duties etc: water supply licensees]",
          "[F1126Chapter 2AE+WDuties relating to sewerage services: sewerage licensees",
          "[F1188CHAPTER 4E+WStorm overflows"
        ]
        |> Enum.join("\n")

      fresult = chapter_efs(binary)

      test =
        [
          "[::chapter::][F141 CHAPTER 1A [F142Water supply licences and sewerage licences] [::region::]E+W",
          "[::chapter::][F690 CHAPTER 2A [F691Supply duties etc: water supply licensees] [::region::]E+W",
          "[::chapter::][F1126 Chapter 2A Duties relating to sewerage services: sewerage licensees [::region::]E+W",
          "[::chapter::][F1188 CHAPTER 4 Storm overflows [::region::]E+W"
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "tag_schedule_efs/1" do
    test "act tag schedule efs" do
      binary =
        [
          "F560SCHEDULE 5E+W Animals which are Protected",
          "F682 SCHEDULE 12E+W+S Procedure in Connection With Orders Under Section 36",
          "[F535SCHEDULE ZA1E+WBirds which re-use their nests",
          "[F656SCHEDULE 9AE+WSpecies control agreements",
          "F683 SCHEDULE 13 E+W",
          "F1546F1546SCHEDULE 1E+W"
        ]
        |> Enum.join("\n")

      fresult = tag_schedule_efs(binary)

      test =
        [
          "[::annex::]5 F560 SCHEDULE 5 Animals which are Protected [::region::]E+W",
          "[::annex::]12 F682 SCHEDULE 12 Procedure in Connection With Orders Under Section 36 [::region::]E+W+S",
          "[::annex::]ZA1 [F535 SCHEDULE ZA1 Birds which re-use their nests [::region::]E+W",
          "[::annex::]9A [F656 SCHEDULE 9A Species control agreements [::region::]E+W",
          "[::annex::]13 F683 SCHEDULE 13 [::region::]E+W",
          "[::annex::]1 F1546F1546 SCHEDULE 1 [::region::]E+W"
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "tag_table_efs/1" do
    tables =
      [
        "[F162 Table 2",
        "🔻F162🔻 Sch. 1A Table 2 substituted (N.I.) (1.6.2018) by",
        "[F163 Table 3",
        "🔻F163🔻 Sch. 1A Table 3 substituted (N.I.) (1.6.2018) by"
      ]
      |> Enum.join("\n")

    result = tag_table_efs(tables)

    model =
      [
        "[::table::][F162 Table 2",
        "🔻F162🔻 Sch. 1A Table 2 substituted (N.I.) (1.6.2018) by",
        "[::table::][F163 Table 3",
        "🔻F163🔻 Sch. 1A Table 3 substituted (N.I.) (1.6.2018) by"
      ]
      |> Enum.join("\n")

    assert result == model
  end

  @section_i [
               # Amendment clauses
               # EF -> SN
               "🔻F2🔻 S. 1A inserted",
               "🔻F169🔻 S. 17DA inserted",
               "🔻F37🔻 S. 16A repealed (E.W.) (6.4.2010) by",
               "🔻F229🔻 S. 11A inserted",
               "🔻F132🔻 S. 30C inserted",
               "🔻F26🔻 S. 14A inserted (N.I.) (1.6.2018) by",
               "🔻F146🔻 S. 91A repealed",
               # SN -> EF
               "🔻F144🔻 S. 17B title substituted",
               "🔻F138🔻 S. 8A substituted",
               "🔻F110🔻 S. 44A inserted",
               # X
               "🔻F438🔻 S. 29C inserted",
               # EF -> SN
               # B-EF-SN-Txt
               "[F21AWater Services",
               # B-EF-SN-Txt
               "[F16917DAGuidance",
               # ef-B-ef-B-EF-SN-Txt
               "F5[F36[F3716ATransfer of authorisationsU.K.",
               # B-ef-B-EF-SN-sp-Txt
               "[F228[F22911A Modification of conditions of licencesE+W+S",
               # ef-EF-SN-sp-Txt
               "F131F13230C Water quality objectives.S",
               # b-EF-period-Txt
               "[F2614A.Radioactive waste: requirementsN.I.",
               #
               "F146[F14591A]Shares subject to outstanding third party obligationsU.K.",
               # SN -> EF
               # SN-B-EF-Txt
               "17B[F144Meaning of supply",
               # B-SN-EF-sp-Txt
               "[8AF138 Modification or removal of limits.E+W+S",
               "[ 44A F110 Injunctions. E+W",
               # X
               # X-B-EF-SN-sp-Txt
               "X2[F43829C Consumer complaintsU.K."
             ]
             |> Enum.join("\n")

  @section_i_model [
    # Amendment clauses
    # EF -> SN
    "🔻F2🔻 S. 1A inserted",
    "🔻F169🔻 S. 17DA inserted",
    "🔻F37🔻 S. 16A repealed (E.W.) (6.4.2010) by",
    "🔻F229🔻 S. 11A inserted",
    "🔻F132🔻 S. 30C inserted",
    "🔻F26🔻 S. 14A inserted (N.I.) (1.6.2018) by",
    "🔻F146🔻 S. 91A repealed",
    # SN -> EF
    "🔻F144🔻 S. 17B title substituted",
    "🔻F138🔻 S. 8A substituted",
    "🔻F110🔻 S. 44A inserted",

    # X
    "🔻F438🔻 S. 29C inserted",
    #
    "[::section::]1A [F2 1A Water Services",
    "[::section::]17DA [F169 17DA Guidance",
    "[::section::]16A F5[F36[F37 16A Transfer of authorisationsU.K.",
    "[::section::]11A [F228[F229 11A Modification of conditions of licencesE+W+S",
    "[::section::]30C F131F132 30C Water quality objectives.S",
    "[::section::]14A [F26 14A Radioactive waste: requirementsN.I.",
    "[::section::]91A F146[F145 91A ]Shares subject to outstanding third party obligationsU.K.",
    "[::section::]17B 17B [F144 Meaning of supply",
    "[::section::]8A [8A F138 Modification or removal of limits.E+W+S",
    "[::section::]44A [44A F110 Injunctions. E+W",
    "[::section::]29C X2 [F438 29C Consumer complaintsU.K."
  ]

  # |> Enum.join("\n")

  describe "tag_section_efs_i/1" do
    test "S. amendments" do
      result = tag_section_efs_i(@section_i, %{qa_si?: true, qa_si_limit?: true})
      assert String.split(result, "\n") == @section_i_model
    end
  end

  @section_ii [
                # Amendment clauses
                # EF -> SN
                "🔻F529🔻 S. 195 substituted",
                "🔻F153🔻 S. 47 repealed (E.W.) (1.9.1989)",
                "🔻F10🔻 S. 3 substituted",
                "🔻F143🔻 S. 41 repealed (30.6.2014)",
                "🔻F685🔻 S. 224 repealed (30.6.2014)",
                "🔻F886🔻 S. 91 substituted",
                "🔻F1205🔻 S. 145 and ... repealed",
                # SN -> EF
                "🔻F1542🔻 S. 221 substituted",
                "🔻F108🔻 S. 43 substituted",
                # X
                "",
                # EF -> SN
                # B-EF-SN-Txt
                "F530[F529195 Maps of waterworks.E+W",
                # EF-ef-ef-SN-sp-Txt
                "F153F152F15447 Duty with waste from vessels etc.S",
                # ef-B-EF-SN-sp-Txt
                "F5[F103 Meaning of “mobile radioactive apparatus”.U.K.",
                # ef-EF-SN-sp-Txt
                "F133F14341 Registers. S",
                # EF-B-SN-Txt
                "F685[224Application to the Isles of Scilly.E+W",
                # EF-SN-sp-Txt
                "[F88691 [F887 Old Welsh",
                # EF-SN-Txt
                "F1205145. . . . . .",
                # SN -> EF
                # B-SN-EF-Txt
                "[221F1542Crown application.E+W",
                # B-sp-SN-sp-EF-sp-Txt
                "[ 43 F108 Offence where listed",
                # X
                # X-B-EF-SN-sp-Txt
                ""
              ]
              |> Enum.join("\n")

  @section_ii_model [
    # Amendment clauses
    # EF -> SN
    "🔻F529🔻 S. 195 substituted",
    "🔻F153🔻 S. 47 repealed (E.W.) (1.9.1989)",
    "🔻F10🔻 S. 3 substituted",
    "🔻F143🔻 S. 41 repealed (30.6.2014)",
    "🔻F685🔻 S. 224 repealed (30.6.2014)",
    "🔻F886🔻 S. 91 substituted",
    "🔻F1205🔻 S. 145 and ... repealed",
    # SN -> EF
    "🔻F1542🔻 S. 221 substituted",
    "🔻F108🔻 S. 43 substituted",
    # X
    "",
    #
    "[::section::]195 F530[F529 195 Maps of waterworks.E+W",
    "[::section::]47 F153F152F154 47 Duty with waste from vessels etc.S",
    "[::section::]3 F5[F10 3 Meaning of “mobile radioactive apparatus”.U.K.",
    "[::section::]41 F133F143 41 Registers. S",
    "[::section::]224 F685 [224 Application to the Isles of Scilly.E+W",
    "[::section::]91 [F886 91 [F887 Old Welsh",
    "[::section::]145 F1205 145  . . . . .",
    "[::section::]221 [221 F1542 Crown application.E+W",
    "[::section::]43 [43 F108 Offence where listed",
    ""
  ]

  # |> Enum.join("\n")

  describe "tag_section_efs_ii/1" do
    test "S. amendments" do
      result = tag_section_efs_ii(@section_ii)
      assert String.split(result, "/n") == @section_ii_model
    end
  end

  @ss [
        "🔻F4🔻 Ss. 1A-1H, 1J (with a reference to the “Scottish Ministers” in s. 1J) substituted for Ss. 1, 2 (S.) (1.10.2011) by",
        "🔻F5🔻 Ss. 1-24 repealed (S.) (1.9.2018) by ",
        "[F4[F51AMeaning of “radioactive material” and “radioactive waste”U.K.",
        "[F51BNORM industrial activitiesU.K.",
        "[F51DRadionuclides not of natural terrestrial or cosmic originU.K.",
        "[F4[F51ERadionuclides with a short half-lifeU.K.",
        "F5[F115 Further exemptions from ss. 13 and 14.E+W"
      ]
      |> Enum.join("\n")

  @ss_model [
              "🔻F4🔻 Ss. 1A-1H, 1J (with a reference to the “Scottish Ministers” in s. 1J) substituted for Ss. 1, 2 (S.) (1.10.2011) by",
              "🔻F5🔻 Ss. 1-24 repealed (S.) (1.9.2018) by ",
              "[::section::]1A [F4[F5 1A Meaning of “radioactive material” and “radioactive waste”U.K.",
              "[::section::]1B [F5 1B NORM industrial activitiesU.K.",
              "[::section::]1D [F5 1D Radionuclides not of natural terrestrial or cosmic originU.K.",
              "[::section::]1E [F4[F5 1E Radionuclides with a short half-lifeU.K.",
              "[::section::]15 F5[F1 15 Further exemptions from ss. 13 and 14.E+W"
            ]
            |> Enum.join("\n")

  @ss_complex [
                "🔻F440🔻 Pt. 2A  (Ss. 78A-78YC) inserted",
                "🔻F501🔻 Pt. IIA (Ss. 78A-78YC) inserted",
                "🔻F504🔻 Pt. IIA (Ss. 78A-78YC) inserted",
                "🔻F513🔻 Pt. IIA (Ss. 78A-78YC) inserted",
                "F441[F44078A Preliminary.S",
                "F455[F44078C Identification and designation of special sites.S",
                "F459[F44078E Duty of enforcing authority to require remediation of contaminated land etc.S",
                "F463[F44078G Grant of, and compensation for, rights of entry etc.S",
                "F464[F44078H Restrictions and prohibitions on serving remediation notices.S",
                "F465[F44078JRestrictions on liability relating to the pollution of controlled waters.S",
                "F466[F44078K Liability in respect of contaminating substances which escape to other land.S",
                "F469[F44078L Appeals against remediation notices.S",
                "F481[F44078N Powers of the enforcing authority to carry out remediation.S",
                "F494[F44078X Supplementary provisions.S",
                "F50178YA Supplementary provisions with respect to guidance by the Secretary of State.E+W+S",
                "F50478YB Interaction of this Part with other enactments.E+W",
                "F50478YB Interaction of this Part with other enactments.S",
                "[F51378YC This Part and radioactivity.S"
              ]
              |> Enum.join("\n")
  @ss_complex_model [
                      "🔻F440🔻 Pt. 2A  (Ss. 78A-78YC) inserted",
                      "🔻F501🔻 Pt. IIA (Ss. 78A-78YC) inserted",
                      "🔻F504🔻 Pt. IIA (Ss. 78A-78YC) inserted",
                      "🔻F513🔻 Pt. IIA (Ss. 78A-78YC) inserted",
                      "[::section::]78A F441[F440 78A Preliminary.S",
                      "[::section::]78C F455[F440 78C Identification and designation of special sites.S",
                      "[::section::]78E F459[F440 78E Duty of enforcing authority to require remediation of contaminated land etc.S",
                      "[::section::]78G F463[F440 78G Grant of, and compensation for, rights of entry etc.S",
                      "[::section::]78H F464[F440 78H Restrictions and prohibitions on serving remediation notices.S",
                      "[::section::]78J F465[F440 78J Restrictions on liability relating to the pollution of controlled waters.S",
                      "[::section::]78K F466[F440 78K Liability in respect of contaminating substances which escape to other land.S",
                      "[::section::]78L F469[F440 78L Appeals against remediation notices.S",
                      "[::section::]78N F481[F440 78N Powers of the enforcing authority to carry out remediation.S",
                      "[::section::]78X F494[F440 78X Supplementary provisions.S",
                      "[::section::]78YA F501 78YA Supplementary provisions with respect to guidance by the Secretary of State.E+W+S",
                      "[::section::]78YB F504 78YB Interaction of this Part with other enactments.E+W",
                      "[::section::]78YB F504 78YB Interaction of this Part with other enactments.S",
                      "[::section::]78YC [F513 78YC This Part and radioactivity.S"
                    ]
                    |> Enum.join("\n")

  alias Legl.Countries.Uk.AirtableArticle.UkArticleSectionsOptimisation, as: Optimiser
  alias Legl.Countries.Uk.AirtableArticle.UkEfCodes, as: EfCodes

  describe "section_ss_efs/1" do
    test "section_ss_efs/1 sections" do
      result = section_ss_efs(@ss)
      assert result == @ss_model
    end

    test "section_ss_ef_codes/1" do
      ef_codes = section_ss_ef_codes(@ss_complex)

      assert ef_codes == [
               {:F513, {"F513", "78A-78YC", "inserted"}},
               {:F504, {"F504", "78A-78YC", "inserted"}},
               {:F501, {"F501", "78A-78YC", "inserted"}},
               {:F440, {"F440", "78A-78YC", "inserted"}}
             ]
    end

    test "Optimiser.optimise_ef_codes/2" do
      ef_codes = section_ss_ef_codes(@ss_complex)
      optimised_ef_codes = Optimiser.optimise_ef_codes(ef_codes, "SECTIONS")

      assert optimised_ef_codes == [
               {:F513, {"F513", "78A-78YC", "inserted"}},
               {:F504, {"F504", "78A-78YC", "inserted"}},
               {:F501, {"F501", "78A-78YC", "inserted"}},
               {:F440, {"F440", "78A-78YC", "inserted"}}
             ]
    end

    test "EfCodes.ef_tags/1" do
      ef_codes = section_ss_ef_codes(@ss_complex)
      optimised_ef_codes = Optimiser.optimise_ef_codes(ef_codes, "SECTIONS")
      ef_tags = EfCodes.ef_tags(optimised_ef_codes)
      assert Enum.count(ef_tags) == 116
    end

    test "section_ss_efs/1 sections complex" do
      result = section_ss_efs(@ss_complex)
      assert result == @ss_complex_model
    end
  end

  describe "tag_section_range/1" do
    test "act sub sections" do
      binary =
        [
          "45,46. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .F16 U.K.",
          "Textual Amendments",
          "🔻F16🔻 Ss. 45, 46 repealed (with savings) by Finance Act 1975",
          "Part IIIU.K.",
          "37—40. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . F147 U.K.",
          "Textual Amendments",
          "🔻F147🔻 S. 37—40 repealed by Crown Estate Act 1961 (c. 55), Sch. 3 Pt. I"
        ]
        |> Enum.join("\n")

      result = tag_section_range(binary)
      # |> IO.inspect()

      model =
        [
          "[::section::]45 F16 45 . . . . . . [::region::]U.K.",
          "[::section::]46 F16 46 . . . . . . [::region::]U.K.",
          "Textual Amendments",
          "🔻F16🔻 Ss. 45, 46 repealed (with savings) by Finance Act 1975",
          "Part IIIU.K.",
          "[::section::]37 F147 37 . . . . . . [::region::]U.K.",
          "[::section::]38 F147 38 . . . . . . [::region::]U.K.",
          "[::section::]39 F147 39 . . . . . . [::region::]U.K.",
          "[::section::]40 F147 40 . . . . . . [::region::]U.K.",
          "Textual Amendments",
          "🔻F147🔻 S. 37—40 repealed by Crown Estate Act 1961 (c. 55), Sch. 3 Pt. I"
        ]
        |> Enum.join("\n")

      assert result == model
    end
  end

  describe "tag_schedule_range/1" do
    test "trailing Ef" do
      data =
        [
          "SCHEDULES 1—4.U.K. . . . F39",
          "Textual Amendments",
          "🔻F39🔻 Schs. 1-4 repealed by Finance"
        ]
        |> Enum.join("\n")

      result = tag_schedule_range(data)

      model =
        [
          "[::annex::]1 F39 SCHEDULE 1 . . . . . [::region::]U.K.",
          "[::annex::]2 F39 SCHEDULE 2 . . . . . [::region::]U.K.",
          "[::annex::]3 F39 SCHEDULE 3 . . . . . [::region::]U.K.",
          "[::annex::]4 F39 SCHEDULE 4 . . . . . [::region::]U.K.",
          "Textual Amendments",
          "🔻F39🔻 Schs. 1-4 repealed by Finance"
        ]
        |> Enum.join("\n")

      assert result == model
    end
  end

  describe "tag_sub_section_efs/1" do
    test "act sub sections" do
      binary =
        [
          "[F18(6)For",
          "[F9(3A) In",
          "[F8(3ZA)A",
          "F1126  (1)No person may",
          "F416(1). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "F34( 2 ). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "F28 [(4A)In any proceedings under subsection",
          "F60[(7)In any proceedings",
          "F383[F384(1). . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "[F659[F660(6)The “list of species of special concern” means",
          "[F89(A1)This section and sections 14 to 16B app",
          "[F39(za)if those waters are in Wales",
          "F20 [F21( 5 ). . "
        ]
        |> Enum.join("\n")

      fresult = tag_sub_section_efs(binary, ~s/[::sub-section::]/)
      # |> IO.inspect()

      test =
        [
          "[::sub_section::]6 [F18 (6) For",
          "[::sub_section::]3A [F9 (3A) In",
          "[::sub_section::]3ZA [F8 (3ZA) A",
          "[::sub_section::]1 F1126 (1) No person may",
          "[::sub_section::]1 F416 (1) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "[::sub_section::]2 F34 (2) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "[::sub_section::]4A F28 [(4A) In any proceedings under subsection",
          "[::sub_section::]7 F60[ (7) In any proceedings",
          "[::sub_section::]1 F383[F384 (1) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "[::sub_section::]6 [F659[F660 (6) The “list of species of special concern” means",
          "[::sub_section::]A1 [F89 (A1) This section and sections 14 to 16B app",
          "[F39(za)if those waters are in Wales",
          "[::sub_section::]5 F20[F21 (5) . . "
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "tag_sub_sub_section_efs/1" do
    test "act sub sub sections" do
      binary =
        [
          "[F43 (aa) the functions of the NRBW; or]",
          "F185 (h) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "[F184 (g) on each water supply licensee and sewerage licensee;]"
        ]
        |> Enum.join("\n")

      fresult = tag_sub_sub_section_efs(binary)
      # |> IO.inspect()

      test =
        [
          "📌[F43 (aa) the functions of the NRBW; or]",
          "📌F185 (h) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .",
          "📌[F184 (g) on each water supply licensee and sewerage licensee;]"
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  @schedules [
               # these are the amendment clauses used to id the amended schedule sections
               "🔻F1569🔻 Sch. 2 para. 4A by",
               "🔻F1593🔻 Sch. 4ZA para. 2A by",
               "🔻F1603🔻 Sch. 4A para. 4 by",
               "🔻F1606🔻 Sch. 4A paras. 8, 9 by",
               "🔻F296🔻 Sch. 2 para. 6 by",
               "🔻F313🔻 Sch. 3 para. 6 repealed by",
               "🔻F1🔻 Act repealed (except for ss. 49(1) for specified purposes and s. 51, Sch. 4 paras. 2, 5-9, 11) by",
               #
               "[F1569Exclusion of transfer of licenceU.K.",
               "[F15932A.U.K.Where a reference is made to the chair of the CMA",
               "[F16034E+WA hospital as defined by section 275",
               "[F16068(1)A care home or independent hospital.E+W",
               "[F2966E+W+S In section 19(3) of the Public Health Act 1936",
               "X3[F3136E+W+SIn section 3(1)(b)",
               "F5[F18 Exemptions from registration under s. 7.U.K."
             ]
             |> Enum.join("\n")

  @ef_codes [
    {:F1, {"F1", "11", ""}},
    {:F1, {"F1", "5-9", ""}},
    {:F1, {"F1", "2", ""}},
    {:F313, {"F313", "6", ""}},
    {:F296, {"F296", "6", ""}},
    {:F1606, {"F1606", "9", ""}},
    {:F1606, {"F1606", "8", ""}},
    {:F1603, {"F1603", "4", ""}},
    {:F1593, {"F1593", "2A", ""}},
    {:F1569, {"F1569", "4A", ""}}
  ]

  describe "tag_schedule_section_efs/1" do
    test "ef_codes/3 schedules" do
      regex = build_schedule_regex()
      result = ef_codes(@schedules, regex, "SCHEDULE")
      assert @ef_codes == result
    end

    test "ef_tags/1 schedules" do
      result = ef_tags(@ef_codes)

      assert [
               {"F1606", "9", "", "F16069"},
               {"F1606", "8", "", "F16068"},
               {"F1603", "4", "", "F16034"},
               {"F1593", "2A", "", "F15932A"},
               {"F1569", "4A", "", "F15694A"},
               {"F313", "6", "", "F3136"},
               {"F296", "6", "", "F2966"},
               {"F1", "11", "", "F111"},
               {"F1", "9", "", "F19"},
               {"F1", "8", "", "F18"},
               {"F1", "7", "", "F17"},
               {"F1", "6", "", "F16"},
               {"F1", "5", "", "F15"},
               {"F1", "2", "", "F12"}
             ] ==
               result
    end

    test "act schedule section efs" do
      result = tag_schedule_section_efs(@schedules)
      # |> IO.inspect()

      test =
        [
          "🔻F1569🔻 Sch. 2 para. 4A by",
          "🔻F1593🔻 Sch. 4ZA para. 2A by",
          "🔻F1603🔻 Sch. 4A para. 4 by",
          "🔻F1606🔻 Sch. 4A paras. 8, 9 by",
          "🔻F296🔻 Sch. 2 para. 6 by",
          "🔻F313🔻 Sch. 3 para. 6 repealed by",
          "🔻F1🔻 Act repealed (except for ss. 49(1) for specified purposes and s. 51, Sch. 4 paras. 2, 5-9, 11) by",
          #
          "[F1569Exclusion of transfer of licenceU.K.",
          "[::section::]2A [F1593 2A Where a reference is made to the chair of the CMA [::region::]U.K.",
          "[::section::]4 [F1603 4 A hospital as defined by section 275 [::region::]E+W",
          "[::section::]8-1 [F1606 8(1) A care home or independent hospital. [::region::]E+W",
          "[::section::]6 [F296 6 In section 19(3) of the Public Health Act 1936 [::region::]E+W+S",
          "[::section::]6 X3[F313 6 In section 3(1)(b) [::region::]E+W+S",
          "[::section::]8 F5[F1 8 Exemptions from registration under s. 7. [::region::]U.K."
        ]
        |> Enum.join("\n")

      assert test == result
    end
  end

  describe "cross_heading_efs/1" do
    test "act cross heading efs" do
      binary =
        [
          # amendments used to id the cross-headings
          "🔻F87🔻 Ss. 12A-12I and cross-heading inserted",
          "🔻F88🔻 S. 13 cross-heading substituted",
          "🔻F136🔻 S. 17 cross-heading inserted",
          "🔻F341🔻 Ss. 22A-22F and preceding cross-heading inserted",
          "🔻F416🔻 Ss. 27A, 27B and preceding cross-heading inserted",
          "🔻F419🔻 Ss. 27C-27G and preceding cross-heading inserted",
          "🔻F448🔻 Ss. 30ZA, 30ZB and preceding cross-heading inserted",
          "🔻F501🔻 S. 35A and preceding cross-heading inserted",
          "🔻F630🔻 Ss. 51A-51E and preceding cross-heading inserted",
          "🔻F677🔻 Ss. 63AA-63AC and preceding cross-heading inserted",
          "🔻F678🔻 Words in s. 63AA cross-heading substituted",
          "🔻F691🔻 S. 66A-66C and cross-heading substituted",
          "🔻F1023🔻 Cross heading and s. 101A inserted",
          "🔻F1569🔻 Sch. 2 para. 4A and preceding cross-heading inserted",
          "🔻F136🔻 Crossheading inserted",
          # cross-headings
          "[F87Modification of appointment conditions: EnglandE+W",
          "[F88Modification of appointment conditions: Wales]E+W",
          "[F136Modification of appointment conditions: England and Wales]E+W",
          "[F341Financial penaltiesE+W",
          "[F416The Consumer Council for WaterE+W",
          "[F419General functions of the CouncilE+W",
          "[F448Further functions of AuthorityE+W",
          "[F501Disclosure of arrangements for remunerationE+W",
          "[F630Adoption of water mains and service pipesE+W",
          "[F677Supply by [F678water supply licensee] etcE+W",
          "[F691Duties of undertakers to supply water supply licensees etc]E+W",
          "F1023[Provision of public sewers otherwise than by requisitionE+W",
          "[F1569Exclusion of transfer of licenceU.K.",
          "[F136 Control of entry of polluting matter and effluents into water]S"
        ]
        |> Enum.join("\n")

      fresult = cross_heading_efs(binary)

      test =
        [
          "🔻F87🔻 Ss. 12A-12I and cross-heading inserted",
          "🔻F88🔻 S. 13 cross-heading substituted",
          "🔻F136🔻 S. 17 cross-heading inserted",
          "🔻F341🔻 Ss. 22A-22F and preceding cross-heading inserted",
          "🔻F416🔻 Ss. 27A, 27B and preceding cross-heading inserted",
          "🔻F419🔻 Ss. 27C-27G and preceding cross-heading inserted",
          "🔻F448🔻 Ss. 30ZA, 30ZB and preceding cross-heading inserted",
          "🔻F501🔻 S. 35A and preceding cross-heading inserted",
          "🔻F630🔻 Ss. 51A-51E and preceding cross-heading inserted",
          "🔻F677🔻 Ss. 63AA-63AC and preceding cross-heading inserted",
          "🔻F678🔻 Words in s. 63AA cross-heading substituted",
          "🔻F691🔻 S. 66A-66C and cross-heading substituted",
          "🔻F1023🔻 Cross heading and s. 101A inserted",
          "🔻F1569🔻 Sch. 2 para. 4A and preceding cross-heading inserted",
          "🔻F136🔻 Crossheading inserted",
          "[::heading::][F87 Modification of appointment conditions: England [::region::]E+W",
          "[::heading::][F88 Modification of appointment conditions: Wales] [::region::]E+W",
          "[::heading::][F136 Modification of appointment conditions: England and Wales] [::region::]E+W",
          "[::heading::][F341 Financial penalties [::region::]E+W",
          "[::heading::][F416 The Consumer Council for Water [::region::]E+W",
          "[::heading::][F419 General functions of the Council [::region::]E+W",
          "[::heading::][F448 Further functions of Authority [::region::]E+W",
          "[::heading::][F501 Disclosure of arrangements for remuneration [::region::]E+W",
          "[::heading::][F630 Adoption of water mains and service pipes [::region::]E+W",
          "[::heading::][F677 Supply by [F678water supply licensee] etc [::region::]E+W",
          "[::heading::][F691 Duties of undertakers to supply water supply licensees etc] [::region::]E+W",
          "[::heading::]F1023 [Provision of public sewers otherwise than by requisition [::region::]E+W",
          "[::heading::][F1569 Exclusion of transfer of licence [::region::]U.K.",
          "[::heading::][F136 Control of entry of polluting matter and effluents into water] [::region::]S"
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "tag_mods_cees/1" do
    test "act tag mods cees" do
      binary =
        [
          "C1A reference to a detention centre within the meaning of Part VIII",
          "C2Act modified (temp.) (29.3.2005) by The Water Act 2003",
          "C3Act: certain provisions modified (temp.) (8.3.2004) by The Water Act 2003",
          "C4Act: transfer of functions (W.)",
          "C5Act restricted (01.12.1991) by Water Resources Act",
          "C6Act restricted (01.12.1991) by Water Resources Act",
          "C323Sch. 2 para. 3 applied (with modifications) (28.6.2013) by The Water Industry",
          "C324Sch. 2 para. 4A applied (with modifications) (28.6.2013) by The Water Industry",
          "C330Sch. 6 Pt. 2 applied (29.3.2017) by The Glyn Rhonwy Pumped Storage Generating",
          "C331Sch. 6 paras. 7-10 applied (23.12.2003) by The United Utilities Water plc"
        ]
        |> Enum.join("\n")

      fresult = tag_mods_cees(binary)
      # |> IO.inspect()

      test =
        [
          "\[::modification::]C1 A reference to a detention centre within the meaning of Part VIII",
          "\[::modification::]C2 Act modified (temp.) (29.3.2005) by The Water Act 2003",
          "\[::modification::]C3 Act: certain provisions modified (temp.) (8.3.2004) by The Water Act 2003",
          "\[::modification::]C4 Act: transfer of functions (W.)",
          "\[::modification::]C5 Act restricted (01.12.1991) by Water Resources Act",
          "\[::modification::]C6 Act restricted (01.12.1991) by Water Resources Act",
          "\[::modification::]C323 Sch. 2 para. 3 applied (with modifications) (28.6.2013) by The Water Industry",
          "\[::modification::]C324 Sch. 2 para. 4A applied (with modifications) (28.6.2013) by The Water Industry",
          "\[::modification::]C330 Sch. 6 Pt. 2 applied (29.3.2017) by The Glyn Rhonwy Pumped Storage Generating",
          "\[::modification::]C331 Sch. 6 paras. 7-10 applied (23.12.2003) by The United Utilities Water plc"
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "tag_commencing_ies/1" do
    test "act tag commencing ies" do
      binary =
        [
          "Commencement Information",
          "I1Act wholly in force at 1.12.1991 see s. 223(2)"
        ]
        |> Enum.join("\n")

      fresult = tag_commencing_ies(binary)
      # |> IO.inspect()

      test =
        [
          "[::commencement_heading::]Commencement Information",
          "[::commencement::]I1 Act wholly in force at 1.12.1991 see s. 223(2)"
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end

  describe "tag_extent_ees/1" do
    test "act tag commencing ies" do
      binary =
        [
          "Extent Information",
          "E1Act extends to England and Wales; for minor variations see s. 223(3)"
        ]
        |> Enum.join("\n")

      fresult = tag_extent_ees(binary)
      # |> IO.inspect()

      test =
        [
          "[::extent_heading::]Extent Information",
          "[::extent::]E1 Act extends to England and Wales; for minor variations see s. 223(3)"
        ]
        |> Enum.join("\n")

      assert test == fresult
    end
  end
end
