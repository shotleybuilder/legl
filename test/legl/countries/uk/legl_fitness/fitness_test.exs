defmodule Legl.Countries.Uk.LeglFitness.FitnessTest do
  # mix test test/legl/countries/uk/legl_fitness/fitness_test.exs:8
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Countries.Uk.Support.LeglFitnessSeparateRulesTest
  alias Legl.Countries.Uk.Support.LeglFitnessTransformTest

  test "transform_articles_and_process_fitnesses/1" do
    records = Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))

    result =
      records
      |> (&Fitness.transform_articles(&1)).()
      |> (&Fitness.process_fitnesses(&1, [])).()

    IO.inspect(result)
    assert is_list(result)
  end

  test "transform_articles/1" do
    records = Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))
    result = Fitness.transform_articles(records)
    IO.inspect(result)
    assert is_list(result)
  end

  @dirty_rules [
    %{
      text:
        "3.—(1) These Regulations apply to every workplace but shall not apply to— 📌(a) a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in— 📌(i) a shipyard, whether or not the shipyard forms part of a harbour or wet dock; or 📌(ii) dock premises, not being work done— 📌(aa) by the master or crew of a ship; 📌(bb) on board a ship during a trial run; 📌(cc) for the purpose of raising or removing a ship which is sunk or stranded; or 📌(dd) on a ship which is not under command, for the purpose of bringing it under command; 📌(b) a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F6 2015 ] , and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that— 📌(i) regulations 18 and 25A apply to such a workplace; and 📌(ii) regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to such a workplace which is indoors; or 📌(c) a workplace located below ground at a mine, except that regulation 20 applies to such a workplace subject to the modification in paragraph (7). ",
      result:
        "These Regulations apply to every workplace but shall not apply to—\n(a) a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in—\n(i) a shipyard, whether or not the shipyard forms part of a harbour or wet dock; or\n(ii) dock premises, not being work done—\n(aa) by the master or crew of a ship;\n(bb) on board a ship during a trial run;\n(cc) for the purpose of raising or removing a ship which is sunk or stranded; or\n(dd) on a ship which is not under command, for the purpose of bringing it under command;\n(b) a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations 2015, and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that—\n(i) regulations 18 and 25A apply to such a workplace; and\n(ii) regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to such a workplace which is indoors; or\n(c) a workplace located below ground at a mine, except that regulation 20 applies to such a workplace subject to the modification in paragraph (7)."
    }
  ]

  test "clean_rule_text/1" do
    Enum.each(@dirty_rules, fn %{text: text, result: test_result} ->
      result = Fitness.clean_rule_text(text)
      IO.inspect(result)
      assert(result == test_result)
    end)
  end

  test "separate_rules/1" do
    Enum.each(LeglFitnessSeparateRulesTest.data(), fn %{rule: rule, result: test} ->
      IO.puts("RULE: #{rule}")

      response =
        Fitness.separate_rules(%{provision: [], rule: rule})
        |> Enum.map(&Fitness.separate_rules(&1))
        |> List.flatten()

      assert is_list(response)

      case test do
        [] ->
          :ok

        _ ->
          response_size = Enum.count(response)
          test_size = Enum.count(test)
          assert response_size == test_size

          case response_size == test_size do
            true ->
              Enum.each(0..(response_size - 1), fn i ->
                assert Enum.at(response, i) == Enum.at(test, i)
              end)

            false ->
              :ok
          end
      end

      IO.inspect(response, label: "RESULT")
    end)
  end

  test "such_clause/1" do
    records = LeglFitnessTransformTest.such()

    Enum.each(records, fn %{rule: rule, result: test_result} ->
      response = Fitness.such_clause(rule)
      IO.inspect(response)
      assert(response == test_result)
    end)
  end

  @but [
    %{
      rule:
        "These Regulations apply to every workplace but shall not apply to—\n(a)a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in—\n(i)a shipyard, whether or not the shipyard forms part of a harbour or wet dock; or\n(ii)dock premises, not being work done—\n(aa)by the master or crew of a ship;\n(bb)on board a ship during a trial run;\n(cc)for the purpose of raising or removing a ship which is sunk or stranded; or\n(dd)on a ship which is not under command, for the purpose of bringing it under command;\n(b)a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F22015], and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that—\n(i)regulations 18 and 25A apply to such a workplace; and\n(ii)regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to such a workplace which is indoors; or\n(c)a workplace located below ground at a mine, except that regulation 20 applies to such a workplace subject to the modification in paragraph (7).",
      result: [
        %{rule: "These Regulations apply to every workplace"},
        %{
          rule:
            "These Regulations shall not apply to—\n(a)a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in—\n(i)a shipyard, whether or not the shipyard forms part of a harbour or wet dock; or\n(ii)dock premises, not being work done—\n(aa)by the master or crew of a ship;\n(bb)on board a ship during a trial run;\n(cc)for the purpose of raising or removing a ship which is sunk or stranded; or\n(dd)on a ship which is not under command, for the purpose of bringing it under command;\n(b)a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F22015], and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that—\n(i)regulations 18 and 25A apply to such a workplace; and\n(ii)regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to such a workplace which is indoors; or\n(c)a workplace located below ground at a mine, except that regulation 20 applies to such a workplace subject to the modification in paragraph (7)."
        }
      ]
    }
  ]

  test "but/1" do
    Enum.each(@but, fn %{rule: rule, result: test_result} ->
      result = Fitness.but(%{rule: rule})
      IO.inspect(result)
      assert(result == test_result)
    end)
  end

  @split [
    %{
      rule:
        "(3) The requirements imposed by these Regulations on an employer shall also apply—📌(a) to a [F1 relevant self-employed person ] , in respect of work equipment he uses at work; 📌(b) subject to paragraph (5), to a person who has control to any extent of— 📌(i) work equipment; 📌(ii) a person at work who uses or supervises or manages the use of work equipment; or 📌(iii) the way in which work equipment is used at work, 📌and to the extent of his control.",
      result: [
        %{rule: "The requirements imposed by these Regulations on an employer shall also apply"},
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply to a relevant self-employed person, in respect of work equipment he uses at work"
        },
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply to a person who has control to any extent of work equipment, a person at work who uses or supervises or manages the use of work equipment or the way in which work equipment is used at work, and to the extent of his control"
        }
      ]
    }
  ]
  test "split/1" do
    Enum.each(@split, fn %{rule: rule, result: test_result} ->
      result = Fitness.split(%{rule: Fitness.clean_rule_text(rule), provision: []})
      IO.inspect(result, label: "RESULT")
      assert(result == test_result)
    end)
  end

  @save_that [
    %{
      rule:
        "These Regulations shall not apply to a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F22015], and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that regulations 18 and 25A apply to such a workplace.",
      result: [
        %{
          rule:
            "These Regulations shall not apply to a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F22015], and in which the only activity being undertaken is construction work within the meaning of those Regulations"
        },
        %{
          rule:
            "Regulations 18 and 25A apply to a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F22015], and in which the only activity being undertaken is construction work within the meaning of those Regulations."
        }
      ]
    },
    %{
      rule:
        "Paragraph (6) does not apply to a ship's work equipment provided for use or used in an activity (whether carried on in or outside Great Britain) specified in the 1995 Order save that it does apply to the construction, reconstruction, finishing, refitting, repair, maintenance, cleaning or breaking up of the ship.",
      result: [
        %{
          rule:
            "Paragraph (6) does not apply to a ship's work equipment provided for use or used in an activity (whether carried on in or outside Great Britain) specified in the 1995 Order"
        },
        %{
          rule:
            "Paragraph (6) does apply to the construction, reconstruction, finishing, refitting, repair, maintenance, cleaning or breaking up of the ship."
        }
      ]
    }
  ]

  test "save_that/1" do
    Enum.each(@save_that, fn %{rule: rule, result: test_result} ->
      result = Fitness.save_that(%{rule: rule})
      IO.inspect(result)
      assert(result == test_result)
    end)
  end

  @unless [
    %{
      test:
        "under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees, unless those persons are on the premises where the work is being carried out.",
      result: [
        "under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees",
        "under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall extend to those persons are on the premises where the work is being carried out."
      ]
    }
  ]

  test "unless/1" do
    Enum.each(@unless, fn %{test: rule, result: test} ->
      result = Fitness.unless([rule])
      IO.inspect(result)
      assert(result == test)
    end)
  end

  @rules [
    %{
      test:
        "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer except that the duties of the employer.",
      result: %{
        rule:
          "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer except that the duties of the employer.",
        provision: []
      }
    },
    #
    %{
      test:
        "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply",
      result: %{
        scope: "Part",
        rule:
          "Notification of work with asbestos, designated areas, health records, medical surveillance do not apply",
        provision: [
          "notification-of-work-with-asbestos",
          "designated-areas",
          "health-records",
          "medical-surveillance"
        ]
      }
    },
    #
    %{
      test:
        "Regulation 17 (cleanliness of premises and plant), to the extent that it requires an employer",
      result: %{
        scope: "Part",
        rule:
          "Cleanliness of premises, cleanliness of plant, to the extent that it requires an employer",
        provision: ["cleanliness-of-premises", "cleanliness-of-plant"]
      }
    },
    #
    %{
      test:
        "Notification of work with asbestos, designated areas, health records, medical surveillance do not apply where the work involves",
      result: %{
        rule:
          "Notification of work with asbestos, designated areas, health records, medical surveillance do not apply where the work involves",
        provision: []
      }
    },
    #
    %{
      test:
        "under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees, unless those persons are on the premises where the work is being carried out.",
      result: %{
        scope: "Part",
        rule:
          "Monitoring, information, training, dealing with accidents shall not extend to persons who are not his employees, unless those persons are on the premises where the work is being carried out.",
        provision: ["monitoring", "information", "training", "dealing-with-accidents"]
      }
    },
    #
    %{
      test:
        "Regulation 12 does not apply to a workplace located above ground at a mine that is a tip (within the meaning of regulation 2(1) of the Mines Regulations 2014).",
      result: %{
        scope: "Part",
        rule:
          "Does not apply to a workplace located above ground at a mine that is a tip (within the meaning of regulation 2(1) of the Mines Regulations 2014).",
        provision: []
      }
    },
    %{
      test:
        "These Regulations apply to every workplace but shall not apply to a workplace located below ground at a mine",
      result: %{
        rule: "Shall not apply to a workplace located below ground at a mine",
        provision: []
      }
    }
  ]

  test "parse_regulation_references" do
    Enum.each(@rules, fn %{test: rule, result: test_result} ->
      param = %{provision: [], rule: rule}
      result = Fitness.parse_regulation_references(param)
      IO.puts("RULE: #{rule}")
      IO.inspect(result)
      assert is_map(result)
      assert result == test_result
    end)
  end

  @ande [
    "health records and medical surveillance",
    "cleanliness of premises and plant",
    "which relate respectively to monitoring, information and training and dealing with accidents",
    "medical surveillance"
  ]

  test "split_and/1" do
    Enum.each(@ande, fn ande ->
      result = Fitness.split_and(ande)
      IO.inspect(result)
      assert is_list(result)
    end)
  end
end
