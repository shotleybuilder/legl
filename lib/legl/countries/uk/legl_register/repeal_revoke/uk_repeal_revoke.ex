defmodule Legl.Countries.Uk.RepealRevoke.RepealRevoke do
  @moduledoc """

    Module checks the amendments table of a piece of legislation for a table row
    that describes the law as having been repealed or revoked.any()

    Saves the results as a .csv file with the fields given by @fields

    Example

    Legl.Countries.Uk.UkRepealRevoke.run(base_name: "UK S", type_code:
    :nia, field_content: [{"Live?_description", ""}], new?: false)

  """

  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Airtable.AirtableIdField, as: ID
  alias Legl.Airtable.AirtableTitleField, as: Title
  alias Legl.Services.Airtable.AtBasesTables

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

  @at_csv ~s[lib/legl/countries/uk/legl_register/repeal_revoke/repeal_revoke.csv]
          |> Path.absname()
  @rr_new_law ~s[lib/legl/countries/uk/legl_register/repeal_revoke/rr_new_law.csv]
              |> Path.absname()
  @code_full "❌ Revoked / Repealed / Abolished"
  @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"
  @at_url_field "leg.gov.uk - changes"

  @live %{
    green: @code_live,
    amber: @code_part,
    red: @code_full
  }

  # these are the fields that will be updated in Airtable
  @fields_update ~w[
    Name
    Live?
    Revoked_by
    Live?_description
  ] |> Enum.join(",")

  @default_opts %{
    # new? option selects blank Live? field records
    # field content is list of tuples of {field name, content state}
    name: "",
    field_content: "",
    new?: true,
    base_name: "UK E",
    type_code: [""],
    type_class: "",
    sClass: "",
    # a list
    live: "",
    fields_source: ["Name", "Title_EN", @at_url_field],
    fields_update: @fields_update,
    fields_new_law: ~w[Name Title_EN type_code Year Number] |> Enum.join(","),
    view: "VS_CODE_REPEALED_REVOKED"
  }
  @doc """
    Run in iex as
     Legl.Countries.Uk.UkRepealRevoke.full_workflow()

  """
  def run(opts \\ []) do
    opts = Enum.into(opts, @default_opts)

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})

    opts = live_field_formula(opts)
    opts = field_content(opts)

    with {:ok, type_codes} <- Legl.Countries.Uk.UkTypeCode.type_code(opts.type_code),
         {:ok, type_classes} <- Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class),
         {:ok, sClass} <- Legl.Countries.Uk.SClass.sClass(opts.sClass),
         opts =
           Map.merge(opts, %{type_code: type_codes, type_class: type_classes, sClass: sClass}),
         IO.puts("OPTIONS: #{inspect(opts)}"),
         {:ok, file} <- @at_csv |> File.open([:utf8, :write]),
         IO.puts(file, opts.fields_update),
         {:ok, file_new_law} <- @rr_new_law |> File.open([:utf8, :write]),
         IO.puts(file_new_law, opts.fields_new_law) do
      Enum.each(type_codes, fn type ->
        IO.puts(">>>#{type}")

        IO.puts("#{formula(type, opts)}")

        opts =
          Map.merge(
            opts,
            %{formula: formula(type, opts), file_new_law: file_new_law, file: file}
          )

        workflow(opts)
      end)

      File.close(file)
      File.close(file_new_law)
    else
      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  defp field_content(%{field_content: ""} = opts), do: opts

  defp field_content(opts) do
    f =
      Enum.reduce(opts.field_content, [], fn {field, content}, acc ->
        content = if content == "", do: "BLANK()", else: ~s/"#{content}"/
        [~s/{#{field}}=#{content}/ | acc]
      end)

    f = ~s/#{Enum.join(f, ",")}/

    Map.put(opts, :field_content, f)
  end

  defp live_field_formula(%{live: ""} = opts), do: opts

  defp live_field_formula(%{live: live} = opts) when is_binary(live) do
    Map.put(opts, :live, ~s/{Live?}="#{Map.get(@live, live)}"/)
  end

  defp live_field_formula(%{live: live} = opts) when is_list(live) do
    formula =
      Enum.reduce(opts.live, "", fn x, acc ->
        case Map.get(@live, x) do
          nil -> acc
          res -> acc <> ~s/{Live?}="#{res}"/
        end
      end)

    case formula do
      "" ->
        Map.put(opts, :live, "")

      _ ->
        formula
        |> (&fn -> ~s/OR(#{&1})/ end).()
        |> (&Map.put(opts, :live, &1)).()
    end
  end

  defp formula(type, %{name: ""} = opts) do
    f = if opts.new?, do: [~s/{Live?}=BLANK()/], else: []
    f = if opts.type_code != [""], do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f
    f = if opts.sClass != "", do: [~s/{sClass}="#{opts.sClass}"/ | f], else: f
    f = if opts.live != "", do: [opts.live | f], else: f
    f = if opts.field_content != "", do: [opts.field_content | f], else: f
    ~s/AND(#{Enum.join(f, ",")})/
  end

  defp formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end

  def workflow(opts) do
    opts = Map.put(opts, :fields, opts.fields_source)

    func = &__MODULE__.make_csv_workflow/3

    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      {:ok, msg} <- AT.enumerate_at_records(records, opts, func)
    ) do
      IO.puts(msg)
    end
  end

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Amendment.amendment_parser/1

  def make_csv_workflow(name, url, opts) do
    with(
      {:ok, table_data} <- RecordGeneric.leg_gov_uk_html(url, @client, @parser),
      {:ok, raw_data} <- revoke_repeal_details(table_data),
      {:ok, result} <- repeal_revoke_description(raw_data),
      {:ok, result} <- process_amendment_table(table_data, result),
      {:ok, result} <- at_revoked_by_field(raw_data, result),
      {:ok, new_law} <- new_law(raw_data)
    ) do
      save_to_csv(name, result, opts.file)
      save_new_law(new_law, opts.file_new_law)
    else
      :ok ->
        :ok

      {:live, result} ->
        save_to_csv(name, result, opts.file)

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
    ~s/#{name},#{@code_live}/ |> (&IO.puts(file, &1)).()
  end

  def save_to_csv(name, %{description: nil}, file) do
    # no revokes or repeals
    ~s/#{name},#{@code_live}/ |> (&IO.puts(file, &1)).()
  end

  def save_to_csv(name, r, file) do
    # part revoke or repeal
    if "" != r.description |> to_string() |> String.trim() do
      ~s/#{name},#{r.code},#{r.revoked_by},#{r.description}/
      |> (&IO.puts(file, &1)).()
    end

    :ok
  end

  def save_new_law(new_laws, file) do
    new_laws
    |> IO.inspect()
    |> Enum.uniq()
    |> Enum.each(fn law ->
      IO.puts(file, law)
    end)
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

          _ ->
            {:cont, acc}
        end
      end)

    {:ok, result}
  end

  def update_acc(title, amending_title, path, code, acc) do
    [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)

    Map.merge(
      acc,
      %{
        title: title,
        amending_title: amending_title,
        path: path,
        type: type,
        year: year,
        number: number,
        code: code
      }
    )
    |> (&{:halt, &1}).()
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

      # |> IO.inspect()
      _ ->
        {:error, "no match"}
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
    |> (&{:live, &1}).()
  end

  def repeal_revoke_description(records) do
    records
    # |> revoke_repeal_details()
    # |> elem(1)
    |> make_repeal_revoke_data_structure()
    |> sort_on_amending_law_year()
    |> convert_to_string()
    |> string_for_at_field()
    |> (&{:ok, &1}).()
  end

  @doc """
  Function builds Name field (ID/key) and saves the result to :revoked_by
  """
  def at_revoked_by_field(records, result) do
    records
    # |> revoke_repeal_details()
    # |> elem(1)
    |> Enum.reduce([], fn {_, _, _, x}, acc ->
      x = Regex.replace(~r/\s/u, x, " ")

      [_, title] =
        case Regex.run(~r/(.*)[ ]\d*💚️/, x) do
          [_, title] ->
            [nil, title]

          _ ->
            case Regex.run(~r/(.*)[ ]\d{4}[ ]\(repealed\)💚️/, x) do
              [_, title] ->
                [nil, title]

              _ ->
                IO.puts("PROBLEM TITLE #{x}")
                [nil, x]
            end
        end

      [_, type, year, number] = Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d*)/, x)
      [ID.id(title, type, year, number) | acc]
    end)
    |> Enum.uniq()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
    |> (&Map.merge(result, %{revoked_by: &1})).()
    |> (&{:ok, &1}).()
  end

  def new_law(raw_data) do
    raw_data
    |> Enum.reduce([], fn {_, _, _, x}, acc ->
      x = Regex.replace(~r/\s/u, x, " ")

      [_, title] =
        case Regex.run(~r/(.*)[ ]\d*💚️/, x) do
          [_, title] ->
            [nil, title]

          _ ->
            case Regex.run(~r/(.*)[ ]\d{4}[ ]\(repealed\)💚️/, x) do
              [_, title] ->
                [nil, title]

              _ ->
                IO.puts("PROBLEM TITLE #{x}")
                [nil, x]
            end
        end

      title =
        title
        |> Title.title_clean()
        |> (fn x -> ~s/"#{x}"/ end).()

      [_, type, year, number] = Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d*)/, x)

      id = ID.id(title, type, year, number)

      [id, title, type, year, number]
      |> Enum.join(",")
      # |> (fn x -> ~s/"#{x}"/ end).()
      |> (&[&1 | acc]).()
    end)
    |> (&{:ok, &1}).()
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
  def revoke_repeal_details([]), do: {:ok, []}

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

            false ->
              acc
          end

        _ ->
          acc
      end
    end)
    |> (&{:ok, &1}).()
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
          |> (&("💚️\t" <> kk <> "💚️\t\t" <> &1)).()
        end)
        |> (&("💚️" <> k <> &1)).()
      end)
      |> (&[&1 | acc]).()
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
    |> (&Regex.replace(~r/^💚️/, &1, "")).()
    |> Legl.Utility.csv_quote_enclosure()
    |> (&Map.merge(%__MODULE__{}, %{description: &1, code: @code_part})).()
  end
end
