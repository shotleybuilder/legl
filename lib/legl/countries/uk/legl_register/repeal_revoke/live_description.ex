defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RRDescription do
  @moduledoc """
  Module to handle generating the content of the '"Live?_description"' field
  """
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke
  alias Legl.Countries.Uk.LeglRegister.LegalRegister

  @doc """
    Groups the revocation / repeal clauses by -
      Amending law
        Revocation / repeal phrase
          Provisions revoked or repealed
  """
  @spec live_description(list(%RepealRevoke{}), %LegalRegister{}, map()) ::
          {:ok, %LegalRegister{}}
  def live_description(records, lr_struct, opts) do
    records
    |> make_repeal_revoke_data_structure()
    |> sort_on_amending_law_year()
    |> convert_to_string()
    |> string_for_at_field()

    # |> (&{:ok, &1}).()
  end

  @doc """
      INPUT
        From rr_filter/1
      OUTPUT
        [
          %{"The Scotland Act 1998 ... Order 1999💚️https://legislation.gov.uk/id/uksi/1999/1747" =>
            %{"repealed in part" => ["s. 41"]}},
          %{
            "The Public Bodies ... Order 2015💚️https://legislation.gov.uk/id/uksi/2015/475" =>
            %{
              "repealed" => ["s. 38(2)", "s. 38(1)", "s. 37(2)", "s. 37(1)(a)"],
              "words repealed" => ["s. 38(4)", "s. 38(1B)", "s. 32(1)"]
            }
          }
        ]

    def make_repeal_revoke_data_structure(records) do
      Enum.group_by(records, &Kernel.elem(&1, 3))
      |> Enum.reduce([], fn {k, v}, acc ->
        Enum.group_by(v, &Kernel.elem(&1, 2), fn x -> elem(x, 1) end)
        |> (&[%{k => &1} | acc]).()
      end)
    end
  """
  def make_repeal_revoke_data_structure(records) do
    Enum.group_by(records, & &1.amending_title_and_path)
    |> Enum.reduce([], fn {k, v}, acc ->
      Enum.group_by(v, & &1.affect, & &1.target)
      |> (&[%{k => &1} | acc]).()
    end)
  end

  @doc """
    OUTPUT
    [
      "1995": %{
        "Requirements of Writing (Scotland) Act 1995💚️https://legislation.gov.uk/id/ukpga/1995/7" => %{
          "repealed" => ["s. 39(5)"]
        }
      },
      "1998": %{
        "Government of Wales Act 1998💚️https://legislation.gov.uk/id/ukpga/1998/38" => %{
          "power to repealed or amended (prosp.)" => ["Act"]
        }
        ...
    ]
  """
  def sort_on_amending_law_year(records) do
    Enum.reduce(records, [], fn record, acc ->
      [key] = Map.keys(record)
      [_, yr] = Regex.run(~r/(\d{4})/, key)
      [{String.to_atom(yr), record} | acc]
    end)
    |> Enum.sort(:asc)
  end

  @doc """
    OUTPUT
    [
      "💚️Forestry and Land Management (Scotland) Act 2018💚️https://legislation.gov.uk/id/asp/2018/8💚️\trepealed💚️\t\tAct",
      ...
    ]
  """
  def convert_to_string(records) do
    Enum.reduce(records, [], fn {_, record}, acc ->
      Enum.into(record, "", fn {k, v} ->
        Enum.into(v, "", fn {kk, vv} ->
          Enum.sort(vv, :asc)
          |> Enum.join(", ")
          |> (&("💚️ " <> kk <> "💚️ " <> &1)).()
        end)
        |> (&("💚️" <> k <> &1)).()
      end)
      |> (&[&1 | acc]).()
    end)
  end

  @doc """
    OUTPUT
      %Legl.Countries.Uk.UkRepealRevoke{
                Title_EN: nil,
                amending_title: nil,
                path: nil,
                type_code: nil,
                Year: nil,
                Number: nil,
                "Live?": "⭕ Part Revocation / Repeal",
                "Live?_description":
                "\"Forestry and Land Management (Scotland) Act 2018💚️https://legislation.gov.uk/id/asp/2018/8💚️ repealed💚️ Act
      }
  """
  def string_for_at_field(records) do
    Enum.join(records)
    |> (&Regex.replace(~r/^💚️/, &1, "")).()
  end
end
