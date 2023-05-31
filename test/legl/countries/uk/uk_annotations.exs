defmodule UKAnnotations do
  # mix test test/legl/countries/uk/uk_annotations.exs:7

  use ExUnit.Case
  import Legl.Countries.Uk.AirtableArticle.UkAnnotations

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

  describe "tag_section_range/1" do
    test "act sub sections" do
      binary =
        [
          "Part IIIU.K.",
          "37—40.. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . F147 U.K.",
          "Textual Amendments",
          "🔻F147🔻 S. 37—40 repealed by Crown Estate Act 1961 (c. 55), Sch. 3 Pt. I"
        ]
        |> Enum.join("\n")

      fresult = tag_section_range(binary)
      # |> IO.inspect()

      test =
        [
          "Part IIIU.K.",
          "[::section::]37 F147 37 .. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .  [::region::]U.K.",
          "[::section::]38 F147 38 .. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .  [::region::]U.K.",
          "[::section::]39 F147 39 .. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .  [::region::]U.K.",
          "[::section::]40 F147 40 .. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .  [::region::]U.K.",
          "Textual Amendments",
          "🔻F147🔻 S. 37—40 repealed by Crown Estate Act 1961 (c. 55), Sch. 3 Pt. I"
        ]
        |> Enum.join("\n")

      assert test == fresult
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

      fresult = tag_sub_section_efs(binary)
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

  describe "tag_schedule_section_efs/1" do
    test "act schedule section efs" do
      binary =
        [
          # these are the amendment clauses used to id the amended schedule sections
          "🔻F1569🔻 Sch. 2 para. 4A ",
          "🔻F1593🔻 Sch. 4ZA para. 2A ",
          "🔻F1603🔻 Sch. 4A para. 4 ",
          "🔻F1606🔻 Sch. 4A paras. 8, 9 ",
          #
          "[F1569Exclusion of transfer of licenceU.K.",
          "[F15932A.U.K.Where a reference is made to the chair of the CMA",
          "[F16034E+WA hospital as defined by section 275 of the National Health Service Act 2006",
          "[F16068(1)A care home or independent hospital.E+W"
        ]
        |> Enum.join("\n")

      fresult = tag_schedule_section_efs(binary)
      # |> IO.inspect()

      test =
        [
          "🔻F1569🔻 Sch. 2 para. 4A ",
          "🔻F1593🔻 Sch. 4ZA para. 2A ",
          "🔻F1603🔻 Sch. 4A para. 4 ",
          "🔻F1606🔻 Sch. 4A paras. 8, 9 ",
          "[F1569Exclusion of transfer of licenceU.K.",
          "[::section::]2A [F1593 2A .U.K.Where a reference is made to the chair of the CMA",
          "[::section::]4 [F1603 4 E+WA hospital as defined by section 275 of the National Health Service Act 2006",
          "[::section::]8-1 [F1606 8(1)A care home or independent hospital.E+W"
        ]
        |> Enum.join("\n")

      assert test == fresult
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
          "[F1569Exclusion of transfer of licenceU.K."
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
          "[::heading::][F1569 Exclusion of transfer of licence [::region::]U.K."
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
