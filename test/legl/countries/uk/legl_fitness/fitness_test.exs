defmodule Legl.Countries.Uk.LeglFitness.FitnessTest do
  @moduledoc false
  # mix test test/legl/countries/uk/legl_fitness/fitness_test.exs:8
  require Logger
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness.Fitness
  alias Legl.Countries.Uk.LeglFitness.RuleTransform, as: RT
  alias Legl.Countries.Uk.LeglFitness.RuleSeparate, as: RS
  alias Legl.Countries.Uk.LeglFitness.RuleSplit
  alias Legl.Countries.Uk.Support.LeglFitnessSeparateRulesTest
  alias Legl.Countries.Uk.Support.LeglFitnessTransformTest

  test "transform_articles_and_process_fitnesses_and_extension_outside_gb/1" do
    records = Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))

    result =
      records
      |> RT.transform_rules()
      |> Fitness.make_fitness_structs()
      |> Fitness.process_fitnesses()

    # |> Legl.Countries.Uk.LeglFitness.ParseExtendsTo.extension_outside_gb()

    result =
      Enum.filter(result, fn
        %{place: ["outside-great-britain"]} -> true
        %{rule: %{rule: "Does not extend outside Great Britain"}} -> true
        %{rule: %{rule: rule}} -> String.contains?(rule, "Great Britain")
      end)

    # IO.puts(~s/Response: #{inspect(result, pretty: true, limit: :infinity)}/)
    assert is_list(result)
    assert Enum.count(result) > 0
  end

  test "transform_articles_and_process_fitnesses/1" do
    records = Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))

    result =
      records
      |> (&RT.transform_rules(&1)).()
      |> (&Fitness.make_fitness_structs(&1)).()
      |> (&Fitness.process_fitnesses(&1)).()

    # IO.puts(~s/Response: #{inspect(result, pretty: true, limit: :infinity)}/)
    assert is_list(result)
    assert Enum.count(result) > 0
  end

  test "transform_rules/1" do
    records = Legl.Utility.read_json_records(Path.absname("lib/legl/data_files/json/parsed.json"))
    result = RT.transform_rules(records)
    # Logger.info(~s/Response: #{inspect(result, pretty: true, limit: :infinity)}/)
    assert is_list(result)
  end

  test "extension_outside_gb/1" do
    records = Legl.Countriess.Uk.Support.ExtendsOutsideGB.data()

    Enum.map(
      records,
      fn {rule, result: test_result} ->
        response = Legl.Countries.Uk.LeglFitness.ParseExtendsTo.extension_outside_gb(rule)
        assert(response == test_result)
      end
    )
  end

  @dirty_rules [
    %{
      text:
        "3.—(1) These Regulations apply to every workplace but shall not apply to— 📌(a) a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in— 📌(i) a shipyard, whether or not the shipyard forms part of a harbour or wet dock; or 📌(ii) dock premises, not being work done— 📌(aa) by the master or crew of a ship; 📌(bb) on board a ship during a trial run; 📌(cc) for the purpose of raising or removing a ship which is sunk or stranded; or 📌(dd) on a ship which is not under command, for the purpose of bringing it under command; 📌(b) a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations [F6 2015 ] , and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that— 📌(i) regulations 18 and 25A apply to such a workplace; and 📌(ii) regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to such a workplace which is indoors; or 📌(c) a workplace located below ground at a mine, except that regulation 20 applies to such a workplace subject to the modification in paragraph (7). ",
      result:
        "These Regulations apply to every workplace but shall not apply to—\n(a) a workplace which is or is in or on a ship, save that regulations 8(1) and (3) and 12(1) and (3) apply to such a workplace where the work involves any of the relevant operations in—\n(i) a shipyard, whether or not the shipyard forms part of a harbour or wet dock; or\n(ii) dock premises, not being work done—\n(aa) by the master or crew of a ship;\n(bb) on board a ship during a trial run;\n(cc) for the purpose of raising or removing a ship which is sunk or stranded; or\n(dd) on a ship which is not under command, for the purpose of bringing it under command;\n(b) a workplace which is a construction site within the meaning of the Construction (Design and Management) Regulations 2015, and in which the only activity being undertaken is construction work within the meaning of those Regulations, save that—\n(i) regulations 18 and 25A apply to such a workplace; and\n(ii) regulations 7(1A), 12, 14, 15, 16, 18, 19 and 26(1) apply to such a workplace which is indoors; or\n(c) a workplace located below ground at a mine, except that regulation 20 applies to such a workplace subject to the modification in paragraph (7)."
    },
    %{
      text:
        "[F3 (3) These Regulations shall not apply to the master or crew of a ship or to the employer of such persons in respect of the normal shipboard activities of a ship’s crew which— 📌(a) are carried out solely by the crew under the direction of the master; and 📌(b) are not liable to expose persons other than the master and crew to a risk to their health and safety, 📌and for the purposes of this paragraph “ship” includes every description of vessel used in navigation, other than a ship forming part of Her Majesty’s Navy. ] ",
      result:
        "These Regulations shall not apply to the master or crew of a ship or to the employer of such persons in respect of the normal shipboard activities of a ship's crew which—\n(a) are carried out solely by the crew under the direction of the master; and\n(b) are not liable to expose persons other than the master and crew to a risk to their health and safety,\nand for the purposes of this paragraph “ship” includes every description of vessel used in navigation, other than a ship forming part of Her Majesty's Navy."
    }
  ]

  test "clean_rule_text/1" do
    Enum.each(@dirty_rules, fn %{text: text, result: test_result} ->
      result = RT.clean_rule_text(text)
      # Logger.info(~s/Response: #{result}/)
      assert(result == test_result)
    end)
  end

  test "separate_rules/1" do
    Enum.each(LeglFitnessSeparateRulesTest.data(), fn %{rule: rule, result: test} ->
      # Logger.info("TEST RULE: #{rule}")

      response =
        RS.separate_rules(%{provision: [], rule: rule})
        |> Enum.map(&RS.separate_rules(&1))
        |> List.flatten()

      Enum.each(response, &Logger.info(~s/#{inspect(&1)}/, ansi_color: :blue))

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
    end)
  end

  test "process_field/1" do
    records = Legl.Countries.Uk.Support.ProcessField.data()

    Enum.map(
      records,
      fn %{test: test, result: result} ->
        response = Fitness.process_field(test)
        assert(response == result)
      end
    )
  end

  test "such_clause/1" do
    records = LeglFitnessTransformTest.such()

    Enum.each(records, fn %{rule: rule, result: test_result} ->
      # Logger.info(~s/Rule: #{rule}/)
      response = RS.such_clause(rule)
      # Logger.info(~s/Response: #{response}/, ansi_color: :blue)
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
      result = RS.but(%{rule: rule})
      # Logger.info(~s/Response: #{inspect(result, pretty: true, limit: :infinity)}/)
      assert(result == test_result)
    end)
  end

  @split [
    %{
      rule:
        "(3) The requirements imposed by these Regulations on an employer shall also apply—📌(a) to a [F1 relevant self-employed person ] , in respect of work equipment he uses at work; 📌(b) subject to paragraph (5), to a person who has control to any extent of— 📌(i) work equipment; 📌(ii) a person at work who uses or supervises or manages the use of work equipment; or 📌(iii) the way in which work equipment is used at work, 📌and to the extent of his control.",
      result: [
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply to a relevant self-employed person, in respect of work equipment he uses at work."
        },
        %{
          rule:
            "The requirements imposed by these Regulations on an employer shall also apply subject to paragraph (5), to a person who has control to any extent of—\n(i) work equipment;\n(ii) a person at work who uses or supervises or manages the use of work equipment; or\n(iii) the way in which work equipment is used at work,\nand to the extent of his control."
        }
      ]
    }
  ]
  test "split/1" do
    Enum.each(@split, fn %{rule: rule, result: test_result} ->
      result = RuleSplit.split(%{rule: RT.clean_rule_text(rule)})
      # Logger.info(~s/Response: #{inspect(result, pretty: true, limit: :infinity)}/)
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
      result = RS.save_that(%{rule: rule})
      # Logger.info(~s/Response: #{inspect(result, pretty: true, limit: :infinity)}/)
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
      result = RuleSplit.unless_([rule])
      # Logger.info(~s/Response: #{result}/)
      assert(result == test)
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
      # Logger.info(~s/Response: #{result}/)
      assert is_list(result)
    end)
  end
end
