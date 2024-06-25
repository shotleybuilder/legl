defmodule Legl.Countries.Uk.LeglFitness.Rule do
  @moduledoc """
  Functions to manage record creation and update in the Legal Fitness RULE Table (LFRT)
  """

  require Logger

  # alias __MODULE__

  @type t :: %__MODULE__{
          record_id: String.t(),
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
           only: [:record_id, :rule, :lrt, :lft, :heading, :scope, :provision_number, :provision]}
  defstruct record_id: "",
            rule: "",
            lrt: [],
            lft: [],
            heading: "",
            scope: nil,
            provision_number: [],
            provision: []

  @spec lfrt_fields() :: [String.t()]
  def lfrt_fields(),
    do:
      new()
      |> Map.from_struct()
      |> Map.drop([:record_id])
      |> Enum.map(fn {k, _v} -> Atom.to_string(k) end)

  @spec new() :: __MODULE__.t()
  def new(), do: %__MODULE__{}

  @spec new(map()) :: __MODULE__.t()
  def new(%{"record_id" => _} = attrs) do
    %__MODULE__{
      record_id: Map.get(attrs, "record_id", ""),
      rule: Map.get(attrs, "rule", ""),
      lrt: Map.get(attrs, "lrt", []),
      lft: Map.get(attrs, "fitness", []),
      heading: Map.get(attrs, "heading"),
      scope: Map.get(attrs, "scope"),
      provision_number: Map.get(attrs, "provision_number", []),
      provision: Map.get(attrs, "provision", [])
    }
  end

  def new(attrs) do
    %__MODULE__{
      record_id: Map.get(attrs, :record_id, ""),
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
          String.t(),
          list(String.t()),
          list(String.t()),
          String.t(),
          String.t(),
          list(String.t()),
          list(String.t())
        ) :: __MODULE__.t()
  def new(record_id, rule, lrt, lft, heading, scope, provision_number, provision) do
    %__MODULE__{
      record_id: record_id,
      rule: rule,
      lrt: lrt,
      lft: lft,
      heading: heading,
      scope: scope,
      provision_number: provision_number,
      provision: provision
    }
  end

  @spec add_rule(t, String.t()) :: __MODULE__.t()
  def add_rule(rule, value) do
    %{rule | rule: [value | rule.rule]}
  end
end
