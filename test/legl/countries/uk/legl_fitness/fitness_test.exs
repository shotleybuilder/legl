defmodule Legl.Countries.Uk.LeglFitness.FitnessTest do
  # mix test test/legl/countries/uk/legl_fitness/fitness_test.exs:8
  use ExUnit.Case, async: true
  alias Legl.Countries.Uk.LeglFitness.Fitness

  @articles [
    %{
      rule:
        "Where a duty is placed by these Regulations on an employer in respect of his employees, he shall, so far as is reasonably practicable, be under a like duty in respect of any other person, whether at work or not, who may be affected by the work carried out by the employer except that the duties of the employer—\n(a) under regulation 10 (medical surveillance) shall not extend to persons who are not his employees other than employees of another employer who are working under the direction of the first-mentioned employer; and\n(b) under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees, unless those persons are on the premises where the work is being carried out.",
      result: []
    },
    %{
      rule:
        "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer except that the duties of the employer—\n(a) under regulation 10 (information, instruction and training) do not extend to persons who are not employees of that employer unless those persons are on the premises where the work is being carried out; and\n(b) under regulation 22 (health records and medical surveillance) do not extend to persons who are not employees of that employer.",
      result: []
    },
    #
    %{
      rule:
        "Where a duty is placed by these Regulations on an employer in respect of its employees, the employer must, so far as is reasonably practicable, be under a like duty in respect of any other person at work who may be affected by the work carried out by the employer except that the duties of the employer—\n(a) under regulation 5 (information and training) do not extend to persons who are not its employees, unless those persons are present in the workplace where the work is being carried out; and\n(b) under regulation 6 (health surveillance) do not extend to persons who are not its employees.",
      result: []
    },
    #
    %{
      rule:
        "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply where—\n(a) the exposure to asbestos of employees is sporadic and of low intensity; and\n(b) it is clear from the risk assessment that the exposure to asbestos of any employee will not exceed the control limit; and\n(c) the work involves—\n(i) short, non-continuous maintenance activities in which only non-friable materials are handled, or\n(ii) removal without deterioration of non-degraded materials in which the asbestos fibres are firmly linked in a matrix, or\n(iii) encapsulation or sealing of asbestos-containing materials which are in good condition, or\n(iv) air monitoring and control, and the collection and analysis of samples to ascertain whether a specific material contains asbestos.",
      result: []
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
          rule: "Air monitoring shall not apply to a self-employed person.",
          provision: ["air-monitoring"],
          scope: "Part"
        }
      ]
    }
  ]

  test "separate_rules/1" do
    Enum.each(@articles, fn %{rule: rule, result: test} ->
      IO.puts("RULE: #{rule}")

      result =
        Fitness.separate_rules(%{provision: [], rule: rule})
        |> Enum.map(&Fitness.separate_rules(&1))
        |> List.flatten()

      assert is_list(result)
      if test != [], do: assert(result == test)
      IO.inspect(result)
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
    "Where a duty is placed by these Regulations on an employer in respect of employees of that employer, the employer is, so far as is reasonably practicable, under a like duty in respect of any other person, whether at work or not, who may be affected by the work activity carried out by that employer except that the duties of the employer.",
    #
    "Regulations 9 (notification of work with asbestos), 18(1)(a) (designated areas) and 22 (health records and medical surveillance) do not apply",
    #
    "Regulation 17 (cleanliness of premises and plant), to the extent that it requires an employer",
    #
    "Notification of work with asbestos, designated areas, health records, medical surveillance do not apply where the work involves",
    #
    "under regulations 9, 11(1) and (2) and 12 (which relate respectively to monitoring, information and training and dealing with accidents) shall not extend to persons who are not his employees, unless those persons are on the premises where the work is being carried out."
  ]

  test "parse_regulation_references" do
    Enum.each(@rules, fn rule ->
      param = %{provision: [], rule: rule}
      result = Fitness.parse_regulation_references(param)
      IO.inspect(result)
      assert is_map(result)
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
