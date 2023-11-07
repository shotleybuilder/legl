defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke do
  @moduledoc """

    Module checks the amendments table of a piece of legislation for a table row
    that describes the law as having been repealed or revoked.

    Saves the results as a .csv file with the fields given by @fields

    Example

    Legl.Countries.Uk.UkRepealRevoke.run(base_name: "UK S", type_code:
    :nia, field_content: [{"Live?_description", ""}], workflow: :create)

  """

  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Services.Airtable.UkAirtable, as: AT
  alias Legl.Countries.Uk.LeglRegister.IdField, as: ID
  alias Legl.Airtable.AirtableTitleField, as: Title
  alias Legl.Services.LegislationGovUk.Url

  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Options
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.RRDescription
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Delta
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Clean
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Patch
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Post
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.NewLaw
  alias Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Csv

  defstruct [
    :Title_EN,
    :amending_title,
    :path,
    :type_code,
    :Year,
    :Number,
    :Live?,
    :Revoked_by,
    :"Live?_description"
  ]

  @doc """
    Run in iex as
     Legl.Countries.Uk.UkRepealRevoke.full_workflow()

  """
  def run(opts \\ []) do
    with {:ok, opts} <- Options.setOptions(opts),
         opts <- if(opts.csv?, do: Csv.openFiles(opts), else: opts),
         :ok <- enumerate_type_codes(opts),
         :ok <- if(opts.csv?, do: Csv.closeFiles(opts), else: :ok) do
      :ok
    else
      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
    end
  end

  def enumerate_type_codes(opts) do
    Enum.each(opts.type_codes, fn type_code ->
      # Formula is different for each type_code
      formula = Options.formula(type_code, opts)
      opts = Map.put(opts, :formula, formula)

      IO.puts("TYPE_CODE: #{type_code}. FORMULA: #{formula}")

      workflow(opts)
    end)
  end

  @api_patch_results_path ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_patch_results.json]
  @api_post_results_path ~s[lib/legl/countries/uk/legl_register/repeal_revoke/api_post_results.json]

  def workflow(opts) do
    opts = Map.put(opts, :fields, opts.fields_source)

    with(
      {:ok, records} <- AT.get_records_from_at(opts),
      records = Jason.encode!(records) |> Jason.decode!(keys: :atoms),
      {:ok, {results, new_laws}} <- enumerate_records(records, opts)
    ) do
      # NEW LAWS for the BASE

      new_laws =
        new_laws
        |> List.flatten()
        |> Enum.uniq()

      IO.puts(~s<\n#{Enum.count(new_laws)} REPEALING / REVOKING LAWS\n>)
      Enum.each(new_laws, fn law -> IO.puts(law[:Title_EN]) end)

      # Filter revoking / repealing laws against those already stored in Base
      new_laws =
        new_laws
        |> NewLaw.new_law?(opts)

      IO.puts(~s<\n#{Enum.count(new_laws)} LAWS MISSING FROM LEGAL REGISTER\n>)
      Enum.each(new_laws, fn %{fields: fields} = _law -> IO.puts("#{fields[:Title_EN]}") end)

      new_laws = Clean.clean_records_for_post(new_laws, opts)

      # view the unclean results to the console?
      if ExPrompt.confirm("\nView New Law Results?"),
        do: IO.inspect(new_laws, label: "NEW CLEANED LAWS: ")

      # save new law records to file as .json
      json =
        new_laws
        |> (&Map.put(%{}, "records", &1)).()
        |> Jason.encode!()

      Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_post_results_path)

      # if option flag :post? == true then POST new laws to Airtable
      if opts.post?, do: Post.post(new_laws, opts)

      # UPDATED LAWS that are REVOKED / REPEALED

      # clean the results so they are suitable for a PATCH call to Airtable
      results = Clean.clean_records(results)

      # view the unclean results to the console?
      if ExPrompt.confirm("\nView Cleaned Patch Results?"),
        do: IO.inspect(results, label: "CLEAN RESULTS: ")

      # store the cleaned results to file for QA
      json =
        results
        |> (&Map.put(%{}, "records", [&1])).()
        |> Jason.encode!()

      Legl.Utility.save_at_records_to_file(~s/#{json}/, @api_patch_results_path)

      # PATCH the results to Airtable if :patch? == true
      if opts.patch?, do: Patch.patch(results, opts)
    end
  end

  @spec workflow(list(), map()) :: list()
  def workflow(records, opts) do
    {:ok, opts} = Options.setOptions(opts)
    {:ok, {records, revoking}} = enumerate_records(records, opts)
    # Save the new laws to json for later processing
    path = ~s[lib/legl/countries/uk/legl_register/repeal_revoke/revoke.json]
    Legl.Utility.save_json(revoking, path)
    records
  end

  @client &Legl.Services.LegislationGovUk.ClientAmdTbl.run!/1
  @parser &Legl.Services.LegislationGovUk.Parsers.Html.amendment_parser/1

  def enumerate_records(records, opts) do
    # IO.inspect(records, limit: :infinity)
    Enum.reduce(records, {[], []}, fn
      #
      # A record returned from Airtable
      %{id: record_id, fields: fields} = record, acc ->
        # BROKEN NEEDS TO GET DIFFERENT FIELDS FROM AT
        %{Name: name, Title_EN: title} = fields
        IO.puts("TITLE_EN: #{title}")

        {result, new_laws} = getRevocations(record, opts)

        if opts.csv?, do: Csv.save_to_csv(name, result, opts)
        if opts.csv?, do: Csv.save_new_law(new_laws, opts)

        # Build the map needed to patch to AT
        result =
          Map.from_struct(result)
          |> (&Map.put(%{id: record_id}, :fields, &1)).()

        # We create when we need a new Live? data and update when the fields have content
        result =
          case opts.workflow do
            :create ->
              result

            :update ->
              Delta.compare(record, result, opts)
          end

        {[result | elem(acc, 0)], [new_laws | elem(acc, 1)]}

      # A record returned from legislation.gov.uk
      %{Title_EN: title} = record, acc ->
        IO.puts("TITLE_EN: #{title}")

        {result, revoking} = getRevocations(record, opts)

        {[Map.merge(result, record) | elem(acc, 0)], [revoking | elem(acc, 1)]}
    end)
    |> (&{:ok, &1}).()
  end

  def getRevocations(record, opts) do
    with(
      url = Url.content_path(record),
      {:ok, html} <- RecordGeneric.leg_gov_uk_html(url, @client, @parser),
      # IO.inspect(html, label: "TABLE DATA", limit: :infinity),
      # Process the html to get a list of data tuples
      data <- proc_amd_tbl(html),
      # Search and filter for the terms 'revoke' or 'repeal' returning {:ok, list} or :no_records
      # List {:ok, [{title, amendment_target, amendment_effect, amending_title&path}, ...{}]
      {:ok, rr_data} <- rrFilter(data),
      # Sets the content of the revocation / repeal "Live?_description" field
      {:ok, result} <- RRDescription.rrDescription(rr_data, %__MODULE__{}, opts),
      # Filters for laws that have been revoked / repealed in full
      {:ok, result} <- rrFullFilter(data, result, opts),
      {:ok, result} <- at_revoked_by_field(rr_data, result),
      {:ok, new_laws} <- new_law(rr_data)
    ) do
      {Map.from_struct(result), new_laws}
    else
      :no_records ->
        result =
          case Map.has_key?(record, :fields) do
            true ->
              Map.merge(record[:fields], %{Live?: opts.code_live, "Live?_checked": opts.date})
              |> (&Map.put(record, :fields, &1)).()

            _ ->
              %{Live?: opts.code_live, "Live?_checked": opts.date}
          end

        {result, []}

      {:live, result} ->
        IO.puts("LIVE: #{title(record)}\n#{inspect(result)}")

        {result, []}

      {nil, msg} ->
        IO.puts("NIL: #{title(record)}\n#{msg}\n")
        {record, []}

      {:error, code, response, _} ->
        IO.puts("#{code} #{response}")
        {record, []}

      {:error, code, response} ->
        IO.puts("#{code} #{response}")
        {record, []}

      {:error, :html} ->
        IO.puts(".html from #{title(record)}")
        {record, []}

      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
        {record, []}

      :error ->
        {record, []}
    end
  end

  defp title(record) do
    if Map.has_key?(record, :fields),
      do: record[:fields][:Title_EN],
      else: record[:Title_EN]
  end

  @doc """
  Function processes each row of the amendment table html
  Returns a tuple:
  {:ok, title, target, effect, amending_title, path}
  where:
    Target = the part of the law that's amended eg 'reg. 2', 'Act'
    Effect = the type of amendment made eg 'words inserted', 'added'
  """
  def proc_amd_tbl([]), do: []

  def proc_amd_tbl([{"tbody", _, rows}]) do
    Enum.map(rows, fn {_, _, x} -> x end)
    |> Enum.map(&proc_amd_tbl_row(&1))
  end

  def proc_amd_tbl_row(row) do
    Enum.with_index(row, fn cell, index -> {index, cell} end)
    |> Enum.reduce([:ok], fn
      {0, {"td", _, [{_, _, [title]}]}}, acc ->
        [title | acc]

      {1, _cell}, acc ->
        acc

      {2, {"td", _, content}}, acc ->
        # IO.inspect(content, label: "CONTENT: ")

        Enum.map(content, fn
          {"a", [{"href", _}, [v1]], [v2]} -> ~s/#{v1} #{v2}/
          {"a", [{"href", _}], [v]} -> v
          {"a", [{"href", _}], []} -> ""
          [v] -> v
          v when is_binary(v) -> v
        end)
        # |> IO.inspect(label: "AT: ")
        |> Enum.join(" ")
        |> String.trim()
        |> (&[&1 | acc]).()

      {3, {"td", _, [amendment_effect]}}, acc ->
        [amendment_effect | acc]

      {3, {"td", [], []}}, acc ->
        ["" | acc]

      {4, {"td", _, [{_, _, [amending_title]}]}}, acc ->
        [amending_title | acc]

      {5, {"td", _, [{_, [{"href", path}], _}]}}, acc ->
        [path | acc]

      {6, _cell}, acc ->
        acc

      {7, _cell}, acc ->
        acc

      {8, _cell}, acc ->
        acc

      {id, row}, acc ->
        IO.puts(
          "Unhandled amendment table row\nID #{id}\nCELL #{inspect(row)}\n[#{__MODULE__}.amendments_table_records]\n"
        )

        acc
    end)
    |> Enum.reverse()
    |> List.to_tuple()

    # |> IO.inspect(label: "DATA TUPLE: ")

    # |> IO.inspect(label: "TABLE ROW TUPLE: ")
  end

  @doc """
    Function searches using a Regex for the terms 'repeal' or 'revoke' in each amendment record

    If no repeal or revoke terms are found then :no_records is returned

    INPUT
      List of tuples from proc_amd_tbl
    OUTPUT
    [
      {"Forestry Act 1967", "s. 39(5)", "repealed",
      "Requirements of Writing (Scotland) Act 1995💚️https://legislation.gov.uk/id/ukpga/1995/7"},
      {"Forestry Act 1967", "Act", "power to repealed or amended (prosp.)",
      "Government of Wales Act 1998💚️https://legislation.gov.uk/id/ukpga/1998/38"},
      ...
    ]
    ALT OUTPUT
    :no_records
  """
  def rrFilter(records) do
    case Enum.reduce(records, [], fn x, acc ->
           case x do
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
         end) do
      [] -> :no_records
      data -> {:ok, data}
    end
  end

  @doc """
  Function filters amendment table rows for entries describing the full revocation / repeal of a law
  """
  def rrFullFilter(data, result, opts) do
    result =
      Enum.reduce_while(data, result, fn x, acc ->
        case x do
          {:ok, title, target, effect, amending_title, path}
          when target in ["Regulations", "Order", "Act"] and effect in ["revoked", "repealed"] ->
            [_, type, year, number] = Regex.run(~r/^\/id\/([a-z]*)\/(\d{4})\/(\d+)/, path)

            Map.merge(
              acc,
              %{
                Title_EN: title,
                amending_title: amending_title,
                path: path,
                type_code: type,
                Year: year,
                Number: number,
                Live?: opts.code_full
              }
            )
            |> (&{:halt, &1}).()

          _ ->
            {:cont, acc}
        end
      end)

    {:ok, result}
  end

  @doc """
  Function builds Name field (ID/key) and saves the result to :revoked_by
  """
  def at_revoked_by_field(records, result) do
    records
    # |> rrFilter()
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
    # |> Legl.Utility.csv_quote_enclosure()
    |> (&Map.merge(result, %{Revoked_by: &1})).()
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

      # |> (fn x -> ~s/"#{x}"/ end).()

      [_, type, year, number] = Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d*)/, x)

      name = ID.id(title, type, year, number)

      Map.new(
        Name: name,
        Title_EN: title,
        type_code: type,
        Year: String.to_integer(year),
        Number: number
      )
      # |> (&Map.put(%{}, :fields, &1)).()

      # [id, title, type, year, number]
      # |> Enum.join(",")
      # |> (fn x -> ~s/"#{x}"/ end).()
      |> (&[&1 | acc]).()
    end)
    |> Enum.uniq()
    |> (&{:ok, &1}).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.RRDescription do
  @moduledoc """
  Module to handle generating the content of the '"Live?_description"' field
  """

  @doc """
    Groups the revocation / repeal clauses by -
      Amending law
        Revocation / repeal phrase
          Provisions revoked or repealed
  """

  def rrDescription(records, struct, opts) do
    records
    # |> rrFilter()
    # |> elem(1)
    |> make_repeal_revoke_data_structure()
    |> sort_on_amending_law_year()
    |> convert_to_string()
    |> string_for_at_field(struct, opts)
    |> (&{:ok, &1}).()
  end

  @doc """
    INPUT
      From rrFilter/1
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
  def string_for_at_field(records, struct, opts) do
    Enum.join(records)
    |> (&Regex.replace(~r/^💚️/, &1, "")).()
    # |> Legl.Utility.csv_quote_enclosure()
    |> (&Map.merge(struct, %{"Live?_description": &1, Live?: opts.code_part})).()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Options do
  @moduledoc """
  Module to handle setting default and user provided options

  """
  alias Legl.Services.Airtable.AtBasesTables
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO

  @code_full "❌ Revoked / Repealed / Abolished"
  @code_part "⭕ Part Revocation / Repeal"
  @code_live "✔ In force"

  @live %{
    green: @code_live,
    amber: @code_part,
    red: @code_full
  }

  # these are the fields for the source data
  # also used for patch after empty fields are dropped
  @at_url_field "leg.gov.uk - changes"
  @fields ~w[
    Name
    Title_EN
    Live?
    Revoked_by
    Live?_description
    Year
  ] ++ [@at_url_field]

  # these are the fields that will be updated in Airtable
  @fields_update ~w[
      Name
      Live?
      Revoked_by
      Live?_description
    ] |> Enum.join(",")

  @default_opts %{
    # field content is list of tuples of {field name, content state}
    name: "",
    field_content: "",
    base_name: "UK E",
    type_code: [""],
    type_class: "",
    sClass: "",
    family: "",
    # Workflow is either :create or :update
    workflow: :create,
    # Content for Live? field
    code_full: @code_full,
    code_part: @code_part,
    code_live: @code_live,
    # today's date
    date: ~s/#{Date.utc_today()}/,
    # a list
    live: "",
    fields_source: @fields,
    fields_update: @fields_update,
    fields_new_law: ~w[Name Title_EN type_code Year Number] |> Enum.join(","),
    view: "VS_CODE_REPEALED_REVOKED",
    # Switches for save
    csv?: false,
    patch?: false,
    post?: false,
    # include/exclude AT records holding today's date
    today?: false
  }

  def setOptions(opts) do
    # IO.puts("DEFAULTS: #{inspect(@default_opts)}")
    opts =
      Enum.into(opts, @default_opts)
      |> LRO.family()

    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})

    opts = live_field_formula(opts)
    opts = field_content(opts)

    with {:ok, type_codes} <- Legl.Countries.Uk.UkTypeCode.type_code(opts.type_code),
         {:ok, type_classes} <- Legl.Countries.Uk.UkTypeClass.type_class(opts.type_class),
         {:ok, sClass} <- Legl.Countries.Uk.SClass.sClass(opts.sClass),
         opts =
           Map.merge(opts, %{
             type_codes: type_codes,
             type_class: type_classes,
             sClass: sClass
           }) do
      if opts.mute? == false, do: IO.puts("OPTIONS: #{inspect(opts)}")
      {:ok, opts}
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

  def formula(type, %{name: ""} = opts) do
    f = if opts.workflow == :create, do: [~s/{Live?}=BLANK()/], else: []
    f = if opts.type_code != [""], do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f
    f = if opts.today? == false, do: [~s/{Live?_checked}!=TODAY()/ | f], else: f
    f = if opts.today? == true, do: [~s/{Live?_checked}=TODAY()/ | f], else: f

    f =
      if opts.family != "",
        do: [~s/{Family}="#{opts.family}"/ | f],
        else: f

    f = if opts.sClass != "", do: [~s/{sClass}="#{opts.sClass}"/ | f], else: f
    f = if opts.live != "", do: [opts.live | f], else: f
    f = if opts.field_content != "", do: [opts.field_content | f], else: f
    ~s/AND(#{Enum.join(f, ",")})/
  end

  def formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Delta do
  @moduledoc """
  Module compares the current and latest "Live?_description" field contents

  Generates a Live?_change_log field to capture the changes
  """
  @field_paddings %{
    :Live? => 15,
    :"Live?_description" => 5,
    :Revoked_by => 10
  }
  # Live?_description is not a good field to compare ...
  @compare_fields ~w[
      Live?
      Revoked_by
      ] |> Enum.map(&String.to_atom(&1))

  def compare(current_record, latest_record, opts) do
    # AT will not return an empty change_log field
    current_record = %{
      current_record
      | fields: Map.put_new(current_record.fields, :"Live?_change_log", "")
    }

    latest_record = %{
      latest_record
      | fields: Map.put_new(latest_record.fields, :"Live?_change_log", "")
    }

    # IO.inspect(current_record, label: "CURRENT RECORD: ")
    # IO.inspect(latest_record, label: "LATEST RECORD: ")

    latest_live_change_log =
      Enum.reduce(@compare_fields, [], fn field, acc ->
        current = Map.get(current_record.fields, field)
        latest = Map.get(latest_record.fields, field)

        cond do
          # find the Delta between the lists
          field == :Revoked_by ->
            current =
              cond do
                is_binary(current) ->
                  String.split(current, ",")
                  |> Enum.map(&String.trim(&1))
                  |> Enum.sort()

                current == nil ->
                  []

                true ->
                  Enum.sort(current)
              end

            latest =
              cond do
                is_binary(latest) ->
                  String.split(latest, ",")
                  |> Enum.map(&String.trim(&1))
                  |> Enum.sort()

                true ->
                  Enum.sort(latest)
              end

            # IO.puts("CURRENT:\n#{inspect(current)}\nLATEST:\n#{inspect(latest)}")
            # IO.puts("DIFF: #{inspect(latest -- current)}")

            case latest -- current do
              [] ->
                acc

              values ->
                # IO.puts(
                #  "NAME: #{current_record.fields."Title_EN"} #{current_record.fields."Year"}\nDIFF: #{inspect(values, limit: :infinity)}"
                # )

                values
                |> Enum.sort()
                |> Enum.join("📌")
                |> (&Keyword.put(acc, field, &1)).()
            end

          true ->
            case changed?(current, latest) do
              false ->
                acc

              value ->
                Keyword.put(acc, field, value)
            end
        end
      end)
      # Create the latest change_log content
      |> live_change_log()

    # |> IO.inspect(label: "LATEST CHANGE LOG: ")

    # |> (&Kernel.<>(current_record.fields[:"Live?_change_log"], &1)).()
    # |> String.trim_leading("📌")

    case compare_live_change_log(
           current_record.fields[:"Live?_change_log"],
           latest_live_change_log
         ) do
      nil ->
        current_record
        |> Map.drop([:createdTime, :fields])
        |> Map.put(:fields, %{"Live?_checked": opts.date})

      _ ->
        # Append the latest change_log content to the current change_log field's contents
        latest_live_change_log =
          ~s/#{current_record.fields[:"Live?_change_log"]}📌#{latest_live_change_log}/

        fields =
          Map.merge(latest_record.fields, %{
            "Live?_change_log": latest_live_change_log,
            "Live?_checked": opts.date
          })

        %{latest_record | fields: fields}
    end
  end

  defp changed?(current, latest) when current in [nil, "", []] and latest not in [nil, "", []] do
    case current != latest do
      false ->
        false

      true ->
        ~s/New value/
    end
  end

  defp changed?(_, latest) when latest in [nil, "", []], do: false

  defp changed?(current, latest) when is_list(current) and is_list(latest) do
    case current != latest do
      false ->
        false

      true ->
        ~s/#{Enum.join(current, ", ")} -> #{Enum.join(latest, ", ")}/
    end
  end

  defp changed?(current, current), do: false

  defp changed?(current, latest), do: "#{current} -> #{latest}"

  defp live_change_log([]), do: ""

  defp live_change_log(changes) do
    # IO.inspect(changes)
    # Returns the metadata changes as a formated multi-line string
    date = Date.utc_today()
    date = ~s(#{date.day}/#{date.month}/#{date.year})

    Enum.reduce(changes, ~s/📌#{date}📌/, fn {k, v}, acc ->
      # width = 80 - string_width(k)
      width = Map.get(@field_paddings, k)
      k = ~s/#{k}#{Enum.map(1..width, fn _ -> "." end) |> Enum.join()}/
      # k = String.pad_trailing(~s/#{k}/, width, ".")
      ~s/#{acc}#{k}#{v}📌/
    end)
    |> String.trim_trailing("📌")
  end

  defp compare_live_change_log(current, current), do: nil

  defp compare_live_change_log(_current, latest), do: latest
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Clean do
  @moduledoc """
  Module to clean the records before POST / PATCH to Airtable
  Calling from the workflow means we can process and store to .json for QA
  """
  def clean_records(record) when is_map(record) do
    clean_records([record]) |> List.first()
  end

  def clean_records(records) when is_list(records) do
    Enum.map(records, fn %{fields: fields} = record ->
      Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
      |> clean()
      |> (&Map.put(record, :fields, &1)).()
    end)
  end

  defp clean(%{Revoked_by: []} = fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :Revoked_by,
      :path,
      :amending_title
    ])
  end

  defp clean(%{Revoked_by: _revoked_by} = fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :path,
      :amending_title
    ])

    # |> Map.put(:Revoked_by, Enum.join(revoked_by, ", "))
  end

  defp clean(fields) do
    Map.drop(fields, [
      :Name,
      :Title_EN,
      :Year,
      :Number,
      :type_code,
      :Revoked_by,
      :path,
      :amending_title
    ])
  end

  def clean_records_for_post(records, opts) do
    Enum.map(records, fn %{fields: fields} = _record ->
      Map.filter(fields, fn {_k, v} -> v not in [nil, "", []] end)
      |> Map.drop([:Name])
      |> (&Map.put(%{}, :fields, &1)).()
    end)
    |> add_family(opts)
  end

  defp add_family(records, opts) do
    # Add Family to records
    # Manually filter those laws to add or not to the BASE

    Enum.reduce(records, [], fn record, acc ->
      case ExPrompt.confirm(
             "Save this law to the Base? #{record.fields[Title_EN]}\n#{inspect(record)}"
           ) do
        false ->
          acc

        true ->
          case opts.family do
            "" ->
              [record | acc]

            _ ->
              case ExPrompt.confirm("Assign this Family? #{opts.family}") do
                false ->
                  [record | acc]

                true ->
                  Map.put(record.fields, :Family, opts.family)
                  |> (&Map.put(record, :fields, &1)).()
                  |> (&[&1 | acc]).()
              end
          end
      end
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Patch do
  def patch([], _), do: :ok

  def patch(record, opts) when is_map(record) do
    IO.write("PATCH single record - ")

    json =
      record
      |> (&Map.put(%{}, "records", [&1])).()
      |> Jason.encode!()

    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    Legl.Services.Airtable.AtPatch.patch_records(json, headers, params)
  end

  def patch(records, opts) when is_list(records) do
    IO.write("PATCH bulk - ")
    process(records, opts)
  end

  defp process(results, %{patch?: true} = opts) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    results =
      Enum.chunk_every(results, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.put(%{}, "records", set)
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(results, fn result_subset ->
      Legl.Services.Airtable.AtPatch.patch_records(result_subset, headers, params)
    end)
  end

  defp process(_, _), do: :ok
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Post do
  def post([], _), do: :ok

  def post(records, opts) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    # Airtable only accepts sets of 10x records in a single PATCH request
    records =
      Enum.chunk_every(records, 10)
      |> Enum.reduce([], fn set, acc ->
        Map.put(%{}, "records", set)
        |> Jason.encode!()
        |> (&[&1 | acc]).()
      end)

    Enum.each(records, fn subset ->
      Legl.Services.Airtable.AtPost.post_records(subset, headers, params)
    end)
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.NewLaw do
  @moduledoc """
  Module to handle addition of new amending laws into the Base
  1. Checks existence of law (for enumeration 1+)
  2. Filters records based on absence
  3. Posts new record with amendment data to Base
  """
  alias Legl.Services.Airtable.Client
  alias Legl.Services.Airtable.Url

  def new_law?(records, opts) do
    # Loop through the records and add a new record parameter :url
    # Record has this shape:
    # %{
    #    Name: "UK_uksi_2003_3073_RVRLAR",
    #    Number: "3073",
    #    Title_EN: "Road Vehicles (Registration and Licensing) (Amendment) (No. 4) Regulations",
    #    Year: "2003",
    #    type_code: "uksi"
    # }
    records =
      Enum.map(records, fn record ->
        options = [
          formula: ~s/{Name}="#{Map.get(record, :Name)}"/,
          fields: ["Name", "Number", "Year", "type_class"]
        ]

        {:ok, url} = Url.url(opts.base_id, opts.table_id, options)
        Map.put(record, :url, url)
      end)

    record_exists_filter(records)
  end

  def record_exists_filter(records) do
    # Loop through the records and GET request the url
    Enum.reduce(records, [], fn record, acc ->
      with {:ok, body} <- Client.request(:get, record.url, []),
           %{records: values} <- Jason.decode!(body, keys: :atoms) do
        # IO.puts("VALUES: #{inspect(values)}")

        case values do
          [] ->
            Map.drop(record, [:url])
            |> (&Map.put(%{}, :fields, &1)).()
            |> (&[&1 | acc]).()

          _ ->
            acc
        end
      else
        {:error, reason: reason} ->
          IO.puts("ERROR #{reason}")
          acc
      end
    end)

    # |> IO.inspect()
  end
end

defmodule Legl.Countries.Uk.LeglRegister.RepealRevoke.RepealRevoke.Csv do
  @at_csv ~s[lib/legl/countries/uk/legl_register/repeal_revoke/repeal_revoke.csv]
          |> Path.absname()
  @rr_new_law ~s[lib/legl/countries/uk/legl_register/repeal_revoke/rr_new_law.csv]
              |> Path.absname()
  def openFiles(opts) do
    with {:ok, file} <- File.open(@at_csv, [:utf8, :write]),
         IO.puts(file, opts.fields_update),
         {:ok, file_new_law} <- File.open(@rr_new_law, [:utf8, :write]),
         IO.puts(file_new_law, opts.fields_new_law) do
      Map.merge(opts, %{file: file, file_new_law: file_new_law})
    end
  end

  def closeFiles(opts) do
    File.close(opts.file)
    File.close(opts.file_new_law)
  end

  def save_to_csv(name, %{"Live?_description": ""}, opts) do
    # no revokes or repeals
    ~s/#{name},#{opts.code_live}/ |> (&IO.puts(opts.file, &1)).()
  end

  def save_to_csv(name, %{"Live?_description": nil}, opts) do
    # no revokes or repeals
    ~s/#{name},#{opts.code_live}/ |> (&IO.puts(opts.file, &1)).()
  end

  def save_to_csv(name, r, opts) do
    # part revoke or repeal
    if "" != r."Live?_description" |> to_string() |> String.trim() do
      ~s/#{name},#{r."Live?"},#{r.revoked_by},#{r."Live?_description"}/
      |> (&IO.puts(opts.file, &1)).()
    end

    :ok
  end

  def save_new_law(new_laws, opts) do
    new_laws
    |> IO.inspect()
    |> Enum.uniq()
    |> Enum.each(fn law ->
      IO.puts(opts.file, law)
    end)
  end
end
