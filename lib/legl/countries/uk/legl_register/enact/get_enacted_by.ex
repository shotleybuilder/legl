defmodule Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy do
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Services.LegislationGovUk.Url, as: Url
  alias Legl.Services.LegislationGovUk.RecordGeneric

  @doc """
    Function processes a list of records from Airtable. Items of metadata (intor
    and enacting text, and urls) are obtained from leg.gov.uk The text is
    processed for the enacting law(s). The enacting laws are stored in the
    enacting_laws: element of the 'fields' map.

    Enacting laws for any particular child are deduped, but there might be dupes
    between children.

    There are 3x processes for finding enacitng laws.

    1. The first is a set of very specific phrases that apply very infrequently.
    2. The second are more general phrases that will include the enacting law
       within the match
    3. The third is a general sweep of the enacting text metadata field

    2. and 3. use the ef-code that indexes laws to the url listed in the
       footnotes.

    These processes search for the ef-codes and read the url from the map of
    urls returned from leg,gov.uk
  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister

  def get_enacting_laws(%LegalRegister{type_code: type_code} = record, _opts)
      when is_struct(record) and type_code in ["ukpga", "anaw", "asp", "nia", "apni"] do
    IO.puts(" x_ENACTED_BY")
    {:ok, record}
  end

  def get_enacting_laws(
        %LegalRegister{type_code: type_code, Number: number, Year: year} = record,
        opts
      )
      when is_struct(record) do
    IO.puts(" ENACTED_BY")

    {:ok, result} =
      %{type_code: type_code, Number: number, Year: year}
      |> get_enacting_laws(opts)

    {:ok, Kernel.struct(record, result)}
  end

  @spec get_enacting_laws(list(), map()) :: {:ok, list(), list()}
  def get_enacting_laws(records, opts) when is_list(records) do
    records =
      Enum.reduce(records, [], fn
        # Acts are not Enacted
        %{type_class: "Act"} = record, acc ->
          [record | acc]

        %{type_code: type_code} = record, acc
        when type_code in ["ukpga", "anaw", "asp", "nia", "apni"] ->
          [record | acc]

        record, acc ->
          with({:ok, record} <- get_enacting_laws(record, opts)) do
            [record | acc]
          else
            {:error, msg, _record} ->
              IO.puts("#{msg}")
              [record | acc]

            {:no_text, msg, _record} ->
              IO.puts("#{msg}")
              [record | acc]
          end
      end)

    enacting_laws = enacting_laws_list(records)

    {:ok, records, enacting_laws}
  end

  def get_enacting_laws(%{fields: %{Title_EN: title} = fields} = record, opts)
      when is_map(record) do
    IO.puts("#{title}")

    with(
      fields = Map.merge(fields, %{enacting_laws: [], urls: nil, text: ""}),
      {:ok, fields} <- get_leg_gov_uk(fields),
      {:ok, fields} <- text(fields),
      {:ok, fields} <- specific_enacting_clauses(fields, opts),
      {:ok, fields} <- enacting_law_in_match(fields),
      {:ok, fields} <- enacting_law_in_enacting_text(fields),
      {:ok, fields} <- dedupe(fields),
      {:ok, fields} <- enacted_by(fields)
    ) do
      # |> IO.inspect()
      record = Map.put(record, :fields, fields)
      {:ok, record}
    else
      {:error, error} ->
        {:error,
         "\nERROR: #{error} #{record[:Title_EN]}\nFUNCTION: #{__MODULE__}.get_enacting_laws/1\n",
         record}

      {:no_text, record} ->
        {:no_text, "No enacting text for this law\n", record}
    end
  end

  @spec get_enacting_laws(map(), map()) :: {:ok, map()}
  def get_enacting_laws(record, opts) do
    with(
      record = Map.merge(record, %{enacting_laws: [], urls: nil, text: ""}),
      {:ok, record} <- get_leg_gov_uk(record),
      {:ok, record} <- text(record),
      {:ok, record} <- specific_enacting_clauses(record, opts),
      {:ok, record} <- enacting_law_in_match(record),
      {:ok, record} <- enacting_law_in_enacting_text(record),
      {:ok, record} <- dedupe(record),
      {:ok, record} <- enacted_by(record),
      {:ok, record} <- enacted_by_description(record)
    ) do
      {:ok, record}
    else
      {:error, error} ->
        IO.puts("\nERROR: #{error}\n #{__MODULE__}.get_enacting_laws/1\n")
        {:ok, Map.put(record, :enact_error, "ERROR: #{error}")}

      {:error, code, error} ->
        IO.puts("\nERROR: #{code}, #{error}\n #{__MODULE__}.get_enacting_laws/1\n")
        {:ok, Map.put(record, :enact_error, "ERROR: #{code}, #{error}")}

      {:no_text, _} ->
        IO.puts("\nNO TEXT: No enacting text for this law\n #{__MODULE__}.get_enacting_laws/1\n")

        {:ok, Map.put(record, :enact_error, "NO TEXT. No enacting text for this law")}
    end
  end

  @doc """
    Response has this shape
    %{
      enacting_text: "",
      introductory_text: "",
      urls: %{"fxxxx" => 'url'}
    }
    If the response is successful the results are merged into the fields property of the record
  """
  def get_leg_gov_uk(record) do
    path = Url.introduction_path(record)

    case RecordGeneric.enacting_text(path) do
      {:ok, :xml, %{urls: urls} = response} ->
        %{introductory_text: i, enacting_text: e, urls: u} =
          Map.put(response, :urls, urls_to_string(urls))

        record = Map.merge(record, %{introductory_text: i, enacting_text: e, urls: u})

        {:ok, record}

      {:ok, :html} ->
        {:error, "html"}

      {:error, code, error} ->
        {:error, code, error}
    end
  end

  defp urls_to_string(urls) do
    Enum.reduce(urls, %{}, fn {k, v}, acc ->
      Enum.map(v, fn url -> "#{url}" end)
      |> (&Map.put(acc, k, &1)).()
    end)
  end

  defp text(%{introductory_text: iText, enacting_text: eText} = record) do
    text =
      (Regex.replace(~r/\n/m, iText, " ") <>
         " " <> Regex.replace(~r/\n/m, eText, " "))
      |> String.trim()

    case text do
      "" ->
        {:no_text, record}

      _ ->
        record = %{record | text: text}
        {:ok, record}
    end
  end

  @doc """
    Parses xml containing clauses with the following patterns:

    The Secretary of State, in exercise of the powers conferred by sections 38 and 51(1)
    of the Fisheries Act 2020 <FootnoteRef Ref="f00001"/>, makes the following Regulations.

    The Secretary of State makes the following Order in exercise of the powers conferred by
    regulation 143(1) of the Conservation of Habitats and Species Regulations 2017 <FootnoteRef Ref="f00001"/>
    (“<Term id="term-the-2017-regulations">the 2017 Regulations</Term>”) and section 22(5)(a) of the
    Wildlife and Countryside Act 1981 <FootnoteRef Ref="f00002"/> (“<Term id="term-the-act">the Act</Term>”).

    The key elements being the phrase "conferred by" and the footnote references.
  """

  def specific_enacting_clauses(record, %{base_name: "UK S"} = _opts),
    do: specific_enacting_clauses(record, s_regexes())

  def specific_enacting_clauses(record, %{base_name: "UK E"} = _opts),
    do: specific_enacting_clauses(record, e_regexes())

  def specific_enacting_clauses(record, []), do: {:ok, record}

  def specific_enacting_clauses(
        %{enacting_laws: eLaws, text: text} = record,
        regexes
      ) do
    eLaws =
      Enum.reduce(regexes, eLaws, fn {act, regex}, acc ->
        case Regex.run(regex, text) do
          nil -> acc
          _ -> [make_law_map(act) | acc]
        end
      end)

    {:ok, %{record | enacting_laws: eLaws}}
  end

  @doc """
  Function to build the regex for specific ENV register enacting law clauses
  Shape of return
  {{title, type_code, year, number}, regex}
  """
  def e_regexes() do
    acts = [
      {"Transport and Works Act", "ukpga", "1992", "42"},
      {"European Union \(Withdrawal\) Act", "ukpga", "2018", "16"},
      {"Planning Act", "ukpga", "2008", "29"}
    ]

    regexes =
      Enum.reduce(acts, [], fn {tl, _t, yr, _n} = act, acc ->
        {act, ~r/an Order under sections?.*? of the #{tl} #{yr}/}
        |> (&[&1 | acc]).()
      end)

    regexes =
      Enum.reduce(acts, regexes, fn {tl, _t, yr, _n} = act, acc ->
        {
          act,
          ~r/in exercise of the powers.*?(?: in)? sections?.*? of(?: the)? #{tl} #{yr}/
        }
        |> (&[&1 | acc]).()
      end)

    regexes ++
      [
        {{"Planning Act", "ukpga", "2008", "29"},
         ~r/An application has been made to the Secretary of State under section 37 of the Planning Act 2008/},
        {{"Planning Act", "ukpga", "2008", "29"},
         ~r/[T|t]he Secretary of State, in exercise of the powers.*? section[s]? 114.*? and 120.*? of the 2008 Act/},
        {{"Planning Act", "ukpga", "2008", "29"},
         ~r/The Secretary of State has decided to grant development consent.*? of the 2008 Act/}
      ]
  end

  def s_regexes() do
    acts = [
      {"Northern Ireland Act", "ukpga", "2000", "1"},
      {"Northern Ireland Act", "ukpga", "1974", "28"}
    ]

    Enum.reduce(acts, [], fn {tl, _t, yr, _n} = act, acc ->
      [
        {act, ~r/powers conferred by paragraph.*?Schedule.*?to the[ ]+#{tl} #{yr}/}
      ]
      |> (&Kernel.++(acc, &1)).()
    end)
  end

  defp enacting_law_in_match(%{urls: urls, text: text, enacting_laws: eLaws} = record) do
    regexes = [
      ~r/powers? conferred.*?by.*?and now vested in/,
      ~r/powers? conferred.*?by.*?having been designated/,
      ~r/powers? conferred.*?by.*?the Health and Safety at Work etc\. Act 1974 (?:\(“the 1974 Act”\) )?(?:f\d{5})?/,
      ~r/powers? conferred.*?by.*?the Health and Safety at Work etc\. Act 1974 (?:f\d{5} )?(?:\(“the 1974 Act”\))?/,
      ~r/powers? conferred.*?by.*?[\.:;]/,
      ~r/powers under.*?f\d{5}/
    ]

    {e_Laws, _} =
      Enum.reduce(regexes, {[], text}, fn regex, {acc, txt} ->
        case Regex.run(regex, txt) do
          nil ->
            {acc, txt}

          [match | _] ->
            # let's ensure later regex don't match again
            txt = Regex.replace(regex, txt, "")
            acc = acc ++ get_url_refs(urls, match)

            {acc, txt}
        end
      end)

    {:ok, %{record | enacting_laws: Kernel.++(eLaws, e_Laws)}}
  end

  @doc """
  Function scans the enacting text for ef-codes (fxxxxx) and looks up the url of
  that ef-code in the map of ef-codes.

  The function only runs if no enacting laws have been Id'd by mroe specific means
  """

  def enacting_law_in_enacting_text(
        %{enacting_text: text, urls: urls, enacting_laws: []} = record
      ) do
    get_url_refs(urls, text)
    |> (&{:ok, %{record | enacting_laws: &1}}).()
  end

  def enacting_law_in_enacting_text(record), do: {:ok, record}

  defp get_url_refs(urls, text) do
    # IO.inspect(enacting_laws, label: "enacting_laws")
    with {:ok, url_set} <- get_urls(urls, text),
         # IO.inspect(url_set, label: "url_set"),
         {:ok, url_matches} <- match_on_year(url_set, text),
         # IO.inspect(url_matches, label: "url_matches"),
         {:ok, enacting_laws} <- enacting_laws(url_matches) do
      enacting_laws
    else
      {:none, []} ->
        []
    end
  end

  defp get_urls(urls, text) do
    case Regex.scan(~r/f\d{5}/m, text) do
      [] ->
        # there are no ef-codes in the text
        {:none, []}

      fCodes ->
        # ef-code is the key to the enacting law's url
        # enumerate the ef-codes found in the text
        Enum.map(fCodes, fn [fCode] ->
          Map.get(urls, fCode)
        end)
        |> Enum.concat()
        |> (&{:ok, &1}).()
    end
  end

  defp match_on_year(url_set, text) do
    # if there is more than 1 url we need to find the one best matching the text
    # we'll try to get a match with Year

    case Regex.scan(~r/[ ]\d{4}[ ]/, text) do
      [] ->
        {:none, []}

      years ->
        Enum.reduce(years, [], fn [year], acc ->
          year = String.trim(year)

          Enum.reduce(url_set, [], fn url, acc ->
            case String.contains?(url, year) do
              true -> [url | acc]
              false -> acc
            end
          end)
          |> (&Kernel.++(acc, &1)).()
        end)
        |> Enum.uniq()
        |> (&{:ok, &1}).()
    end
  end

  defp enacting_laws(urls) do
    Enum.reduce(urls, [], fn url, acc ->
      case url do
        "" ->
          acc

        _ ->
          cond do
            String.contains?(url, "european") ->
              [_, year, number] =
                Regex.run(
                  ~r/http:\/\/www.legislation.gov.uk\/european\/directive\/(\d{4})\/(\d+)$/,
                  url
                )

              [{"eu law", "eudr", year, number} | acc]

            true ->
              [_, type, year, number] =
                Regex.run(
                  ~r/http:\/\/www.legislation.gov.uk\/id\/([a-z]*?)\/(\d{4})\/(\d+)$/,
                  url
                )

              case Url.introduction_path(type, year, number) |> get_title() do
                {:ok, title} -> [make_law_map({title, type, year, number}) | acc]
                {:error, _error} -> acc
              end
          end
      end
    end)
    |> Enum.uniq()
    |> (&{:ok, &1}).()
  end

  defp get_title(path) do
    case RecordGeneric.metadata(path) do
      {:ok, :xml, %{Title_EN: title}} ->
        {:ok, title}

      {:ok, :html} ->
        {:error, "not found"}

      {:error, _code, error} ->
        {:error, error}
    end
  end

  defp make_law_map({title, type, year, number}) do
    id =
      Legl.Airtable.AirtableTitleField.title_clean(title)
      |> Legl.Countries.Uk.LeglRegister.IdField.id(type, year, number)

    %{
      Name: id,
      Title_EN: title,
      type_code: type,
      Year: year,
      Number: number
    }
  end

  def dedupe(%{enacting_laws: eLaws} = record) do
    {:ok, %{record | enacting_laws: Enum.uniq_by(eLaws, &{&1[Name]})}}
  end

  @doc """
  Airtable 'Enacted_by' field is a long text that needs a comma separated string
  """
  def enacted_by(%{enacting_laws: eLaws} = record) do
    enacted_by =
      Enum.map(eLaws, fn %{Name: name} = _eLaw -> name end)
      |> Enum.join(",")

    {:ok, Map.put(record, :Enacted_by, enacted_by)}
  end

  @spec enacting_laws_list(list()) :: list()
  def enacting_laws_list(results) do
    Enum.reduce(results, [], fn
      %{enacting_laws: enacting_laws} = _result, acc ->
        [enacting_laws | acc]

      _result, acc ->
        acc
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  def enacted_by_description(%{enacting_laws: e_laws} = record) do
    enacted_by_description =
      Enum.map(
        e_laws,
        fn %{Name: name, Title_EN: title} = e_law ->
          ~s/#{name}📌#{title}📌#{Legl.Utility.legislation_gov_uk_id_url(e_law)}📌📌/
        end
      )
      |> Enum.join()
      |> String.trim_trailing("📌📌")

    {:ok, Map.put(record, :enacted_by_description, enacted_by_description)}
  end
end
