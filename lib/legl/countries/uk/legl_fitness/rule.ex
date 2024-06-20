defmodule Legl.Countries.Uk.LeglFitness.Rule do
  @moduledoc """
  Functions to manage record creation and update in the Legal Fitness RULE Table (LFRT)
  """

  require Logger

  # alias __MODULE__

  @type t :: %__MODULE__{
          rule: String.t(),
          # single link to REGISTER table (lrt)
          lrt: list(String.t()),
          # single link to FITNESS table (lft)
          lft: list(String.t()),
          # Single select fields
          heading: String.t(),
          scope: String.t(),
          provision_number: list(String.t()),
          provision: list(String.t())
        }

  @derive {Jason.Encoder,
           only: [:rule, :lrt, :lft, :heading, :scope, :provision_number, :provision]}
  defstruct rule: "",
            lrt: [],
            lft: [],
            heading: nil,
            scope: nil,
            provision_number: [],
            provision: []

  @spec new() :: Legl.Countries.Uk.LeglFitness.Rule.t()
  def new() do
    %__MODULE__{}
  end

  @spec new(map()) :: t
  def new(attrs) do
    %__MODULE__{
      rule: Map.get(attrs, :rule, ""),
      lrt: Map.get(attrs, :lrt, []),
      lft: Map.get(attrs, :fitness, []),
      heading: Map.get(attrs, :heading),
      scope: Map.get(attrs, :scope),
      provision_number: Map.get(attrs, :provision_number, []),
      provision: Map.get(attrs, :provision, [])
    }
  end

  @spec new(
          String.t(),
          list(String.t()),
          list(String.t()),
          String.t(),
          String.t(),
          list(String.t()),
          list(String.t())
        ) :: t
  def new(rule, lrt, lft, heading, scope, provision_number, provision) do
    %__MODULE__{
      rule: rule,
      lrt: lrt,
      lft: lft,
      heading: heading,
      scope: scope,
      provision_number: provision_number,
      provision: provision
    }
  end

  @spec add_rule(t, String.t()) :: t
  def add_rule(rule, value) do
    %{rule | rule: [value | rule.rule]}
  end
end
