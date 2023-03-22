defmodule Legl.Countries.Uk.UkRepealRevoke do
  @moduledoc """

    Module checks the amendments table of a piece of legislation for a table row that
    describes the law as having been repealed or revoked.any()

    Saves the results as a .csv file with the fields given by @fields



  """

  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Countries.Uk.UkAirtable, as: AT
  alias Legl.Airtable.AirtableIdField, as: ID

  defstruct [
    :title,
    :amending_title,
    :path,
    :type,
    :year,
    :number,
    :code,
    :revoked_by,
    :description
  ]

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Amendment.amendment_parser/1

  @at_type %{
    ukpga: ["ukpga"],
    uksi: ["uksi"],
    ni: ["nia", "apni", "nisi", "nisr", "nisro"],
    s: ["asp", "ssi"],
    uk: ["ukpga", "uksi"],
    w: ["anaw", "mwa", "wsi"],
    o: ["ukcm", "ukla", "asc", "ukmo", "apgb", "aep"]
  }
  @at_csv "airtable_repeal_revoke"
  @code_full "❌ Revoked / Repealed / Abolished"
  @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"
  @at_url_field "leg.gov.uk - changes"

  @fields ~w[
    Name
    Live?
    Revoked_by
    Live?_description
  ] |> Enum.join(",")
  @doc """
    Run in iex as
     Legl.Countries.Uk.UkRepealRevoke.full_workflow()

    Having set @at_type and the formula to return the correct AT records for process
  """
  def full_workflow(t) when is_atom(t) do

    {:ok, file} = "lib/#{@at_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])
    IO.puts(file, @fields)

    t = Map.get(@at_type, t)
    Enum.each(t, fn x -> full_workflow(file, x) end)

    File.close(file)
  end

  def full_workflow(file, type) do
    formula = ~s/AND({type_code}="#{type}",{Live?}=BLANK())/
    #formula = ~s/{type_code}="#{type}"/
    #formula = ~s/AND({type_code}="#{type}",{Live?}="#{@code_part}")/
    #formula = ~s/AND({type_code}="#{type}",OR({Live?}="#{@code_part}",{Live?}="#{@code_full}"))/
    opts =
      [
        formula: formula,
        fields: ["Name", "Title_EN", @at_url_field],
        view: "REPEALED_REVOKED"
      ]
    func = &__MODULE__.make_csv_workflow/3
    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      {:ok, msg} <- AT.enumerate_at_records({file, records}, @at_url_field, func)
    ) do
      IO.puts(msg)
    end
  end

  def make_csv_workflow(file, name, url) do
    with(
      {:ok, table_data} <- RecordGeneric.leg_gov_uk_html(url, @client, @parser),
      {:ok, result} <- repeal_revoke_description(table_data),
      {:ok, result} <- process_amendment_table(table_data, result),
      {:ok, result} <- at_revoked_by_field(table_data, result)
    ) do
      save_to_csv(name, result, file)
    else
      :ok -> :ok
      {:live, result} ->
        save_to_csv(name, result, file)
      {:error, code, response, _} ->
        IO.puts("#{code} #{response}")
      {nil, msg} ->
        IO.puts("#{name} #{msg}")
      {:error, code, response} ->
        IO.puts("#{code} #{response}")
      {:error, error} ->
        {:error, error}
    end
  end
  def save_to_csv(name, %{description: ""}, file) do
    # no revokes or repeals
    ~s/#{name},#{@code_live}/ |> (&(IO.puts(file, &1))).()
  end
  def save_to_csv(name, %{description: nil}, file) do
    # no revokes or repeals
    ~s/#{name},#{@code_live}/ |> (&(IO.puts(file, &1))).()
  end
  def save_to_csv(name, r, file) do
    # part revoke or repeal
    if "" != r.description |> to_string() |> String.trim() do
      ~s/#{name},#{r.code},#{r.revoked_by},#{r.description}/
      |> (&(IO.puts(file, &1))).()
    end
    :ok
  end

  def process_amendment_table([], result) do
    {:live, Map.put(result, :code, @code_live)}
  end

  def process_amendment_table(_, %{description: nil} = result) do
    {:live, Map.put(result, :code, @code_live)}
  end

  def process_amendment_table([{"tbody", _, records}], result) do
    result =
      Enum.reduce_while(records, result, fn {_, _, x}, acc ->
        case proc_amd_tbl_row(x) do
          {:ok, title, "Regulations", "revoked", amending_title, path} ->
            update_acc(title, amending_title, path, @code_full, acc)

          {:ok, title, "Order", "revoked", amending_title, path} ->
            update_acc(title, amending_title, path, @code_full, acc)

          {:ok, title, "Act", "repealed", amending_title, path} ->
            update_acc(title, amending_title, path, @code_full, acc)

          _ -> {:cont, acc}
        end
      end)
    {:ok, result}
  end

  def update_acc(title, amending_title, path, code, acc) do
    [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)

    Map.merge(acc,
      %{
        title: title,
        amending_title: amending_title,
        path: path,
        type: type,
        year: year,
        number: number,
        code: code
      })
    |> (&({:halt, &1})).()
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
        #|> IO.inspect()
      _ -> {:error, "no match"}
    end
  end
  @doc """
    Groups the revocation / repeal clauses by -
      Amending law
        Revocation / repeal phrase
          Provisions revoked or repealed
  """
  def repeal_revoke_description([]) do
    Map.merge(%__MODULE__{}, %{description: nil, code: @code_live})
    |> (&({:live, &1})).()
  end
  def repeal_revoke_description(records) do
    records
    |> revoke_repeal_details()
    |> make_repeal_revoke_data_structure()
    |> sort_on_amending_law_year()
    |> convert_to_string()
    |> string_for_at_field()
    |> (&({:ok, &1})).()
  end
  @doc """

  """
  def at_revoked_by_field(records, result) do
    records
    |> revoke_repeal_details()
    |> Enum.reduce([], fn {_, _, _, x}, acc ->
      x = Regex.replace(~r/\s/u, x, " ")
      [_, title] =
        case Regex.run(~r/(.*)[ ]\d*💚️/, x) do
          [_, title] -> [nil, title]
          _ ->
            case Regex.run(~r/(.*)[ ]\d{4}[ ]\(repealed\)💚️/, x) do
              [_, title] ->
                [nil, title]
              _ ->
                IO.puts("PROBLEM TITLE #{x}")
                [nil, x]
            end
        end
      [_, type, year, number] =
        Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d*)/, x)
      [ID.id(title, type, year, number) | acc]
    end)
    |> Enum.uniq()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
    |> (&(Map.merge(result, %{revoked_by: &1}))).()
    |> (&({:ok, &1})).()
  end
  @doc """
    INPUT
    OUTPUT
    [
      {"Forestry Act 1967", "s. 39(5)", "repealed",
      "Requirements of Writing (Scotland) Act 1995💚️https://legislation.gov.uk/id/ukpga/1995/7"},
      {"Forestry Act 1967", "Act", "power to repealed or amended (prosp.)",
      "Government of Wales Act 1998💚️https://legislation.gov.uk/id/ukpga/1998/38"},
      ...
    ]
  """
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
      From revoke_repeal_details/1
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
    Enum.reduce(records, [], fn(record, acc) ->
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
@doc """
  OUTPUT
    %Legl.Countries.Uk.UkRepealRevoke{
              title: nil,
              amending_title: nil,
              path: nil,
              type: nil,
              year: nil,
              number: nil,
              code: "⭕ Part Revocation / Repeal",
              description:
              "\"Forestry and Land Management (Scotland) Act 2018💚️https://legislation.gov.uk/id/asp/2018/8💚️\trepealed💚️\t\tAct
    }
"""
  def string_for_at_field(records) do
    Enum.join(records)
    |> (&(Regex.replace(~r/^💚️/, &1, ""))).()
    |> Legl.Utility.csv_quote_enclosure()
    |> (&(Map.merge(%__MODULE__{}, %{description: &1, code: @code_part}))).()
  end
end
