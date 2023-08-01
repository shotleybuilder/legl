defmodule Legl.Countries.Uk.AtArticle.Clean.UkBespoke do
  @moduledoc """
  Module applies bespoke cleaning functions to a specific piece of law.  The ID
  number from airtable is used as the name of each function.

  Module is called after all the cleaning functions have been called.

  The module is the code embodiment of the original.txt notes contained in Airtable.
  """

  @tag "💙\\0"
  @ln_tag "💙\\0💙"

  def bespoker(binary, id) do
    func =
      String.downcase(id)
      |> String.replace("-", "_")
      |> String.replace("/", "_")
      |> String.to_atom()

    try do
      Kernel.apply(__MODULE__, func, [binary])
    rescue
      UndefinedFunctionError ->
        binary
    else
      {:ok, binary} ->
        binary
    end
  end

  def uk_ukpga_1990_8_tcpa(binary) do
    # Town and Country Planning Act
    binary
    |> (&Regex.replace(
          ~r/Powers of Secretary of State to secure adequate publicity and consultationsE+W\n/,
          &1,
          "Powers of Secretary of State to secure adequate publicity and consultationsE+W\n7"
        )).()
  end

  def uk_ukpga_1991_56_wia(binary) do
    tag = "💙\\0"
    ln = "💙\\0💙"
    # Water Industry Act
    # Marking up what we want to parse
    binary
    |> (&Regex.replace(
          ~r/^Water Industry Act 1991/,
          &1,
          tag
        )).()
    |> (&Regex.replace(
          ~r/\n^Part IE\+W PRELIMINARY/m,
          &1,
          tag
        )).()
    |> (&Regex.replace(
          ~r/^Part IIE\+W APPOINTMENTMENT AND REGULATION OF UNDERTAKERS$/m,
          &1,
          ln
        )).()
    # from
    |> (&Regex.replace(
          ~r/\[F141CHAPTER 1AE\+W \[F142Water supply licences and sewerage licences\]/m,
          &1,
          tag
        )).()
    # to
    |> (&Regex.replace(
          ~r/CHAPTER IIE\+W ENFORCEMENT OF INSOLVENCY/m,
          &1,
          tag
        )).()
    # line
    |> (&Regex.replace(
          ~r/Part IIIE\+W WATER SUPPLY/m,
          &1,
          ln
        )).()
    # from
    |> (&Regex.replace(
          ~r/\[F690CHAPTER 2AE\+W\[F691Supply duties etc: water supply licensees\]/m,
          &1,
          tag
        )).()
    # to
    |> (&Regex.replace(
          ~r/\nCHAPTER IVE\+W FLUORIDATION/m,
          &1,
          tag
        )).()
    # line
    |> (&Regex.replace(
          ~r/Part IVE\+W SEWERAGE SERVICES/m,
          &1,
          ln
        )).()
    # from
    |> (&Regex.replace(
          ~r/CHAPTER IIIE\+W TRADE EFFLUENT/m,
          &1,
          tag
        )).()
    # to
    |> (&Regex.replace(
          ~r/\[F1188CHAPTER 4E\+WStorm overflows/m,
          &1,
          tag
        )).()
    # line
    |> (&Regex.replace(
          ~r/SCHEDULES/m,
          &1,
          ln
        )).()
    # from
    |> (&Regex.replace(
          ~r/\[F1573SCHEDULE 2AU\.K\.WATER SUPPLY LICENCES: AUTHORISATIONS/m,
          &1,
          tag
        )).()
    # to
    |> (&Regex.replace(
          ~r/Section 23\.\nSCHEDULE 3E\+W SPECIAL ADMINISTRATION ORDERS/m,
          &1,
          tag
        )).()
    # Bug fix
    |> (&Regex.replace(
          ~r/^\[F69166AAWater supply from water undertakerE\+W$/m,
          &1,
          "[::section::]66AA [F691 66AA Water supply from water undertaker [::region::]E+W"
        )).()
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1991_57_wra(binary) do
    regexes = [
      start: ~r/^Water Resources Act 1991/m,
      end: ~r/Part IE\+W\+S PRELIMINARY/m,
      start_end: ~r/^Part IIE\+W Water Resources Management/m,
      start: ~r/Chapter IIE\+W ABSTRACTION AND IMPOUNDING/m,
      end: ~r/chapter IIIE\+W DROUGHT/m,
      start: ~r/Part IIIE\+W Control of Pollution of Water Resources/m,
      end: ~r/Part IVE\+W FLOOD DEFENCE/m,
      start_end: ~r/SCHEDULES/m,
      start: ~r/^SCHEDULE 5E+W PROCEDURE RELATING TO STATEMENTS ON MINIMUM ACCEPTABLE FLOW/m,
      end: ~r/^Section 73\.\n^SCHEDULE 8E\+W PROCEEDINGS ON APPLICATIONS FOR DROUGHT ORDERS/m,
      start: ~r/^Section 93\.\n^SCHEDULE 11E\+W WATER PROTECTION ZONE ORDERS/m,
      end: ~r/^Section 94.\n^F729SCHEDULE 12E+W NITRATE SENSITIVE AREA ORDERS/m
    ]

    include(binary, regexes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_2003_37_wa(binary) do
    regexes = [
      start: ~r/^Water Act 2003$/m,
      end: ~r/^Part 2 U\.K\.New regulatory arrangements, etc$/m,
      start_end: ~r/Part 4 E\+W\+SSupplementary$/m,
      start: ~r/^105Interpretation, commencement, short title, and extentE\+W$/m,
      end: ~r/SCHEDULES/m
    ]

    include(binary, regexes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1991_60_wccpa(binary) do
    regex = ~r/F15Sch\. 1 para\. 34 repealed \(20\.6\.2003\) by Enterprise Act 2002/m

    Regex.replace(
      regex,
      binary,
      "F15Sch\. 1 para\. 33, 34 repealed (20\.6\.2003) by Enterprise Act 2002"
    )
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_2010_29_fwma(binary) do
    regexes = [
      start: ~r/^Flood and Water Management Act 2010/m,
      end: ~r/^Part 2 E\+W\+SMiscellaneous/m,
      start: ~r/^SCHEDULES$/m,
      end: ~r/^Section 31\nSCHEDULE 2E\+WRisk Management: Amendment of Other Acts/m,
      start: ~r/^Section 32\nSCHEDULE 3E+WSustainable Drainage/m,
      end: ~r/Section 33\nSCHEDULE 4E+W+SReservoirs/
    ]

    changes = [
      {~r/^1\. Key concepts and definitionsE\+W$/m, ~s/Key concepts and definitionsE+W/},
      {~r/^2\. Strategies, co-operation and fundingE\+W$/m,
       ~s/Strategies, co-operation and fundingE+W/},
      {~r/^3\. Supplemental powers and dutiesE\+W/m, ~s/Supplemental powers and dutiesE+W/},
      {~r/^4\. Regional Flood and Coastal Committees \[F20for regions in England\] E\+W$/m,
       ~s/Regional Flood and Coastal Committees [F20for regions in England] E+W/},
      {~r/5\. GeneralE\+W/m, ~s/GeneralE+W/},
      {~r/F3626“The Minister”E\+W/m, ~s/F3626 “The Minister”E+W/},
      {~r/F3626A“The appropriate agency”E\+W/m, ~s/F3626A “The appropriate agency”E+W/}
    ]

    include(binary, regexes)
    |> replace(changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1968_47_ssa(binary) do
    changes = [
      {~r/^Chap ter	Short Title	Extent of Repeal$/m, ~s/Chapter	Short Title	Extent of Repeal/},
      {~r/F430. . .\tF430. . .\tF430. . ./m, ~s/\tF430. . .\tF430. . .\tF430. . ./},
      {~r/\nSection 60\(1\)\.\nSCHEDULE 1S CONSEQUENTIAL AMENDMENTS/m, ~s/SCHEDULES\\0/},
      {~r/^SCHEDULE 2S ENACTMENTS REPEALED$/m, ~s/SCHEDULE 2 S ENACTMENTS REPEALED/}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1980_45_wsa(binary) do
    regexes = [
      start: ~r/^Water \(Scotland\) Act 1980$/m,
      end: ~r/^Part IS Central Authority$/m,
      start: ~r/^Part VIS Conservation and Protection of Water Resources$/m,
      end: ~r/^Part VIIS Powers to Supply Water During Drought$/m,
      start: ~r/^Part IXS General$/m,
      end: ~r/^SCHEDULES$/m
    ]

    changes = [
      {~r/F546\n76MPower to enterS/m, ~s/F546 76M Power to enter S/}
    ]

    include(binary, regexes)
    |> replace(changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1989_15_wa(binary) do
    regexes = [
      start: ~r/^Water Act 1989$/m,
      end: ~r/^Part I U\.K\. Preliminary$/m,
      start: ~r/^Part III E\+W\+S The Protection and Management of Rivers and other Waters$/m,
      end: ~r/^Part IV E\+W Powers in Relation to Land and Works Powers etc\.$/m,
      start: ~r/^Part V S Provisions relating to Scotland$/m,
      end: ~r/^SCHEDULES$/m
    ]

    changes = [
      {~r/F1567—68/m, ~s/F15 67—68/},
      {~r/F2075—82/m, ~s/F20 75—82/},
      {~r/F2897—102/m, ~s/F28 97—102/},
      {~r/F29103—124/m, ~s/F29 103—124/},
      {~r/F30125—135/m, ~s/F30 125—135/},
      {~r/F34138/m, ~s/F34 138/},
      {~r/F40143—150/m, ~s/F40 143—150/},
      {~r/F41151—167/m, ~s/F41 151—167/},
      {~r/F42170, 171/m, ~s/F42 170, 171/},
      {~r/F43172/m, ~s/F43 172/},
      {~r/F96176/m, ~s/F96 176/},
      {~r/F97178—182/m, ~s/F97 178—182/},
      {~r/F101186/m, ~s/F101 186/},
      {~r/F102188/m, ~s/F102 188/},
      {~r/^Schedule 22/m, ~s/ Schedule 22/},
      {~r/^Schedule 23/m, ~s/ Schedule 23/}
    ]

    include(binary, regexes)
    |> replace(changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_2014_21_wa(binary) do
    regexes = [
      start: ~r/^Water Act 2014$/m,
      end: ~r/^CHAPTER 2E\+WWater and sewerage undertakers$/m,
      start: ~r/^Part 3 E\+W\+SEnvironmental regulation$/m,
      end: ~r/^Part 4 U\.K\.Flood insurance$/m,
      start_end: ~r/^SCHEDULES$/m,
      start: ~r/^Section 61\nSCHEDULE 8E\+W\+SRegulation of the water environment/m,
      end:
        ~r/^Section 87\nSCHEDULE 9U\.K\.Publication requirements under the Land Drainage Act 1991/m
    ]

    include(binary, regexes)
    # |> replace(changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1949_geo6_12_13_14_97_npatca(binary) do
    changes = [
      {~r/^F11F1/m, ~s/F1 1 F1/},
      {~r/^F12F1/m, ~s/F1 2 F1/},
      {~r/^F13F1/m, ~s/F1 3 F1/},
      {~r/^F14F1/m, ~s/F1 4 F1/},
      {~r/^Part II[\. ]+?F300E\+W/m,
       ~s/F300 Part II . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . E+W/},
      {~r/^FIRST SCHEDULE/m, ~s/SCHEDULE 1/},
      {~r/^X1 Part IE\+W/m, ~s/[::part::]1 X1 Part I [::region::]E+W/}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1981_69_wca(binary) do
    changes = [
      {~r/\[F505X561 Ploughing of public rights of way\.E\+W/m,
       ~s/[F50561 X5 Ploughing of public rights of way.E+W/},
      {~r/^X11 \[F610 4 S For subsection \(3\)/m, ~s/[F6104 X11 S For subsection (3)/},
      {~r/^X12 \[F611 5 \(1\)/m, ~s/[F6115 X12 (1)/},
      {~r/^10A“ Exceptions for authorised persons./m,
       ~s/“10A Exceptions for authorised persons./},
      {~r/^X13 \[F612 6 \(1\)/m, ~s/[F6126 X13 (1)/},
      {~r/^2\.\(1\)This paragraph applies where—/m, ~s/2(1)This paragraph applies where—/},
      {~r/^1\.In this schedule—/m, ~s/1 In this schedule—/},
      {~r/^Companion animalsS/m, ~s/[::heading::]2 Companion animals [::region::]S/},
      {~r/^5\.\(1\)The appropriate authority/m, ~s/5(1) The appropriate authority/},
      {~r/^U\.K\. REPTILES/m, ~s/REPTILES U.K./},
      {~r/^U\.K\. AMPHIBIANS/m, ~s/AMPHIBIANS U.K./},
      {~r/^U\.K\. FISH/m, ~s/FISH U.K./},
      {~r/^U\.K\. MOLLUSCS/m, ~s/MOLLUSCS U.K./},
      {~r/^MarsupialsU\.K\./m, ~s/Marsupials/},
      {~r/^RheasU\.K\./m, ~s/Rheas/},
      {~r/^CrocodiliansU\.K\./m, ~s/Crocodilians/},
      {~r/^The kinds of amphibian specified in the first column below—/m,
       ~s/4U.K.The kinds of amphibian specified in the first column below—/},
      {~r/F705 1 —4\.E\+W\+S[\. ]*/m, ~s/F705 1—4 . . . . . E+W+S/}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_2007_19_cmcha(binary) do
    changes = [
      {~r/^17DPP/m, ~s/17 DPP/}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1972_28_emasa(binary) do
    changes = [
      {~r/^C81.2.1973/m, ~s/C8 1.2.1973/}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1920_65_ewypca(binary) do
    changes = [
      {~r/^Part III. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . F23U.K.$/m,
       ~s/Part IIIU.K.. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . F23/},
      {~r/^F24Part IV repealed/m, ~s/F24Sch. Part IV repealed/},
      {~r/^Article[ ]/m, ~s//}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1984_3_ola(binary) do
    changes = [
      {~r/^F11 Duty of occupier/m, ~s/F1 1 Duty of occupier/}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1963_41_osrpa(binary) do
    changes = [
      {~r/^F4227\(1\)\(2\)/m, ~s/F42Ss. 27(1)(2)/},
      {~r/^F4428/m, ~s/F44Ss. 28/},
      {~r/^F6128/m, ~s/F61Ss. 28/},
      {~r/^F7328/m, ~s/F73Ss. 28/},
      {~r/^F7828/m, ~s/F78Ss. 28/},
      {~r/^F5352\(1\)/m, ~s/F53Ss. 52(1)/}
    ]

    replace(binary, changes)
    |> (&{:ok, &1}).()
  end

  def uk_ukpga_1974_37_hswea(binary) do
    changes = [
      {~r/^\[F11\(1\)\[F12Subject/m, ~s/[::sub_section::]1 F11 (1) [F12 Subject/},
      {~r/^F15429/m, ~s/F154 29/},
      {~r/^F15631/m, ~s/F156 31/}
    ]

    regexes = [
      start: ~r/^Health and Safety at Work etc\. Act 1974/m,
      end: ~r/^The Health and Safety Commission and the Health and Safety ExecutiveU\.K\./m,
      start: ~r/^EnforcementU\.K\./m,
      end: ~r/^Financial provisionsU\.K\./m,
      start: ~r/^Part IVU\.K\. Miscellaneous and General/m,
      end: ~r/^X177 Amendment of Radiological Protection Act 1970\.U\.K\./m,
      start: ~r/^84 Extent, and application of Act\.U\.K\./m,
      end: ~r/^SCHEDULES/m
    ]

    binary
    |> include(regexes)
    |> replace(changes)
    |> (&{:ok, &1}).()
  end

  def uk_uksi_2000_128_pssr(binary) do
    changes = [
      {~r/\[::paragraph::\]1 1\. The manufacturer’s name\./, ~s/1. The manufacturer’s name./},
      {~r/\[::paragraph::\]2 2\. A serial number to identify the vessel\./,
       ~s/2. A serial number to identify the vessel./},
      {~r/\[::paragraph::\]3 3\. The date of manufacture of the vessel\./,
       ~s/3. The date of manufacture of the vessel./},
      {~r/\[::paragraph::\]4 4\. The standard to which the vessel was built\./,
       ~s/4. The standard to which the vessel was built./},
      {~r/\[::paragraph::\]5 5\. The maximum allowable pressure of the vessel\./,
       ~s/5. The maximum allowable pressure of the vessel./},
      {~r/\[::paragraph::\]6 6\. The minimum allowable pressure of the vessel where it is other than atmospheric\./,
       ~s/[::paragraph::]6 6. The minimum allowable pressure of the vessel where it is other than atmospheric./},
      {~r/\[::paragraph::\]7 7\. The design temperature\./,
       ~s/[::paragraph::]7 7. The design temperature./},
      {~r/60 �C and having a total mass not exceeding 23 kilogrammes/,
       ~s/60°C and having a total mass not exceeding 23 kilogrammes/}
    ]

    binary
    # |> include(regexes)
    |> replace(changes)
    |> (&{:ok, &1}).()
  end

  def uk_uksi_2016_1105_pesr(binary) do
    changes = [
      {~r/ �C/, ~s/°C/}
    ]

    changes_mid = [
      {~r/(^\[::article::\]41.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E23)/m,
       ~s/[::region::]E+W+S/},
      {~r/(^\[::amendment::\]F91.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E24)/m,
       ~s/[::region::]E+W+S/},
      {~r/(^\[::article::\]44.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E25)/m,
       ~s/[::region::]E+W+S/},
      {~r/(^\[::article::\]46.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E26)/m,
       ~s/[::region::]E+W+S/},
      {~r/(^\[::amendment::\]F150.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E35)/m,
       ~s/[::region::]E+W+S/},
      {~r/(^\[::amendment::\]F90.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E89)/m,
       ~s/[::region::]N.I./},
      {~r/(^\[::amendment::\]F92.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E90)/m,
       ~s/[::region::]N.I./},
      {~r/(^\[::amendment::\]F93.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E91)/m,
       ~s/[::region::]N.I./},
      {~r/(^\[::amendment::\]F94.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E92)/m,
       ~s/[::region::]N.I./},
      {~r/(^\[::amendment::\]F151.*\n\[::heading::\])(\n[\s\S]+^\[::extent::\]E101)/m,
       ~s/[::region::]N.I./}
    ]

    binary
    # |> include(regexes)
    |> replace(changes)
    |> replace_mid(changes_mid)
    |> (&{:ok, &1}).()
  end

  def uk_nisr_1999_13_csrni(binary) do
    changes = [
      {~r/currently �5,000/m, ~s/currently £5,000/}
    ]

    binary
    # |> include(regexes)
    |> replace(changes)
    # |> replace_mid(changes_mid)
    |> (&{:ok, &1}).()
  end

  def uk_nisr_1996_119_hssssrni(binary) do
    changes = [
      {~r/The following set of coded signals are without prejudice to other codes applicable at Community level/m,
       ~s/[::paragraph::]3.1 3.1. The following set of coded signals are without prejudice to other codes applicable at Community level/}
    ]

    binary
    # |> include(regexes)
    |> replace(changes)
    # |> replace_mid(changes_mid)
    |> (&{:ok, &1}).()
  end

  def uk_nisr_2004_222_pssrni(binary) do
    # {"\uFFFD"} == �
    # "\u{B0}" == °
    # "\u{B7}" == ·
    IO.inspect(Regex.scan(~r/[#{"\u{B7}"}]/m, binary), label: "points")
    IO.inspect(Regex.scan(~r/[#{"\u{B0}"}]/m, binary), label: "degs")

    changes = [
      {~r/[#{"\u{B7}"}]/m, ~s/./},
      {~r/[#{"\u{B0}"}]C/m, ~s/degrees Celsius/}
    ]

    binary
    # |> include(regexes)
    |> replace(changes)
    # |> replace_mid(changes_mid)
    |> (&{:ok, &1}).()
  end

  defp include(binary, regexes) do
    binary =
      Enum.reduce(regexes, binary, fn {pos, regex}, acc ->
        replace = if pos == :start_end, do: @ln_tag, else: @tag

        Regex.replace(
          regex,
          acc,
          replace
        )
      end)

    # IO.inspect(binary)

    Regex.scan(~r/^💙[\S\s]*?💙/m, binary)
    |> Enum.reduce("", fn
      [x], "" -> "#{x}"
      [x], acc -> "#{acc}\n#{x}"
    end)
    |> (&Regex.replace(~r/💙/m, &1, "")).()
  end

  defp replace(binary, changes) do
    Enum.reduce(changes, binary, fn {from, to}, acc ->
      Regex.replace(from, acc, to)
    end)
  end

  defp replace_mid(binary, changes) do
    Enum.reduce(changes, binary, fn {from, to}, acc ->
      Regex.replace(from, acc, "\\g{1} #{to}\\g{2}")
    end)
  end
end
