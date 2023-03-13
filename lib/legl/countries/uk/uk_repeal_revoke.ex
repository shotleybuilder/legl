defmodule Legl.Countries.Uk.UkRepealRevoke do
  @moduledoc """

    Module checks the amendments table of a piece of legislation for a table row that
    describes the law as having been repealed or revoked.any()

    Saves the results as a .csv file with the fields given by @fields



  """

  alias Legl.Services.LegislationGovUk.RecordGeneric, as: Record
  alias Legl.Countries.Uk.UkAirtable, as: AT
  alias Legl.Airtable.AirtableIdField, as: ID

  @at_type ["ukpga"]
  @at_csv "airtable_repeal_revoke"
  @code "❌ Revoked / Repealed / Abolished"
  @at_url_field "leg.gov.uk - changes"

  @fields ~w[
    Name
    Live?
    Revoked_by
    Live?_description
  ]
  @doc """
    Run in iex as
     Legl.Countries.Uk.UkRepealRevoke.full_workflow()

    Having set @at_type and the formula to return the correct AT records for process
  """
  def full_workflow() do
    Legl.Utility.csv_header_row(@fields, @at_csv)
    Enum.each(@at_type, fn x -> full_workflow(x) end)
  end

  def full_workflow(type) do
    #formula = ~s/AND({type}="#{type}",{Live?}=BLANK())/
    #formula = ~s/{type}="#{type}"/
    formula = ~s/AND({type}="#{type}",{Live?}="#{@code}")/
    opts =
      [
        formula: formula,
        fields: ["Name", "Title_EN", @at_url_field],
        view: "REPEALED_REVOKED"
      ]
    func = &__MODULE__.make_csv_workflow/2
    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      #IO.inspect(records, limit: :infinity),
      {:ok, msg} <- AT.enumerate_at_records(records, @at_url_field, func)
    ) do
      IO.puts(msg)
    end
  end

  def make_csv_workflow(name, url) do
    with(
      {:ok, table_data} <- Record.repeal_revoke(url),
      {:ok,
        %{
          title: _title,
          amending_title: amending_title,
          path: _path,
          type: type,
          year: year,
          number: number
        }
      } <- process_amendment_table(table_data),
      description <- repeal_revoke_description(table_data)
    ) do
      id = ID.id(amending_title, type, year, number)
      ~s/#{name},#{@code},#{id},#{description}/
      |> Legl.Utility.append_to_csv(@at_csv)
      :ok
    else
      :ok -> :ok
      {nil, msg} -> IO.puts("#{name} ---> #{msg}")
      {:error, code, response} ->
        IO.puts("************* #{code} #{response} **************")
      {:error, error} -> {:error, error}
    end
  end

  def process_amendment_table([]) do
    IO.puts("record.ex: number of records: 0")
    {nil, "no amendments - not repealed nor revoked"}
  end

  def process_amendment_table([{"tbody", _, records}]) do
    table =
      Enum.reduce(records, %{}, fn {_, _, x}, acc ->
        case proc_amd_tbl_row(x) do
          {:ok, title, "Regulations", "revoked", amending_title, path} ->
            update_acc(title, amending_title, path, acc)

          {:ok, title, "Act", "repealed", amending_title, path} ->
            update_acc(title, amending_title, path, acc)

          _ -> acc
        end
      end)
    case Enum.count(table) do
      0 -> {nil, "not repealed nor revoked"}
      _ -> {:ok, table}
    end
  end

  def update_acc(title, amending_title, path, acc) do
    [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)
    Map.merge(acc,
      %{
        title: title,
        amending_title: amending_title,
        path: path,
        type: type,
        year: year,
        number: number
      })
  end

  @pattern quote do: [
    {"td", _, [{_, _, [var!(title)]}]},
    {"td", _, _},
    {"td", _, [{_, [{"href", _}], [var!(amendment_target)]}]},
    {"td", _, [var!(amendment_effect)]},
    {"td", _, [{_, _, [var!(amending_title)]}]},
    {"td", _, [{_, [{"href", var!(path)}], _}]},
    {"td", _, _},
    {"td", _, _},
    {"td", _, _}
  ]

  def proc_amd_tbl_row(row) do
    case row do
      unquote(@pattern) ->
        {:ok, title, amendment_target, amendment_effect, amending_title, path}
      _ -> {:error, "no match"}
    end
  end
  @doc """
    Groups the revocation / repeal clauses by -
      Amending law
        Revocation / repeal phrase
          Provisions revoked or repealed
  """
  def repeal_revoke_description(records) do
    records
    |> revoke_repeal_details()
    |> make_repeal_revoke_data_structure()
    |> sort_on_amending_law_year()
    |> convert_to_string()
    |> string_for_at_field()
  end

  def revoke_repeal_details([{"tbody", _, records}]) do
    Enum.reduce(records, [], fn {_, _, x}, acc ->
      case proc_amd_tbl_row(x) do
        {:ok, title, amendment_target, amendment_effect, amending_title, path} ->
          case Regex.match?(~r/(repeal|revoke)/, amendment_effect) do
            true ->
              grp_by = "#{amending_title}💚️https://legislation.gov.uk#{path}"
              [
                {title, amendment_target, amendment_effect, grp_by}
                | acc
              ]
            false -> acc
          end
        _ -> acc
      end
    end)
  end

  @doc """
    INPUT
      [
        {title, amendment_target, amendment_effect, amending_title, path}
      ]
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
  """
  def make_repeal_revoke_data_structure(records) do
    Enum.group_by(records, &Kernel.elem(&1, 3))
    |> Enum.reduce([], fn {k, v}, acc ->
      Enum.group_by(v, &Kernel.elem(&1, 2), fn x -> elem(x, 1) end)
      |> (&([%{k => &1} | acc])).()
    end)
  end

  def sort_on_amending_law_year(records) do
    Enum.reduce(records, [], fn(record, acc) ->
      [key] = Map.keys(record)
      [_, yr] = Regex.run(~r/(\d{4})/, key)
      [{String.to_atom(yr), record} | acc]
    end)
    |> Enum.sort(:asc)
  end

  def convert_to_string(records) do
    Enum.reduce(records, [], fn({_, record}, acc) ->
      Enum.into(record, "", fn {k, v} ->
        Enum.into(v, "", fn {kk, vv} ->
          Enum.sort(vv, :asc)
          |> Enum.join(", ")
          |> (&("💚️\t"<>kk<>"💚️\t\t"<>&1)).()
        end)
        |> (&("💚️"<>k<>&1)).()
      end)
      |> (&([&1 | acc])).()
    end)
  end

  def string_for_at_field(records) do
    Enum.join(records)
    |> (&(Regex.replace(~r/^💚️/, &1, ""))).()
    |> Legl.Utility.csv_quote_enclosure()
  end
end
