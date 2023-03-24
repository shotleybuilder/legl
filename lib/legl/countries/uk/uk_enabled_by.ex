defmodule Legl.Countries.Uk.UkEnabledBy do

  alias Legl.Services.LegislationGovUk.RecordGeneric
  alias Legl.Countries.Uk.UkTypeCode
  alias Legl.Countries.Uk.UkAirtable, as: AT

  @new_law_csv "airtable_new_law?"
  @parents_csv "airtable_parents"

  @default_opts %{
    base_name: "UK E",
    t: :uksi,
    fields: ["Name", "Title_EN", "type_code", "Year", "Number", "Enabled by"],
    view: "Enabled_by"
  }

  def open_files() do
    {:ok, new_law_csv} = "lib/#{@new_law_csv}.csv" |> Path.absname() |> File.open([:utf8, :write, :read])
    IO.puts(new_law_csv, "Name,Title_EN,type_code,Year,Number")
    {:ok, parents_csv} = "lib/#{@parents_csv}.csv" |> Path.absname() |> File.open([:utf8, :write, :read])
    IO.puts(parents_csv,"Name,Title_EN,type_code,Year,Number,Enabled by")
    {new_law_csv, parents_csv}
  end
  @doc """
    opts

    Run as Legl.Countries.Uk.UkEnabledBy.run([t: type_code, base_name: base_name])
  """
  def run(opts \\ []) when is_list(opts) do

    opts = Enum.into(opts, @default_opts)

    {new_law_csv, parents_csv} = files = open_files()
    opts = Map.put(opts, :files, files)

    case Map.get(%UkTypeCode{}, Map.get(opts, :t)) do

      nil ->
        IO.puts("ERROR with option")

      types when is_list(types) ->

        Enum.each(types, fn type ->
          IO.puts(">>>#{type}")
          opts = Map.put(opts, :type, type)
          get_child_process(opts)
        end)

      type when is_binary(type) ->
        opts = Map.put(opts, :type, type)
        get_child_process(opts)
    end

    File.close(new_law_csv)
    File.close(parents_csv)
  end

  def get_child_process(opts) do

    opts = Map.put(opts, :formula, ~s/AND({type_code}="#{opts.type}",{Enabled by}=BLANK())/)

    {new_law_csv, parents_csv} = opts.files

    with {:ok, at_records} <- AT.get_records_from_at(opts),
      #IO.inspect(recordset)
      :ok <- get_parent_laws_from_leg_gov_uk(opts.files, at_records),
      :ok <- dedupe(new_law_csv),
      :ok <- dedupe(parents_csv)
    do
      #IO.puts("csv saved with #{count} records")
      :ok
    else
      {:error, error} -> IO.puts("#{error}")
    end
  end

  @doc """
    Legl.Countries.Uk.UkEnabledBy.get_parent_laws_from_leg_gov_uk()
  """
  def get_parent_laws_from_leg_gov_uk() do
    files = open_files()
    get_parent_laws_from_leg_gov_uk(files, Airtable.at_data())
  end

  def get_parent_laws_from_leg_gov_uk(files, records) do
    Enum.reduce(records, [],
      fn %{"fields" => %{"type_code" => type, "Year" => year, "Number" => number, "Title_EN" => title}} = x, acc ->
        IO.puts("#{title}")
        path = introduction_path(type, year, number)
        with(
          {:ok, response} <- get_parent(path),
          {:ok, response} <- parse_filter(response)
        ) do
          enacting_laws = Map.merge(x["fields"], response)
          record = %{x | "fields" => enacting_laws}
          make_csv_record(files, record)
          [record | acc]
        else
          {:error, _error} -> acc
        end
      end)
    :ok
  end

  @doc """

  """
  def dedupe(file) do
    File.read!(file)
    |> String.split("\n")
    |> Enum.uniq()
    |> Enum.join("\n")
    |> (&(File.write!(file, &1))).()
  end

  @doc """
    Deal with one record at a time
  """
  def make_csv_record(files, %{
    "fields" =>
    %{
      "Name" => name,
      "Title_EN" => title,
      "type_code" => type,
      "Year" => year,
      "Number" => number,
      enacting_laws: enacting_laws
    }
    } = _law) do
    case enacting_laws do
      [] -> :ok
      "" -> :ok
      nil -> :ok
      _ ->
        at_parent = at_parent(enacting_laws)
        title = title |> Legl.Utility.csv_quote_enclosure()
        [~s/#{name},#{title},#{type},#{year},#{number},#{at_parent}/]
        |> new_acting_laws(enacting_laws)
        |> Enum.reverse()
        |> save_record_to_csv(files)
    end
  end
  def make_csv_record(_record), do: :ok
  def make_csv_record(), do: nil

  def save_record_to_csv([child | new_parent?], {new_law_csv, parents_csv} = _files) do
      Enum.each(new_parent?, &IO.puts(new_law_csv, &1))
      IO.puts(parents_csv, child)
  end

  def open_airtable_data_from_file() do
    {:ok, binary} =
      "lib/airtable.txt"
      |> Path.absname()
      |> File.read()

    String.split(binary, "%")
    |> Enum.each(fn x -> IO.inspect(x) end)
  end

  def data do
    Enum.each(Airtable.at_data(), fn x -> IO.inspect(x) end)
  end

  def view_text_as_csv(text) do
    for {_k, v} when is_binary(v) == true <- text  do
      File.write!("lib/amending.csv" |> Path.absname(), v)
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
  def get_parent(path) do
    case RecordGeneric.enacting_text(path) do
      {:ok, :xml, response} ->
        {:ok, response}
      {:ok, :html} -> {:ok, "not found"}
      {:error, _code, error} -> {:error, error}
    end
  end

  def parse_filter(
    %{
      introductory_text: introductory_text,
      enacting_text: enacting_text,
      urls: urls
    } =
    response) do
      joined_text = text(introductory_text, enacting_text)
      cond do
        joined_text == nil -> {:ok, Map.put_new(response, :enacting_laws, [])}
        Regex.match?(~r/an Order under sections.*? of the Transport and Works Act 1992/, joined_text) == true ->
          {:ok, Map.put_new(response, :enacting_laws, [{"Transport and Works Act", "ukpga", "1992", "42"}])}
        Regex.match?(~r/in exercise of the powers in section.*? of the European Union \(Withdrawal\) Act 2018/, joined_text) == true ->
          {:ok, Map.put_new(response, :enacting_laws, [{"European Union (Withdrawal) Act", "ukpga", "2018", "16"}])}
        Regex.match?(~r/[T|t]he Secretary of State, in exercise of the powers.*? section[s]? 114.*? and 120.*? of the 2008 Act/, joined_text) ==  true ->
          {:ok, Map.put_new(response, :enacting_laws, [{"Planning Act", "ukpga", "2008", "29"}])}
        Regex.match?(~r/An application has been made to the Secretary of State under section 37 of the Planning Act 2008/, joined_text) == true ->
          {:ok, Map.put_new(response, :enacting_laws, [{"Planning Act", "ukpga", "2008", "29"}])}
        Regex.match?(~r/The Secretary of State has decided to grant development consent.*? of the 2008 Act/, joined_text) == true ->
          {:ok, Map.put_new(response, :enacting_laws, [{"Planning Act", "ukpga", "2008", "29"}])}
        Regex.match?(~r/^.*?powers conferred by.*?and now vested in it/, joined_text) == true ->
          Regex.run(~r/^.*?powers conferred by.*?and now vested in it/, joined_text)
          |> List.first()
          |> parse_text(urls, response)
        Regex.match?(~r/^.*?power[s]?[ ]conferred[ a-z]*?by.*?[:|\.|—|;]/, joined_text) == true ->
          Regex.run(~r/^.*?power[s]?[ ]conferred[ a-z]*?by.*?[:|\.|—|;]/, joined_text)
          |> List.first()
          |> parse_text(urls, response)
        Regex.match?(~r/f\d{5}/m, enacting_text) ==  true ->
          parse_text(enacting_text, urls, response)
        true ->
          {:ok, response}
      end
  end
  def text(nil, nil), do: nil
  def text(nil, enacting_text), do: Regex.replace(~r/\n/m, enacting_text, " ")
  def text(introductory_text, nil), do: Regex.replace(~r/\n/m, introductory_text, " ")
  def text(introductory_text, enacting_text) do
    Regex.replace(~r/\n/m, introductory_text, " ")<>" "<>Regex.replace(~r/\n/m, enacting_text, " ")
    |> String.trim()
  end

  def parse_text(nil, _urls, response) do
    {:ok, response}
  end

  def parse_text(text, urls, response) do
    #jtext = Regex.replace(~r/\n/m, text, " ") #|> IO.inspect
    matches = Regex.scan(~r/f\d{5}/m, text)
    case matches do
      _ ->
        parents =
          urls(urls, matches)
          |> parents()
        {:ok, Map.put_new(response, :enacting_laws, parents)}
    end

  end

  def urls(urls, matches) do
    Enum.map(matches, fn [x] ->
      Map.get(urls, x) |> to_string()
    end)
  end

  def parents(urls) do
    Enum.reduce(urls, [], fn x, acc ->
      case x do
        "" -> acc
        _ ->
          cond do
            Regex.match?(
              ~r/http:\/\/www.legislation.gov.uk\/id\/([a-z]*?)\/(\d{4})\/(\d+)$/, x) == true ->
                [_, type, year, number] =
                  Regex.run(~r/http:\/\/www.legislation.gov.uk\/id\/([a-z]*?)\/(\d{4})\/(\d+)$/, x)
                  case introduction_path(type, year, number) |> get_title() do
                    {:ok, title} -> [{title, type, year, number} | acc]
                    {:error, error} -> [{error, type, year, number} | acc]
                  end
            Regex.match?(
              ~r/http:\/\/www.legislation.gov.uk\/european\/directive\/(\d{4})\/(\d+)$/, x) == true ->
                [_, year, number] =
                  Regex.run(~r/http:\/\/www.legislation.gov.uk\/european\/directive\/(\d{4})\/(\d+)$/, x)
                [{"eu law", "eudr", year, number} | acc]
          end
      end
    end)
    |> Enum.uniq()
  end

  def get_title(path) do
    case Legl.Services.LegislationGovUk.Record.legislation(path) do
      {:ok, :xml, %{metadata: %{title: title}}} ->
        {:ok, title}
      {:ok, :html} -> {:ok, "not found"}
      {:error, _code, error} -> {:error, error}
    end
  end

  def introduction_path(type, year, number) do
     "/#{type}/#{year}/#{number}/introduction/made/data.xml"
  end

  #*****************************************************************
  #Helper functions
  #
  #*****************************************************************

  @doc """
    Content of the Airtable Parent field.
    A comma separated list within quote marks of the Airtable ID field (Name).
    "UK_ukpga_2010_41_abcd,UK_uksi_2013_57_abcd"
  """
  def at_parent({:url_error, url} = _enacting_laws), do: url

  def at_parent(enacting_laws) do
    Enum.map(enacting_laws, fn {title, type, year, number} ->
      Legl.Airtable.AirtableTitleField.title_clean(title)
      |> Legl.Airtable.AirtableIdField.id(type, year, number)
    end)
    |> Enum.sort()
    |> Enum.join(",")
    |> Legl.Utility.csv_quote_enclosure()
  end

  def new_acting_laws(recs, enacting_laws) do
    Enum.reduce(enacting_laws, recs, fn {title, type, year, number}, acc ->
      title =
        Legl.Airtable.AirtableTitleField.title_clean(title)
        |> Legl.Utility.csv_quote_enclosure()
      name = Legl.Airtable.AirtableIdField.id(title, type, year, number)
      [~s/#{name},#{title},#{type},#{year},#{number}/ | acc]
    end)
  end

  def field_names(records) do
    [~s/Name,Title_EN,Type,Year,Number,Child\sof/ | records]
  end

end
