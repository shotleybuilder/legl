defmodule Legl.Countries.Uk.Support.LeglFitnessSeparateRulesTest do
  @data [
    %{
      rule:
        "Where a duty is placed by these Regulations on an employer in respect of his employees, he shall, so far as is reasonably practicable, be under a like duty in respect of any other person, whether at work or not, who may be affected by the work carried out by the employer except that the duties of the employer—\n(a) under regulation 10 (medical surveillance) shall not extend to persons who are not his employees other than employees of another employer who are working under the direction of the first-mentioned employer; and\n(b) under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees, unless those persons are on the premises where the work is being carried out.",
      result: [
        %{
          rule:
            "Where a duty is placed by these Regulations on an employer in respect of his employees, he shall, so far as is reasonably practicable, be under a like duty in respect of any other person, whether at work or not, who may be affected by the work carried out by the employer.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 10 (medical surveillance) shall not extend to persons who are not his employees.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 10 (medical surveillance) shall extend to employees of another employer who are working under the direction of the first-mentioned employer.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall extend to those persons are on the premises where the work is being carried out.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees.",
          provision: []
        }
      ]
    },
    %{
      rule:
        "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer except that the duties of the employer—\n(a) under regulation 10 (information, instruction and training) do not extend to persons who are not employees of that employer unless those persons are on the premises where the work is being carried out; and\n(b) under regulation 22 (health records and medical surveillance) do not extend to persons who are not employees of that employer.",
      result: [
        %{
          rule:
            "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 10 (information, instruction and training) do extend to those persons are on the premises where the work is being carried out.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 10 (information, instruction and training) do not extend to persons who are not employees of that employer.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 22 (health records and medical surveillance) do not extend to persons who are not employees of that employer.",
          provision: []
        }
      ]
    },
    #
    %{
      rule:
        "Where a duty is placed by these Regulations on an employer in respect of its employees, the employer must, so far as is reasonably practicable, be under a like duty in respect of any other person at work who may be affected by the work carried out by the employer except that the duties of the employer—\n(a) under regulation 5 (information and training) do not extend to persons who are not its employees, unless those persons are present in the workplace where the work is being carried out; and\n(b) under regulation 6 (health surveillance) do not extend to persons who are not its employees.",
      result: [
        %{
          rule:
            "Where a duty is placed by these Regulations on an employer in respect of its employees, the employer must, so far as is reasonably practicable, be under a like duty in respect of any other person at work who may be affected by the work carried out by the employer.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 5 (information and training) do extend to those persons are present in the workplace where the work is being carried out.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 5 (information and training) do not extend to persons who are not its employees.",
          provision: []
        },
        %{
          rule:
            "that the duties of the employer under regulation 6 (health surveillance) do not extend to persons who are not its employees.",
          provision: []
        }
      ]
    },
    #
    %{
      rule:
        "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where—\n(a) the exposure to asbestos of employees is sporadic and of low intensity; and\n(b) it is clear from the risk assessment that the exposure to asbestos of any employee will not exceed the control limit; and\n(c) the work involves—\n(i) short, non-continuous maintenance activities in which only non-friable materials are handled, or\n(ii) removal without deterioration of non-degraded materials in which the asbestos fibres are firmly linked in a matrix, or\n(iii) encapsulation or sealing of asbestos-containing materials which are in good condition, or\n(iv) air monitoring and control, and the collection and analysis of samples to ascertain whether a specific material contains asbestos.",
      result: [
        %{
          rule:
            "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where the exposure to asbestos of employees is sporadic and of low intensity.",
          provision: []
        },
        %{
          rule:
            "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where it is clear from the risk assessment that the exposure to asbestos of any employee will not exceed the control limit.",
          provision: []
        },
        %{
          rule:
            "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where the work involves air monitoring and control, and the collection and analysis of samples to ascertain whether a specific material contains asbestos.",
          provision: []
        },
        %{
          rule:
            "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where the work involves encapsulation or sealing of asbestos-containing materials which are in good condition.",
          provision: []
        },
        %{
          rule:
            "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where the work involves removal without deterioration of non-degraded materials in which the asbestos fibres are firmly linked in a matrix.",
          provision: []
        },
        %{
          rule:
            "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where the work involves short, non-continuous maintenance activities in which only non-friable materials are handled.",
          provision: []
        }
      ]
    },
    #
    %{
      rule:
        "These Regulations shall apply to a self-employed person as they apply to an employer and an employee and as if that self-employed person were both an employer and an employee, except that regulation 9 (air monitoring) shall not apply to a self-employed person.",
      result: [
        %{
          rule:
            "These Regulations shall apply to a self-employed person as they apply to an employer and an employee and as if that self-employed person were both an employer and an employee",
          provision: []
        },
        %{
          rule: "regulation 9 (air monitoring) shall not apply to a self-employed person.",
          provision: []
        }
      ]
    },
    %{
      rule:
        "These Regulations apply to every workplace but shall not apply to a workplace located below ground at a mine",
      result: [
        %{
          rule: "These Regulations apply to every workplace",
          provision: []
        },
        %{
          rule: "These Regulations shall not apply to a workplace located below ground at a mine",
          provision: []
        }
      ]
    },
    %{
      rule:
        "These Regulations apply to every workplace but shall not apply to—\n(a) a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in—\n(i) a shipyard, whether or not the shipyard forms part of a harbour or wet dock; or\n(ii) dock premises, not being work done—\n(aa) by the master or crew of a ship;\n(bb) on board a ship during a trial run;\n(cc) for the purpose of raising or removing a ship which is sunk or stranded; or\n(dd) on a ship which is not under command, for the purpose of bringing it under command;\n(b) a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F22015], and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that—\n(i) regulations 18 and 25A apply to such a workplace; and\n(ii) regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to such a workplace which is indoors; or\n(c) a workplace located below ground at a mine, except that regulation 20 applies to such a workplace subject to the modification in paragraph (7).",
      result: [
        %{rule: "These Regulations apply to every workplace", provision: []},
        %{
          rule: "These Regulations shall not apply to a workplace which is or is in or on a ship",
          provision: []
        },
        %{
          rule:
            "Regulations 8(1) and (3) and 12(1) and (3) apply to a workplace which is or is in or on a ship, where the work involves any of the relevant operations in dock premises, not being work done—\n(aa) by the master or crew of a ship;\n(bb) on board a ship during a trial run;\n(cc) for the purpose of raising or removing a ship which is sunk or stranded; or\n(dd) on a ship which is not under command, for the purpose of bringing it under command.",
          provision: []
        },
        %{
          rule:
            "Regulations 8(1) and (3) and 12(1) and (3) apply to a workplace which is or is in or on a ship, where the work involves any of the relevant operations in a shipyard, whether or not the shipyard forms part of a harbour or wet dock.",
          provision: []
        },
        %{
          rule:
            "These Regulations shall not apply to a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F22015], and in which the only activity being undertaken is construction work within the meaning of those Regulations",
          provision: []
        },
        %{
          rule:
            "Regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to a workplace which is or is in or on a ship, which is indoors.",
          provision: []
        },
        %{
          rule: "Regulations 18 and 25A apply to a workplace which is or is in or on a ship,.",
          provision: []
        },
        %{
          rule: "These Regulations shall not apply to a workplace located below ground at a mine",
          provision: []
        },
        %{
          rule:
            "Regulation 20 applies to a workplace which is or is in or on a ship, subject to the modification in paragraph (7).",
          provision: []
        }
      ]
    },
    %{
      rule:
        "As respects any workplace which is or is in or on an aircraft, locomotive or rolling stock, trailer or semi-trailer used as a means of transport or a vehicle for which a licence is in force under the Vehicles (Excise) Act 1971 or a vehicle exempted from duty under that Act—\n(a) regulations 5 to 12 and 14 to 25 shall not apply to any such workplace; and\n(b) regulation 13 shall apply to any such workplace only when the aircraft, locomotive or rolling stock, trailer or semi-trailer or vehicle is stationary inside a workplace and, in the case of a vehicle for which a licence is in force under the Vehicles (Excise) Act 1971, is not on a public road.",
      result: [
        %{
          rule:
            "Regulations 5 to 12 and 14 to 25 shall not apply to a workplace which is or is in or on an aircraft, locomotive or rolling stock, trailer or semi-trailer used as a means of transport or a vehicle for which a licence is in force under the Vehicles (Excise) Act 1971 or a vehicle exempted from duty under that Act.",
          provision: []
        },
        %{
          rule:
            "Regulation 13 shall apply to a workplace which is or is in or on an aircraft, locomotive or rolling stock, trailer or semi-trailer used as a means of transport or a vehicle for which a licence is in force under the Vehicles (Excise) Act 1971 or a vehicle exempted from duty under that Act only when the aircraft, locomotive or rolling stock, trailer or semi-trailer or vehicle is stationary inside a workplace and, in the case of a vehicle for which a licence is in force under the Vehicles (Excise) Act 1971, is not on a public road.",
          provision: []
        }
      ]
    },
    %{
      rule:
        "As respects any workplace which is in fields, woods or other land forming part of an agricultural or forestry undertaking but which is not inside a building and is situated away from the undertaking's main buildings—\n(a) regulations 5 to 19 and 23 to 25 shall not apply to any such workplace; and\n(b) any requirement to ensure that any such workplace complies with any of regulations 20 to 22 shall have effect as a requirement to so ensure so far as is reasonably practicable.",
      result: [
        %{
          rule:
            "Regulations 5 to 19 and 23 to 25 shall not apply to a workplace which is in fields, woods or other land forming part of an agricultural or forestry undertaking _but_ which is not inside a building and is situated away from the undertaking's main buildings.",
          provision: []
        },
        %{
          rule:
            "As respects any workplace which is in fields, woods or other land forming part of an agricultural or forestry undertaking but which is not inside a building and is situated away from the undertaking's main buildings any requirement to ensure that any such workplace complies with any of regulations 20 to 22 shall have effect as a requirement to so ensure so far as is reasonably practicable.",
          provision: []
        }
      ]
    },
    %{
      rule:
        "The requirements imposed by these Regulations on an employer shall also apply—\n(a) to a relevant self-employed person, in respect of work equipment he uses at work;\n(b) subject to paragraph (5), to a person who has control to any extent of—\n(i) work equipment;\n(ii) a person at work who uses or supervises or manages the use of work equipment; or\n(iii) the way in which work equipment is used at work,\nand to the extent of his control.",
      result: [
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply to a relevant self-employed person, in respect of work equipment he uses at work.",
          provision: []
        },
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply subject to paragraph (5), to a person who has control to any extent of the way in which work equipment is used at work, and to the extent of his control.",
          provision: []
        },
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply subject to paragraph (5), to a person who has control to any extent of a person at work who uses or supervises or manages the use of work equipment and to the extent of his control.",
          provision: []
        },
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply subject to paragraph (5), to a person who has control to any extent of work equipment and to the extent of his control.",
          provision: []
        }
      ]
    },
    %{
      rule:
        "These Regulations shall apply—\n(a) in Great Britain; and\n(b) outside Great Britain as sections 1 to 59 and 80 to 82 of the 1974 Act apply by virtue of articles 7 and 8(a) of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 1995 save in relation to anything to which articles 4 to 6 of that Order apply.",
      result: [
        %{rule: "These Regulations shall apply in Great Britain.", provision: []},
        %{
          rule:
            "These Regulations shall apply outside Great Britain as sections 1 to 59 and 80 to 82 of the 1974 Act apply by virtue of articles 7 and 8(a) of the Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 1995 save in relation to anything to which articles 4 to 6 of that Order apply.",
          provision: []
        }
      ]
    }
  ]

  def data(), do: @data
end
