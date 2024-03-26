defmodule Legl.Countries.Uk.LeglInterpretation.Interpretation do
  @moduledoc """
  Functions to parse interpretation / definitions in law

  Enumerates a list of %UK.Act{} or %UK.Regulation{} structs

  File input saved as at_schema.json

  Running

  UK.lit()

  To mute printing of OPTIONS
  UK.lit([LRT: [print_ops?: false]])

  """

  alias Legl.Countries.Uk.LeglRegister.Crud.Read, as: LRRead
  alias Legl.Countries.Uk.LeglArticle.Article
  alias Legl.Countries.Uk.LeglInterpretation.Read, as: LIRead
  alias Legl.Countries.Uk.LeglInterpretation.Options, as: LIO

  @type legal_article_interpretation :: %__MODULE__{
          Term: String.t(),
          Term_Welsh: String.t(),
          Definition: String.t(),
          Defined_By: list(),
          Definition_Referenced: boolean(),
          Scope: String.t()
        }

  defstruct Term: "",
            Term_Welsh: "",
            Definition: "",
            Defined_By: [],
            Definition_Referenced: false,
            Scope: ""

  @default_lit_opts %{
    base_name: "uk ehs",
    table_name: "interpretation",
    lit_query_name: :Term,
    patch?: true
  }

  # scope definitions

  @scope_law Enum.join(
               [
                 ~s/[Ff]or these purposes/,
                 ~s/[Ii]n these [Rr]egulations/,
                 ~s/[Ii]n this [Oo]rder/
               ],
               "|"
             )

  @scope_provision Enum.join(
                     [
                       ~s/[Ff]or the purposes? of this (?:[Rr]egulation|[Oo]rder|[Aa]rticle)/,
                       ~s/[Ff]or the purposes? of paragraph \\(\\d+\\)/,
                       ~s/for this purpose/,
                       ~s/In (?:subsection|paragraph) \\(\\d+\\)/,
                       ~s/[Ii]n (?:this|that) (?:[Rr]egulation|[Oo]rder|[Aa]rticle)|[Ss]ection|[Ss]ubsection/
                     ],
                     "|"
                   )

  @scope_part Enum.join([
                ~s/In this [Pp]art/
              ])

  # Blocks of text containing these terms are excluded from processing

  @excluded Enum.join(
              [
                "substitute" <> <<226, 128, 148>>,
                "substitute" <> <<226, 128, 147>>,
                # "(?<!means?|shall be construed|has the same meaning|is to be read).*substituted?s?",
                "” substitute “",
                "inserte?d?:?" <> <<226, 128, 148>>,
                "inserte?d?:?" <> <<226, 128, 147>>,
                "(?:inserte?d?|inserted (?:the words|at the end|following)) “",
                "References to" <> <<226, 128, 148>>,
                "References to" <> <<226, 128, 147>>,
                "are to be read as if",
                # "For the purposes of these Regulations",
                "The provisions referred to in",
                "When interpreting the Directive for the purposes of these Regulations"
              ],
              "|"
            )

  def excluded(), do: @excluded

  @doc """
  Function is called for stand-alone processing of terms & definitions

  The function reads records from the LRT before processing
  """
  def api_interpretation(%{}) do
    opts = [LRT: [], LAT: [], LIT: []]
    api_interpretation(opts)
  end

  def api_interpretation(LRT: lrt_opts, LAT: lat_opts, LIT: lit_opts) do
    lrt_opts = [{:QA_taxa, "FALSE()"} | lrt_opts]

    lit_opts =
      Enum.into(lit_opts, @default_lit_opts)
      |> LIO.base_table_id()

    # Read records from LRT
    LRRead.api_read(lrt_opts)
    |> process(lat_opts, lit_opts)
  end

  # INTERNAL but TESTED FUNCTIONS

  def process([], _), do: IO.puts("No records returned from the Legal Register")

  def process(lrt_records, lat_opts, lit_opts) do
    # Get and parse the content of each record
    lat_opts =
      lat_opts
      |> Enum.into(%{})
      |> Map.put(:article_workflow_name, :"Original -> Clean -> Parse -> Airtable")
      |> Map.put(:html?, true)
      |> Map.put(:pbs?, false)
      |> Map.put(:country, :uk)

    Enum.each(lrt_records, fn
      %{
        Name: name,
        record_id: record_id,
        Title_EN: title_en,
        type_class: type_class,
        type_code: type_code
      } ->
        IO.puts(~s/\n#{name} #{title_en}/)

        lat_opts =
          lat_opts
          |> Map.put(:Name, name)
          |> Map.put(:type, set_type(type_class))

        lit_opts = lit_opts |> Map.put(:Title_EN, title_en)

        # LAT interpretation records
        {interpretation_section, rest} =
          Article.api_article(lat_opts)
          |> elem(1)
          |> filter_interpretation_sections()

        # IO.inspect(interpretation_section, label: "INTER")
        # IO.inspect(rest, label: "REST")
        interpretation_section =
          interpretation_section
          |> parse_interpretation_section(type_code, :inter)

        rest =
          rest
          |> parse_interpretation_section(type_code, :rest)

        (interpretation_section ++ rest)
        |> Enum.uniq()
        |> build_interpretation_struct(record_id)
        |> tag_for_create_or_update(lit_opts)

        # Enum.concat(results, acc)
    end)
  end

  @doc """
  Function to split the records of the law

  Interpretation section w/o substitutions & other

  Remainder of law w/o substitutions

  Returns as tuple - {interpretation section, other, boolean}
  """

  @spec filter_interpretation_sections(list()) :: {list(), list()}
  def filter_interpretation_sections(records) do
    {inter, rest} =
      Enum.reduce(records, {{[], []}, false}, fn
        %{type: "heading", text: text}, {acc, _} ->
          case Regex.match?(~r/[Ii]nterpretation/, text) do
            true -> {acc, true}
            false -> {acc, false}
          end

        %{type: "section", text: text}, {acc, _} ->
          case Regex.match?(~r/[Ii]nterpretation|Application/, text) do
            true -> {acc, true}
            false -> {acc, false}
          end

        %{type: type, text: text} = record, {{inter, rest} = acc, inter?}
        when type in ["article", "sub-article", "sub-section"] ->
          case excluded_text?(text) do
            true ->
              {acc, inter?}

            _ ->
              record = Map.put(record, :text, Regex.replace(~r/[ ]?📌/m, text, "\n"))

              case inter? do
                true -> {{[record | inter], rest}, inter?}
                false -> {{inter, [record | rest]}, inter?}
              end
          end

        _, acc ->
          acc
      end)
      |> elem(0)

    {Enum.reverse(inter), Enum.reverse(rest)}
  end

  @doc """
  Function to parse definitions when they are contained within an
  'Interpretation' section
  """
  def parse_interpretation_section(lat_records, type_code, print) do
    lat_records
    |> Enum.reduce([], fn %{text: text}, acc ->
      # Remove footnote markers
      text =
        text
        |> (&Regex.replace(~r/\(fn\d*\)/, &1, "")).()
        # Remove EFs
        |> (&Regex.replace(~r/\[F[0-9]*/, &1, "")).()
        |> (&Regex.replace(~r/\]/, &1, "")).()
        |> (&Regex.replace(~r/📌/, &1, "\n")).()
        |> String.trim()

      if print == :inter, do: IO.puts(~s/TEXT: #{text}\n/)

      interpretation_patterns =
        case type_code do
          x when x in ["wsi"] -> interpretation_patterns(true)
          _ -> interpretation_patterns(false)
        end

      interpretation_patterns
      |> Enum.reduce({acc, text}, fn regex, {acc2, txt} ->
        case Regex.scan(regex, txt) do
          [] ->
            {acc2, txt}

          result ->
            termdefs = process_regex_scan_result(result, type_code, txt, print)
            txt = process_text(result, txt)

            if print == :inter, do: IO.puts(~s/\nREMAIN TEXT: #{inspect(txt)}/)

            {Enum.concat(acc2, termdefs), txt}
        end
      end)
      |> elem(0)
    end)
  end

  @spec build_interpretation_struct(
          list({term :: binary(), defn :: binary(), scope :: binary()}),
          String.t()
        ) ::
          list(%__MODULE__{})
  def build_interpretation_struct(records, record_id) do
    Enum.map(records, fn
      {term, w_term, defn, scope} ->
        term = clean_term(term)
        defn = clean_defn(defn)
        refd? = definition_references_another_law?(defn)

        %__MODULE__{
          Term: String.trim(term),
          Definition: defn,
          Defined_By: [record_id],
          Term_Welsh: String.downcase(w_term),
          Definition_Referenced: refd?,
          Scope: scope
        }

      {term, defn, scope} ->
        term = clean_term(term)
        defn = clean_defn(defn)
        refd? = definition_references_another_law?(defn)

        %__MODULE__{
          Term: String.trim(term),
          Definition: defn,
          Defined_By: [record_id],
          Definition_Referenced: refd?,
          Scope: scope
        }
    end)
    |> print_results()
  end

  @doc """
  Function to compare results with records in the LIT

  Term is missing -> Create new record
  Term is present w/ law listed and matching defn -> No action - Record unchanged
  Term is present w/ law listed but w/o matching defn
    If the law is the only definer -> Update definition
    If the law is one of many definers -> Delete linked law in original record & Create new record
  Term is present w/ matching defn but law not listed as a definer -> Update linked record field
  Term is present w/o matching defn -> Create new record

  Term Present? -n-> CREATE RECORD
  -y->

  Term defined by this law?
  -y-> Definition changed?
  -n-> NO ACTION
  -y-> Multiple defining laws?
  -y-> CREATE RECORD
  -n-> UPDATE 'Definition' field

  Term defined by this law?
  -n-> Definition present?
  -y-> UPDATE 'Defined_By' field
  -n-> CREATE RECORD
  """

  def tag_for_create_or_update(lat_records, lit_records \\ nil, lit_opts)
      when is_map(lit_opts) do
    Enum.reduce(lat_records, [], fn
      %__MODULE__{Term: term, Defined_By: [record_id]} = record, acc ->
        # We only GET LIT records using the Term as search value
        lit_opts = Map.put(lit_opts, :term, term)

        # Allows the function to be tested w/o calling the Base
        lit_records =
          case lit_records do
            nil -> LIRead.api_lit_read(lit_opts)
            _ -> lit_records
          end

        case lit_records do
          # Term not present
          [] ->
            result =
              record
              |> Map.from_struct()
              |> Map.put(:action, :post)

            # POST
            build(result, lit_opts)

            [result | acc]

          # Term present
          _ ->
            case term_defined_by_this_law?(lit_records, record) do
              false ->
                case definition_present?(lit_records, record) do
                  false ->
                    result =
                      record
                      |> Map.from_struct()
                      |> Map.put(:action, :post)

                    # POST
                    build(result, lit_opts)

                    [result | acc]

                  [result] ->
                    defined_by =
                      case Map.has_key?(result, :Defined_By) do
                        true -> [record_id | result."Defined_By"] |> Enum.sort()
                        # Handles orphan terms with no Defined_By field content
                        false -> [record_id]
                      end

                    result =
                      Map.merge(result, %{Defined_By: defined_by, action: :patch})
                      |> Map.drop([:Name, :Definition, :Term])

                    # PATCH
                    build(result, lit_opts)

                    [result | acc]

                  result ->
                    IO.puts(
                      ~s/ERROR: #{inspect(result)}\n #{__MODULE__}.tag_for_create_or_update definition_present/
                    )
                end

              [at_record] ->
                case definition_changed?(at_record, record) do
                  false ->
                    acc

                  true ->
                    case multiple_defining_laws?(at_record) do
                      true ->
                        result = record |> Map.from_struct() |> Map.put(:action, :post)

                        # POST
                        build(result, lit_opts)

                        defined_by = at_record."Defined_By" -- record."Defined_By"

                        at_result =
                          at_record
                          |> Map.put(:Defined_By, defined_by)
                          |> Map.drop([:Name, :Definition, :Term])
                          |> Map.put(:action, :patch)

                        # PATCH
                        build(at_result, lit_opts)

                        [at_result | acc]
                        |> (&[result | &1]).()

                      false ->
                        at_record =
                          at_record
                          |> Map.drop([:Defined_By])
                          |> Map.put(:Definition, record."Definition")
                          |> Map.put(:action, :patch)

                        # PATCH

                        build(at_record, lit_opts)
                        [at_record | acc]
                    end
                end

              at_record ->
                IO.puts(
                  ~s/ERROR: #{inspect(at_record)}\n #{__MODULE__}.tag_for_create_or_update definition_changed?/
                )
            end
        end
    end)
  end

  def build(%{action: :post} = record, opts) when is_map(record) do
    Map.drop(record, [:action, :Name])
    |> Legl.Utility.map_filter_out_empty_members()
    |> (&Map.merge(%{}, %{fields: &1})).()
    |> List.wrap()
    |> post(opts)
  end

  def build(%{record_id: record_id, action: :patch} = record, opts) when is_map(record) do
    %{id: record_id, fields: Map.drop(record, [:record_id, :Name, :action])}
    |> patch(opts)
  end

  def post(record, opts) do
    headers = [{:"Content-Type", "application/json"}]
    params = %{base: opts.base_id, table: opts.table_id, options: %{}}
    json = Map.merge(%{}, %{"records" => record, "typecast" => true}) |> Jason.encode!()
    # IO.inspect(json, label: "__MODULE__", limit: :infinity)
    Legl.Services.Airtable.AtPost.post_records([json], headers, params)
  end

  defp patch(record, %{patch?: true} = opts) when is_map(record) do
    headers = [{:"Content-Type", "application/json"}]

    params = %{
      base: opts.base_id,
      table: opts.table_id,
      options: %{}
    }

    record = Map.merge(%{}, %{"records" => List.wrap(record), "typecast" => true})

    with({:ok, json} <- Jason.encode(record)) do
      Legl.Services.Airtable.AtPatch.patch_records(json, headers, params)
    else
      {:error, %Jason.EncodeError{message: error}} ->
        IO.puts(~s/#{error}/)
        :ok
    end
  end

  defp patch(_, %{patch?: false}), do: :ok

  defp patch(record, %{patch?: patch} = opts) when patch in [nil, ""] do
    patch? = ExPrompt.confirm("\nPatch #{opts."Title_EN"}?")
    patch(record, Map.put(opts, :patch?, patch?))
  end

  defp patch([], _), do: :ok

  defp patch(record, opts), do: patch(record, Map.put(opts, :patch?, ""))

  defp term_defined_by_this_law?(results, %{Defined_By: [record_id]} = _record) do
    matches =
      Enum.filter(results, fn
        %{Defined_By: record_ids} ->
          Enum.member?(record_ids, record_id)

        result ->
          Map.has_key?(result, :Defined_By)
      end)

    case Enum.count(matches) do
      0 ->
        false

      1 ->
        matches

      _ ->
        IO.puts(~s/ERROR: Law #{record_id} linked to multiple defns of the same term/)
        Enum.each(matches, fn match -> IO.inspect(match) end)
        matches
    end
  end

  defp definition_present?(results, %{Definition: definition} = _record) do
    Enum.filter(results, fn
      %{Definition: at_definition} ->
        case String.bag_distance(at_definition, definition) do
          x when x > 0.9 -> true
          _ -> false
        end

      # AT doesn't return a value if the 'Definition' field is empty
      _ ->
        case String.bag_distance("", definition) do
          x when x > 0.9 -> true
          _ -> false
        end
    end)
    |> case do
      [] -> false
      result -> result
    end
  end

  defp definition_changed?(
         %{Definition: at_definition} = _result,
         %{Definition: definition} = _record
       ) do
    case String.bag_distance(at_definition, definition) do
      x when x > 0.9 -> false
      _ -> true
    end
  end

  defp multiple_defining_laws?(%{Defined_By: record_ids}) when is_list(record_ids) do
    case Enum.count(record_ids) do
      1 -> false
      _ -> true
    end
  end

  @spec process_regex_scan_result(list(), String.t(), String.t(), atom()) :: list()
  def process_regex_scan_result(result, type_code, txt, print) when type_code in ["wsi"] do
    # IO.inspect(result)
    scope = definition_scope(txt)

    results =
      Enum.map(result, fn
        [_, _, _, _, _, _, _, ""] ->
          []

        [_, _, _, _, _, ""] ->
          []

        [_, _, _, ""] ->
          []

        [_, term1, welsh1, term2, welsh2, term3, welsh3, defn] ->
          defn = String.trim(defn)

          [
            {term1, welsh1, defn, scope},
            {term2, welsh2, defn, scope},
            {term3, welsh3, defn, scope}
          ]

        [_, term1, welsh1, term2, welsh2, defn] ->
          defn = String.trim(defn)
          [{term1, welsh1, defn, scope}, {term2, welsh2, defn, scope}]

        [_, term1, welsh1, defn] ->
          [{term1, welsh1, String.trim(defn), scope}]
      end)
      |> List.flatten()

    print_regex_result(results, txt, print)
    results
  end

  @spec process_regex_scan_result(list(), String.t(), String.t(), atom()) :: list()
  def process_regex_scan_result(result, _type_code, txt, print) do
    # IO.inspect(result)
    scope = definition_scope(txt)

    results =
      Enum.map(result, fn
        [_, _, _, ""] ->
          []

        [_, _, ""] ->
          []

        [_, term1, term2, term3, defn] ->
          defn = String.trim(defn)
          [{term1, defn, scope}, {term2, defn, scope}, {term3, defn, scope}]

        [_, term1, term2, defn] ->
          defn = String.trim(defn)
          [{term1, defn, scope}, {term2, defn, scope}]

        # deals with a specific error in leg.gov.uk -> "the 1974" Act means
        [_, "the 1974", " Act" <> defn] ->
          [{"the 1974 Act", String.trim(defn), scope}]

        [_, term, defn] ->
          [{term, String.trim(defn), scope}]
      end)
      |> List.flatten()

    print_regex_result(results, txt, print)
    results
  end

  def print_regex_result(results, txt, :rest),
    do:
      Enum.each(results, fn
        {term, welsh, defn, scope} ->
          IO.puts(
            ~s/\nTEXT: #{txt}\nMATCH:🔹term: #{term} welsh: #{welsh}🔹defn: #{inspect(defn)}🔹scope: #{scope}/
          )

        {term, defn, scope} ->
          IO.puts(
            ~s/\nTEXT: #{txt}\nMATCH:🔹term: #{term} 🔹defn: #{inspect(defn)}🔹scope: #{scope}/
          )
      end)

  def print_regex_result(results, _, _),
    do:
      Enum.each(results, fn
        {term, welsh, defn, scope} ->
          IO.puts(~s/MATCH:🔹term: #{term}🔹welsh: #{welsh}🔹defn: #{inspect(defn)}🔹scope: #{scope}/)

        {term, defn, scope} ->
          IO.puts(~s/MATCH:🔹term: #{term}🔹defn: #{inspect(defn)}🔹scope: #{scope}/)
      end)

  def definition_scope(text) do
    law = @scope_law

    provision = @scope_provision

    part = @scope_part

    cond do
      Regex.match?(~r/#{law}/, text) -> "law"
      Regex.match?(~r/#{provision}/, text) -> "provision"
      Regex.match?(~r/#{part}/, text) -> "part"
      true -> ""
    end
  end

  def process_text(results, text) do
    Enum.reduce(results, text, fn
      [match | _], txt ->
        Regex.replace(~r/#{Regex.escape(match)}/, txt, "")
    end)
  end

  def excluded_text?(text) do
    # Discard amendment text blocks which contains these terms
    Regex.match?(~r/#{@excluded}/, text)
  end

  @spec interpretation_patterns(boolean()) :: list()
  def interpretation_patterns(welsh?) do
    single = ~s/“([[:print:]]*)”/
    welsh = ~s/\\(“([[:print:]’]*)”\\)/

    single_welsh = ~s/#{single}[ ]#{welsh}/

    double = ~s/#{single}[ ]and[ ]#{single}/
    double_welsh = ~s/#{single_welsh}[ ]and[ ]#{single_welsh}/

    triple = ~s/#{single},[ ]#{double}/
    triple_welsh = ~s/#{single_welsh},[ ]#{double_welsh}/

    fwd_lh =
      [
        # end of text (we're not using 'm')
        "\\.$",
        # start of next line
        "[,;][ ]?\n(?:[ ]?“|the[ ]“|\\([a-z]\\)[ ](?:the[ ]|any reference to a[ ])?“)",
        # 'and' joiner
        "[,;][ ]and[ ]?\n[ ]?“",
        # a period where a semi-colon should be
        "\\.[ ]\n“",
        # no end of line punct, just a space
        "[ ]\n“",
        # no punc just a new line
        "[ ]\n[ ]“",
        # repeal before next term
        ". . .\n“"
      ]
      |> Enum.join("|")

    fwd_lh = ~s/([\\s\\S]*?)(?=(?:#{fwd_lh}))/

    case welsh? do
      true ->
        [
          ~s/#{triple_welsh}[ ]#{fwd_lh}/,
          ~s/#{double_welsh}[ ]#{fwd_lh}/,
          ~s/#{single_welsh}[, ]#{fwd_lh}/
        ]

      _ ->
        [
          ~s/#{triple}[ ]#{fwd_lh}/,
          ~s/#{double}[ ]#{fwd_lh}/,
          ~s/#{single}[, ]#{fwd_lh}/

          # ~s/“([[:print:]]*)”[ ]and[ ]“([[:print:]]*)”[ ]([\\s\\S]*?)#{fwd_lh}/,
          # ~s/“([[:print:]]*)”[ ]([\\s\\S]*?)#{fwd_lh}/
        ]
    end
    |> Enum.map(&(Regex.compile(&1, "m") |> elem(1)))
  end

  # PRIVATE FUNCTIONS

  defp clean_term(term) do
    term
    # Remove any leading 'the' from the term
    |> (&Regex.replace(~r/^the[ ]/, &1, "")).()
    # Remove any leading 'a' from the term
    |> (&Regex.replace(~r/^a[ ]/, &1, "")).()
    |> String.downcase()
  end

  # punct -> [ or , or ; . ( empty parentheses -> () ( ) repeating period [ ].
  @defn_regex ~r/(?:[,;\.\(]|\([ ]?\)|(?:[ ]\.)*|\.*|[ ]M\d+|[ ]F\d+)$/

  defp clean_defn(defn) do
    defn = String.trim(defn)

    case Regex.match?(~r/@defn_regex/, defn) do
      true ->
        defn
        |> (&Regex.replace(@defn_regex, &1, "")).()
        |> String.trim()
        |> clean_defn()

      _ ->
        defn
    end
  end

  defp definition_references_another_law?(defn) do
    cond do
      Regex.match?(
        ~r/has?v?e? the meanings? (?:in|they bear|that it bears|assigned|given|respectively assigned).*(?:in the|to the|of the|of).*(?:Act|Regulation|Order)/,
        defn
      ) ->
        true

      Regex.match?(
        ~r/has?v?e? the same meanings? (?:as in|as in the|given|assigned).*(?:Act|Regulation|Order)/,
        defn
      ) ->
        true

      Regex.match?(
        ~r/has?v?e? the respective meanings? (?:as in|as in the|given|assigned).*(?:Act|Regulation|Order)/,
        defn
      ) ->
        true

      Regex.match?(
        ~r/(?:is to be|shall) be construed (?:as provided|in accordance).*(?:of the|of).*(?:Act|Regulation|Order)/,
        defn
      ) ->
        true

      Regex.match?(~r/as defined by.*(?:Act|Regulation|Order)/, defn) ->
        true

      true ->
        false
    end
  end

  defp print_results(results) do
    IO.puts(~s/\nRESULTS:\n/)

    Enum.each(results, fn
      %__MODULE__{
        Term: term,
        Term_Welsh: w_term,
        Definition: defn,
        Definition_Referenced: ref,
        Scope: scope
      } ->
        IO.puts(
          ~s/TERM: #{term}\nWELSH TERM: #{w_term}\nDEFN: #{defn}\nREF: #{ref}\nSCOPE: #{scope}\n/
        )

      %__MODULE__{Term: term, Definition: defn, Definition_Referenced: ref, Scope: scope} ->
        IO.puts(~s/TERM: #{term}\nDEFN: #{defn}\nREF: #{ref}\n SCOPE: #{scope}\n/)
    end)

    results
  end

  defp set_type("Act"), do: :act
  defp set_type(_), do: :regulation
end
