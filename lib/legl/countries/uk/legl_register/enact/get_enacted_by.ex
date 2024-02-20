defmodule Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy do
  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR
  alias Legl.Services.LegislationGovUk.Url, as: Url
  alias Legl.Services.LegislationGovUk.RecordGeneric

  defmodule Enact do
    @type enact :: %__MODULE__{
            enacting_text: String.t(),
            introductory_text: String.t(),
            text: String.t(),
            urls: list(),
            enacting_laws: list()
          }
    @struct ~w[
      enacting_text
      introductory_text
      text
      urls
      enacting_laws
    ]a
    defstruct @struct
  end

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
  def get_enacting_laws(%LR{type_code: type_code} = record, _opts)
      when is_struct(record) and type_code in ["ukpga", "anaw", "asp", "nia", "apni"] do
    IO.puts(" x_ENACTED_BY")
    {:ok, record}
  end

  def get_enacting_laws(
        %LR{} = record,
        opts
      )
      when is_struct(record) do
    IO.puts(" ENACTED_BY")
    if opts.workflow == :Enact, do: IO.puts(record."Title_EN")

    get_enacting_laws(record)
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

  def get_enacting_laws(%{fields: %{Title_EN: title} = fields} = record, _opts)
      when is_map(record) do
    IO.puts("#{title}")

    with({:ok, record} <- get_enacting_laws(fields)) do
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
  def get_enacting_laws(record) do
    with(
      {:ok, enact} <- get_leg_gov_uk(record),
      {:ok, enact} <- text(enact),
      {:ok, enact} <- specific_enacting_clauses(enact),
      {:ok, enact} <- enacting_law_in_match(enact),
      {:ok, enact} <- enacting_law_in_enacting_text(enact),
      {:ok, record} <- enacted_by(enact, record),
      {:ok, record} <- enacted_by_description(enact, record)
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
    # we always need to use the /made/ rather than the latest version for ENACT
    path = Url.introduction_path_enact(record)

    case RecordGeneric.enacting_text(path) do
      {:ok, :xml, response} ->
        response = Kernel.struct(%Enact{}, response) |> Map.put(:enacting_laws, [])

        {:ok, response}

      {:ok, :html} ->
        {:error, "html"}

      {:error, code, error} ->
        {:error, code, error}
    end
  end

  @doc """
    Function to clean-up the enacting and introdcutory text

    Removes line returns

    Creates a new :text param combining enacting and introdcutory text into a single
    string
  """
  def text(%{introductory_text: iText, enacting_text: eText} = record) do
    text =
      (Regex.replace(~r/\n/m, iText, " ") <>
         " " <> Regex.replace(~r/\n/m, eText, " "))
      |> String.trim()

    case text do
      "" ->
        {:no_text, record}

      _ ->
        {:ok, Map.put(record, :text, text)}
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

  def specific_enacting_clauses(%{enacting_laws: enacting_laws, text: text} = record) do
    regexes = e_regexes() ++ s_regexes()

    enacting_laws =
      Enum.reduce(regexes, enacting_laws, fn {act, regex}, acc ->
        case Regex.run(regex, text) do
          nil -> acc
          _ -> [make_law_map(act) | acc]
        end
      end)

    {:ok, Map.put(record, :enacting_laws, enacting_laws)}
  end

  def enacting_law_in_match(%{urls: urls, text: text, enacting_laws: enacting_laws} = record) do
    regexes = [
      ~r/powers? conferred.*?by.*?and now vested in/,
      ~r/powers? conferred.*?by.*?having been designated/,
      ~r/powers? conferred.*?by.*?the Health and Safety at Work etc\. Act 1974 (?:\(“the 1974 Act”\) )?(?:f\d{5})?/,
      ~r/powers? conferred.*?by.*?the Health and Safety at Work etc\. Act 1974 (?:f\d{5} )?(?:\(“the 1974 Act”\))?/,
      ~r/powers? conferred.*?by.*?(?:etc\.).*?[\.:;]/,
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

    {:ok, %{record | enacting_laws: Kernel.++(enacting_laws, e_Laws)}}
  end

  @doc """
  Function scans the enacting text for ef-codes (fxxxxx) and cee-codes (cxxxxxxxx) and looks up the url of
  that ef-code / cee-code in the map of ef-codes / cee-codes.

  The function only runs if no enacting laws have been Id'd by mroe specific means
  """
  def enacting_law_in_enacting_text(%{enacting_text: _, urls: []} = record),
    do: {:ok, record}

  def enacting_law_in_enacting_text(
        %{enacting_laws: [], enacting_text: enacting_text, urls: urls} = record
      ) do
    get_url_refs(urls, enacting_text)
    # |> (&Kernel.++(enacting_laws, &1)).()
    |> (&{:ok, Map.put(record, :enacting_laws, &1)}).()
  end

  def enacting_law_in_enacting_text(record), do: {:ok, record}

  def get_url_refs(urls, text) do
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

  def get_urls(urls, text) do
    case Regex.scan(~r/(?:f\d{5}|(?:\[start_ref\]).*?(?:\[end_ref\]))/m, text) do
      nil ->
        {:none, []}

      [] ->
        # there are no ef-codes in the text
        {:none, []}

      codes ->
        # IO.puts(~s/URLS: #{inspect(urls)}\nCODES: #{inspect(codes)}/)
        # ef-code is the key to the enacting law's url
        # enumerate the ef-codes found in the text
        Enum.map(codes, fn [code] ->
          code = code |> String.replace("[start_ref]", "") |> String.replace("[end_ref]", "")
          Map.get(urls, code)
        end)
        |> Enum.concat()
        |> (&{:ok, &1}).()
    end
  end

  def match_on_year(url_set, text) do
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

  @spec enacting_laws(list()) :: {:ok, list()}
  def enacting_laws(urls) do
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

              [Legl.Countries.Uk.LeglRegister.IdField.id(type, year, number) | acc]

              # case Url.introduction_path(type, year, number) |> get_title() do
              #  {:ok, title} -> [make_law_map({title, type, year, number}) | acc]
              #  {:error, _error} -> acc
              # end
          end
      end
    end)
    |> Enum.uniq()
    |> (&{:ok, &1}).()
  end

  defp make_law_map({_title, type, year, number}) do
    Legl.Countries.Uk.LeglRegister.IdField.id(type, year, number)
  end

  @doc """
  Airtable 'Enacted_by' field

  A long text that needs a comma separated string
  """
  @spec enacted_by(%Enact{}, %LR{}) :: {:ok, %LR{}}
  def enacted_by(%{enacting_laws: enacting_laws} = _enact, record),
    do: {:ok, Map.put(record, :Enacted_by, enacting_laws |> Enum.uniq() |> Enum.join(","))}

  @doc """
  Airtable 'enacted_by_description' field
  """
  @spec enacted_by_description(%Enact{}, %LR{}) :: {:ok, %LR{}}
  def enacted_by_description(%{enacting_laws: enacting_laws} = _enact, record) do
    enacted_by_description =
      enacting_laws
      |> Enum.uniq()
      |> Enum.map(fn name ->
        [_, type_code, year, number] = String.split(name, "_")
        path = Url.introduction_path(type_code, year, number)
        title = get_title(path)
        ~s[#{name}\n#{title}\nhttps://legislation.gov.uk#{path}\n\n]
      end)
      |> Enum.join()
      |> String.trim_trailing("\n\n")

    {:ok, Map.put(record, :enacted_by_description, enacted_by_description)}
  end

  defp get_title(path) do
    case RecordGeneric.metadata(path) do
      {:ok, :xml, %{Title_EN: title}} ->
        title

      {:ok, :html} ->
        "api returning .html - set title manually"

      {:error, _code, error} ->
        error
    end
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
end
