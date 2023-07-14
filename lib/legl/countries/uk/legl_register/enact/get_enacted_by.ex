defmodule Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy do
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

  def get_enacting_laws(records, opts) do
    Enum.reduce(records, [], fn %{"fields" => %{"Title_EN" => title}} = record, acc ->
      IO.puts("#{title}")

      with(
        record = Map.merge(record, %{enacting_laws: [], urls: nil, text: ""}),
        {:ok, record} <- get_leg_gov_uk(record),
        {:ok, record} <- text(record),
        {:ok, record} <- specific_enacting_clauses(record, opts),
        {:ok, record} <- enacting_law_in_match(record),
        {:ok, record} <- enacting_law_in_enacting_text(record),
        {:ok, record} <- dedupe(record),
        {:ok, record} <- enacted_by(record)
      ) do
        [record | acc]
      else
        {:error, error} ->
          IO.puts("ERROR get_enacting_laws/1 #{error}")
          acc

        {:no_text, record} ->
          # avoids parsing if there is no text
          [record | acc]
      end
    end)
    |> (&{:ok, &1}).()
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
  def get_leg_gov_uk(
        %{
          "fields" => %{
            "type_code" => type,
            "Year" => year,
            "Number" => number
          }
        } = record
      ) do
    path = Url.introduction_path(type, year, number)

    case RecordGeneric.enacting_text(path) do
      {:ok, :xml, %{urls: urls} = response} ->
        %{introductory_text: i, enacting_text: e, urls: u} = %{
          response
          | urls: urls_to_string(urls)
        }

        fields = Map.merge(record["fields"], %{introductory_text: i, enacting_text: e})
        record = %{record | "fields" => fields, urls: u}
        {:ok, record}

      {:ok, :html} ->
        {:ok, "html"}

      {:error, _code, error} ->
        {:error, error}
    end
  end

  defp urls_to_string(urls) do
    Enum.reduce(urls, %{}, fn {k, v}, acc ->
      Map.put(acc, k, "#{v}")
    end)
  end

  defp text(%{"fields" => %{introductory_text: iText, enacting_text: eText}} = record) do
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
    []
  end

  defp enacting_law_in_match(%{urls: urls, text: text, enacting_laws: eLaws} = record) do
    regexes = [
      ~r/^.*?powers conferred by.*?and now vested in it/,
      ~r/^.*?power[s]?[ ]conferred[ a-z]*?by.*?[:|\.|—|;]/
    ]

    eLaws =
      Enum.reduce(regexes, [], fn regex, acc ->
        case Regex.run(regex, text) do
          nil ->
            acc

          [match | _] ->
            acc ++ get_url_refs(urls, match)
        end
      end)
      |> (&Kernel.++(eLaws, &1)).()

    {:ok, %{record | enacting_laws: eLaws}}
  end

  @doc """
  Function scans the enacting text for ef-codes (fxxxxx) and looks up the url of that ef-code in the map of ef-codes
  """
  def enacting_law_in_enacting_text(
        %{"fields" => %{enacting_text: text}, urls: urls, enacting_laws: eLaws} = record
      ) do
    eLaws =
      get_url_refs(urls, text)
      |> (&Kernel.++(eLaws, &1)).()

    {:ok, %{record | enacting_laws: eLaws}}
  end

  defp get_url_refs(urls, text) do
    case Regex.scan(~r/f\d{5}/m, text) do
      [] ->
        # there are no ef-codes in the text
        []

      fCodes ->
        # ef-code is the key to the enacting law's url
        Enum.map(fCodes, fn [fCode] ->
          Map.get(urls, fCode) |> to_string()
        end)
        # translate the url into the specific params for the enacting law
        |> enacting_laws()
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
                {:error, error} -> [make_law_map({error, type, year, number}) | acc]
              end
          end
      end
    end)
    |> Enum.uniq()
  end

  defp get_title(path) do
    case Legl.Services.LegislationGovUk.Record.legislation(path) do
      {:ok, :xml, %{title: title}} ->
        {:ok, title}

      {:ok, :html} ->
        {:ok, "not found"}

      {:error, _code, error} ->
        {:error, error}
    end
  end

  defp make_law_map({title, type, year, number}) do
    id =
      Legl.Airtable.AirtableTitleField.title_clean(title)
      |> Legl.Airtable.AirtableIdField.id(type, year, number)

    %{
      id: id,
      title: title,
      type: type,
      year: year,
      number: number
    }
  end

  def dedupe(%{enacting_laws: eLaws} = record) do
    {:ok, %{record | enacting_laws: Enum.uniq(eLaws)}}
  end

  def enacted_by(%{enacting_laws: eLaws} = record) do
    enacted_by =
      Enum.map(eLaws, fn %{id: id} = _eLaw -> id end)
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()

    {:ok, %{record | "fields" => Map.put(record["fields"], :Enacted_by, enacted_by)}}
  end
end
