defmodule Legl.Airtable.Schema do
  @moduledoc """

  """

  @default_schema_opts %{
    records: Types.Component.components_as_list(),
    dedupe: true
  }

  # alias __MODULE__

  @spec schema(
          binary,
          atom | %{:title_name => any, optional(any) => any},
          keyword
        ) :: binary
  @doc """
  Creates a tab-delimited binary suitable for copying into Airtable.
  """
  def schema(binary, regex, opts \\ []) do
    opts = Enum.into(opts, @default_schema_opts)

    with records <- records(binary, regex, opts),
         dupes <- dupes(records, "Duplicates"),
         # Dedupe the records if there are duplicate IDs
         records <- dedupe(records, dupes, opts),
         # Check the deduping worked
         dupes(records, "\nDuplicates after Codification") do
      Enum.count(records) |> (&IO.puts("\nnumber of records = #{&1}")).()

      records
    end
  end

  def component_for_regex(name) when is_atom(name) do
    Types.Component.mapped_components_for_regex() |> Map.get(name)
  end

  def records(binary, regex, opts) do
    # Regex OR structure "title|content|part|chapter|section|sub_section..."
    record_types = opts.records |> Enum.join("|")

    # First line is always the title
    [head | tail] = String.split(binary, "\n", trim: true)

    fields =
      case opts.type do
        :act -> UK.Act.act()
        :regulation -> UK.Regulation.regulation()
      end

    collector = [title(regex, head, fields)]

    # a _record_ represents a single line/row entry in Airtable
    # and is the rolling history of what's been
    # _records_ is a `t:list/0` of the set of records
    tail
    |> Enum.reduce(collector, fn str, acc ->
      # |> reset_region()
      last_record = hd(acc)

      case Regex.match?(~r/^\[::(#{record_types})::\]/, str) do
        true ->
          [tag] = Regex.run(~r/^#{Types.Component.components_for_regex_or()}/, str)

          case Regex.run(~r/^\[::([a-z_]+)::\]$/, tag) do
            [_m, tag] ->
              function = String.to_atom(tag)

              this_record =
                try do
                  Kernel.apply(__MODULE__, function, [
                    regex,
                    str,
                    last_record,
                    opts.type
                  ])
                rescue
                  _error ->
                    # IO.puts("ERROR: Function not found for #{inspect(function)}")
                    this_record_(regex, str, last_record, opts.type)
                end

              [this_record | acc]

            nil ->
              IO.inspect(tag, label: "error")
          end

        _ ->
          acc
      end
    end)
    # Add id of law directory table record into each article record
    |> Enum.reduce([], fn record, acc ->
      record = Map.put(record, :name, opts.name) |> add_id_to_record(opts)
      [record | acc]
    end)
  end

  def dupes(records, label) do
    Enum.reduce(records, [], fn x, acc -> Map.get(x, :id) |> (&[&1 | acc]).() end)
    |> Legl.Utility.duplicate_records()
    |> IO.inspect(label: label, limit: :infinity)
  end

  def dedupe(records, dupes, opts) do
    case opts.dedupe do
      true ->
        case Enum.count(dupes) do
          0 -> records
          _ -> make_record_duplicates_uniq(dupes, records, opts)
        end

      _ ->
        records
    end
  end

  @doc """

  """
  def add_id_to_record(record, %{country: :uk} = _opts) do
    Legl.Countries.Uk.AirtableArticle.UkArticleId.make_id(record)
  end

  def make_record_duplicates_uniq(dupes, records, %{country: :uk} = _opts) do
    Legl.Countries.Uk.AirtableArticle.UkArticleId.make_record_duplicates_uniq(dupes, records)
  end

  def title(regex, "[::title::]" <> str, last_record) do
    %{
      last_record
      | flow: "pre",
        type: regex.title_name,
        text: str
    }
  end

  def part(regex, "[::part::]" <> str, last_record, type \\ :regulation) do
    article_type =
      case last_record.flow do
        "post" -> "#{regex.annex_name}, #{regex.part_name}"
        _ -> regex.part_name
      end

    record =
      case Regex.run(~r/#{regex.part}/, str) do
        [_, value, text, region] ->
          case type do
            :act ->
              %{
                last_record
                | flow: flow(last_record),
                  type: article_type,
                  part: value,
                  text: text,
                  region: region
              }

            :regulation ->
              %{
                last_record
                | flow: flow(last_record),
                  type: article_type,
                  part: value,
                  text: text,
                  region: region
              }
          end

        [_, value, str] ->
          %{
            last_record
            | flow: flow(last_record),
              type: article_type,
              part: value,
              text: str
          }

        nil ->
          IO.inspect("ERROR part/4 #{regex.part} #{str}")
      end

    fields_reset(record, :part, regex)
  end

  @doc """
  A chapter inherits any Part numbering and sets a new Chapter level numbering
  on subsequent articles

  ## Regex

  To return the chapter number in the first capture group

  * FIN `^(\\d+)`
  * UK `^Chapter[ ](\\d+)`
  """
  def chapter(regex, "[::chapter::]" <> str, last_record, _type) do
    record =
      case Regex.run(~r/#{regex.chapter}/m, str) do
        [_, chap_num, txt, region] ->
          %{
            last_record
            | flow: flow(last_record),
              type: regex.chapter_name,
              chapter: chap_num,
              text: txt,
              region: region
          }

        [_, chap_num, txt] ->
          %{
            last_record
            | flow: flow(last_record),
              type: regex.chapter_name,
              chapter: chap_num,
              text: txt
          }

        [_, chap_num] ->
          %{
            last_record
            | flow: flow(last_record),
              type: regex.chapter_name,
              chapter: chap_num,
              text: str
          }

        nil ->
          IO.inspect("ERROR chapter/4 #{regex.chapter} #{str}")

        chap_num ->
          %{
            last_record
            | flow: flow(last_record),
              type: regex.chapter_name,
              chapter: chap_num,
              text: str
          }
      end

    fields_reset(record, :chapter, regex)
  end

  @doc """
  AIRTABLE Field: Heading
  When heading doesn't hold a number the number reverts to the last section number + A,B,C...
  This will create duplicate heading IDs
  """
  def heading(regex, "[::heading::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.heading}/, str) do
      [_, "", text, region] ->
        h = last_record.heading
        # heading? acts as a flag to indicate the start of the auto heading counter
        heading_num =
          case last_record.heading? do
            false ->
              h <> "A"

            true ->
              h
              |> String.last()
              |> (&Map.get(Legl.Utility.alphabet_to_numeric_map(), &1)).()
              |> (&Kernel.+(&1, 1)).()
              |> (&Kernel.++([h], ["#{<<&1::utf8>>}"])).()
              |> Enum.join()
          end

        %{
          last_record
          | flow: flow(last_record),
            type: "#{regex.heading_name}",
            heading: heading_num,
            text: text,
            region: region,
            heading?: true
        }
        |> fields_reset(:heading, regex)

      [_, value, text, region] ->
        %{
          last_record
          | flow: flow(last_record),
            type: "#{regex.heading_name}",
            heading: value,
            text: text,
            region: region,
            heading?: false
        }
        |> fields_reset(:heading, regex)

      [_, value, str] ->
        %{
          last_record
          | flow: flow(last_record),
            type: "#{regex.heading_name}",
            heading: value,
            text: str,
            heading?: false
        }
        |> fields_reset(:heading, regex)

      nil ->
        IO.inspect("ERROR heading/4 #{regex.heading} #{str}")
    end
  end

  def this_record_(regex, "[::heading::]" <> str, last_record, _type) do
    heading(regex, "[::heading::]" <> str, last_record, nil)
  end

  def this_record_(regex, "[::article::]" <> str, last_record, _type) do
    article(regex, "[::article::]" <> str, last_record, nil)
  end

  def this_record_(regex, "[::sub_article::]" <> str, last_record, _type) do
    sub_article(regex, "[::sub_article::]" <> str, last_record, nil)
  end

  def this_record_(regex, "[::paragraph::]" <> str, last_record, _type) do
    clause(:paragraph, regex, str, last_record)
  end

  def this_record_(regex, "[::sub_paragraph::]" <> str, last_record, _type) do
    sub_clause(:sub_paragraph, regex, str, last_record)
  end

  def this_record_(regex, "[::table::]" <> str, last_record, _type) do
    table(regex, "[::table::]" <> str, last_record, nil)
  end

  def this_record_(regex, "[::figure::]" <> str, last_record, _type) do
    figure(regex, "[::figure::]" <> str, last_record, nil)
  end

  def this_record_(
        %{country: :UK} = regex,
        "[::amendment_heading::]" <> str,
        last_record,
        _type
      ) do
    case Regex.run(~r/#{regex.amendment_heading}/, str) do
      [amd_hd] ->
        %{
          last_record
          | type:
              Legl.Utility.csv_quote_enclosure("#{regex.amendment_name},#{regex.heading_name}"),
            text: amd_hd
        }

        # |> fields_reset(:section, regex)
    end
  end

  def this_record_(regex, "[::subordinate_heading::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.subordinate_heading}/, str) do
      [txt] ->
        %{
          last_record
          | type:
              Legl.Utility.csv_quote_enclosure("#{regex.subordinate_name},#{regex.heading_name}"),
            text: txt
        }

        # |> fields_reset(:section, regex)
    end
  end

  def this_record_(%{country: :UK} = regex, "[::subordinate::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.subordinate}/, str) do
      [_, code, num, str] ->
        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.subordinate_name},content"),
            text: code <> num <> str,
            amendment: num,
            sub_section: ""
        }

      nil ->
        IO.puts("ERROR amendment/4 regex: #{regex.amendment} string: #{str}")
    end
  end

  def this_record_(_schema, record, last_record, _) do
    IO.puts("ERROR: this_record_/4 #{record}\nLast Record: #{inspect(last_record)}")
    last_record
  end

  @doc """
  AIRTABLE FIELD : Section||Regulation
  also used for : paragraphs for Schedules
  """

  def clause(name, regex, str, last_record) when name in [:paragraph] do
    fields_reset(last_record, :section, regex)
    s_regex = Map.get(regex, name)

    type = Map.get(regex, String.to_atom(Atom.to_string(name) <> "_name"))

    case Regex.run(~r/#{s_regex}/m, str) do
      [_, n, "", text, region] ->
        # inherit region
        region = if region == "", do: last_record.region, else: region

        %{
          last_record
          | flow: flow(last_record),
            type: type,
            section: n,
            text: text,
            region: region
        }
        |> fields_reset(:section, regex)

      [_, n, nn, text, region] ->
        # inherit region
        region = if region == "", do: last_record.region, else: region

        %{
          last_record
          | flow: flow(last_record),
            type: type,
            section: n,
            sub_section: nn,
            text: text,
            region: region
        }
        |> fields_reset(:sub_section, regex)

      [_, n, "", text] ->
        %{
          last_record
          | flow: flow(last_record),
            type: type,
            section: n,
            text: text
        }
        |> fields_reset(:section, regex)

      [_, n, nn, text] ->
        %{
          last_record
          | flow: flow(last_record),
            type: type,
            section: n,
            sub_section: nn,
            text: text
        }
        |> fields_reset(:sub_section, regex)

      nil ->
        IO.puts("ERROR: clause/4 => regex: #{s_regex} str: #{str}")
        last_record
    end
  end

  def section(regex, "[::section::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.section}/m, str) do
      [_, section_number, "", text, region] ->
        %{
          last_record
          | flow: flow(last_record),
            type: regex.section_name,
            section: section_number,
            text: text,
            region: region
        }
        |> fields_reset(:section, regex)

      [_, section_number, sub_section_number, text, region] ->
        %{
          last_record
          | flow: flow(last_record),
            type: regex.section_name,
            section: section_number,
            sub_section: sub_section_number,
            text: text,
            region: region
        }
        |> fields_reset(:sub_section, regex)

      [_, section_number, text, region] ->
        %{
          last_record
          | flow: flow(last_record),
            type: regex.section_name,
            section: section_number,
            text: text,
            region: region
        }
        |> fields_reset(:section, regex)

      [_, section_number, text] ->
        %{
          last_record
          | flow: flow(last_record),
            type: regex.section_name,
            section: section_number,
            text: text
        }
        |> fields_reset(:section, regex)

      [_, text] ->
        %{
          last_record
          | type: regex.section_name,
            section: increment(last_record.section),
            text: text
        }
        |> fields_reset(:section, regex)

      nil ->
        IO.inspect("#{str}", label: "ERROR: section/4")
    end
  end

  @doc """
  AIRTABLE FIELD : Sub_Section||Sub_Regulation
  also used for : sub_paragraphs for Schedules
  """

  def sub_clause(name, regex, str, last_record)
      when name in [:sub_paragraph] and is_map(last_record) do
    fields_reset(last_record, :sub_section, regex)
    s_regex = Map.get(regex, name)

    type = Map.get(regex, String.to_atom(Atom.to_string(name) <> "_name"))

    record =
      case Regex.run(~r/#{s_regex}/m, str) do
        [_, n, t] ->
          %{
            last_record
            | flow: flow(last_record),
              type: type,
              sub_section: n,
              text: String.replace(t, "[::region::]", ""),
              # inherit region from last record
              region: last_record.region
          }

        nil ->
          IO.puts("ERROR: clause/4 => regex: #{s_regex} str: #{str}")
      end

    fields_reset(record, :sub_section, regex)
  end

  def sub_clause(name, _regex, str, last_record) do
    IO.puts("ERROR: #{name}\n#{str}\n#{inspect(last_record)}")
    last_record
  end

  def sub_section(regex, "[::sub_section::]" <> str, last_record, _type) do
    fields_reset(last_record, :sub_section, regex)

    record =
      case Regex.run(~r/#{regex.sub_section}/m, str) do
        [_, n, t] ->
          %{
            last_record
            | flow: flow(last_record),
              type: regex.sub_section_name,
              sub_section: n,
              text: t
          }

        nil ->
          IO.puts("ERROR: sub_section/4 => regex: #{regex.sub_section} str: #{str}")
      end

    fields_reset(record, :sub_section, regex)
  end

  @doc """
  ## Regex

  To return the article number in the 1st capture group
  To return the sub-article number in the 2nd capture group

  * FIN `^(\d+)`
  * UK ^(\d+[a-zA-Z]*)-?(\d+)?[ ](.*)[ ]\[::region::\](.*)
  * AUT `^§[ ](\d+)`
  """
  def article(regex, "[::article::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.article}/, str) do
      nil ->
        IO.inspect("ERROR article #{regex.article} #{str}")

        case last_record.flow do
          "post" ->
            [_, value] = Regex.run(~r/^(\d+)\./, str)
            %{last_record | type: "annex, #{regex.article_name}", para: value, text: str}

          _ ->
            %{last_record | type: regex.article_name, text: str}
            |> fields_reset(:section, regex)
        end

      [_, article, "", text, region] ->
        region = if region == "", do: last_record.region, else: region

        %{
          last_record
          | flow: flow(last_record),
            type: regex.article_name,
            section: article,
            text: text,
            region: region
        }
        |> fields_reset(:section, regex)

      [_, article, sub_article, text, region] ->
        region = if region == "", do: last_record.region, else: region

        %{
          last_record
          | type: "#{regex.article_name}",
            section: article,
            sub_section: sub_article,
            text: text,
            region: region
        }
        |> fields_reset(:sub_section, regex)

      [_, article, sub_article, text] ->
        %{
          last_record
          | type: "#{regex.article_name}",
            section: article,
            sub_section: sub_article,
            text: text
        }
        |> fields_reset(:sub_section, regex)
    end
  end

  @doc """

  """
  def sub_article(%{country: :UK} = regex, "[::sub_article::]" <> str, last_record, _type) do
    fields_reset(last_record, :sub_section, regex)

    record =
      case Regex.run(~r/#{regex.sub_article}/m, str) do
        [_, n, t] ->
          %{
            last_record
            | flow: flow(last_record),
              type: regex.sub_article_name,
              sub_section: n,
              text: t,
              region: last_record.region
          }
      end

    fields_reset(record, :sub_section, regex)
  end

  def sub_article(regex, "[::sub_article::]" <> str, last_record, _type) do
    # str = String.replace(str, sub_article_emoji(), "")
    [_, value, str] = Regex.run(~r/#{regex.sub_article}/, str)

    cond do
      last_record.flow == "prov" ->
        %{last_record | type: regex.amending_sub_article_name, sub: value, text: str}

      last_record.flow == "post" ->
        %{last_record | type: regex.amending_sub_article_name, para: value, text: str}
        |> fields_reset(:para, regex)

      true ->
        %{last_record | type: regex.sub_article_name, para: value, text: str}
        |> fields_reset(:para, regex)
    end
  end

  def para(regex, "[::para::]" <> str, last_record, _type) do
    [para, txt] =
      case Regex.run(~r/#{regex.para}/, str) do
        [_, para, txt] ->
          [para, txt]

        nil ->
          IO.puts("regex: #{regex.para} str: #{str}")
          ["NaN", ""]
      end

    %{last_record | type: regex.para_name, para: para, text: txt}
    |> fields_reset(:para, regex)
  end

  def sub(regex, "[::sub::]" <> str, last_record, _type) do
    [_, _article, _para, sub, txt] = Regex.run(~r/#{regex.sub}/, str)

    %{last_record | type: regex.sub_name, sub: sub, text: txt}
  end

  @doc """
  Creates an annex record

  Regex:
  * UK `^SCHEDULE[ ](\d+)`
  * AUT `^Anlage[ ](\d+)`

  """
  def annex(regex, "[::annex::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.annex}/, str) do
      [_, annex_num, annex, annex_name, region] ->
        annex_num =
          cond do
            annex_num != "" -> annex_num
            annex_name == "SCHEDULE" -> "1"
            true -> "post"
          end

        %{
          last_record
          | type: regex.annex_name,
            text: annex,
            flow: annex_num,
            region: region
        }
        |> fields_reset(:all, regex)

      [_, annex_num, annex, region] ->
        annex_num =
          cond do
            annex_num != "" -> annex_num
            true -> "post"
          end

        %{
          last_record
          | type: regex.annex_name,
            text: annex,
            flow: annex_num,
            region: region
        }
        |> fields_reset(:all, regex)

      [_, annex_num, annex] ->
        annex_num = if annex_num != "", do: annex_num, else: "post"

        %{
          last_record
          | type: regex.annex_name,
            text: annex,
            flow: annex_num
        }
        |> fields_reset(:all, regex)

      nil ->
        IO.inspect("ERROR regex: #{regex.annex} record: #{str}")
        last_record
    end
  end

  def form(regex, "[::form::]" <> str, last_record, _type) do
    [_, form_num, form] = Regex.run(~r/#{regex.form}/, str)

    %{
      last_record
      | type: regex.form_name,
        part: form_num,
        text: form
    }
    |> fields_reset(:part, regex)
  end

  def amendment(%{country: :UK} = regex, "[::amendment::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.amendment}/, str) do
      [_, amd_code, amd_num, str] ->
        last_record =
          if last_record.max_amendments < String.to_integer(amd_num),
            do: %{last_record | max_amendments: String.to_integer(amd_num)},
            else: last_record

        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.amendment_name},textual"),
            text: amd_code <> amd_num <> str,
            amendment: amd_num,
            sub_section: ""
        }

      nil ->
        IO.puts("ERROR amendment/4 regex: #{regex.amendment} string: #{str}")
    end
  end

  def amendment(regex, "[::amendment::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.amendment}/, str) do
      [_, art_num, para_num, str] ->
        cond do
          regex.country == :tur ->
            %{
              last_record
              | type: "#{regex.amendment_name}",
                para: art_num,
                sub: is_para_num(para_num),
                text: str,
                flow: "prov"
            }

          true ->
            %{
              last_record
              | type: "#{regex.amendment_name}",
                article: art_num,
                para: is_para_num(para_num),
                text: str,
                flow: "post"
            }
        end

      [_, amd_number, text] ->
        %{
          last_record
          | type: "#{regex.amendment_name}",
            section: amd_number,
            text: text
        }

      [_, str] ->
        %{
          last_record
          | type: "#{regex.amendment_name}",
            text: str
        }
    end
  end

  def modification_heading(
        %{country: :UK} = regex,
        "[::modification_heading::]" <> str,
        last_record,
        _type
      ) do
    case Regex.run(~r/#{regex.modification_heading}/, str) do
      [md_hd] ->
        %{
          last_record
          | type:
              Legl.Utility.csv_quote_enclosure("#{regex.modification_name},#{regex.heading_name}"),
            text: md_hd
        }
        |> fields_reset(:section, regex)
    end
  end

  def modification(%{country: :UK} = regex, "[::modification::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.modification}/, str) do
      [_, code, num, str] ->
        last_record =
          if last_record.max_modifications < String.to_integer(num),
            do: %{last_record | max_modifications: String.to_integer(num)},
            else: last_record

        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.modification_name},content"),
            text: code <> num <> str,
            amendment: num,
            sub_section: ""
        }

      nil ->
        IO.puts("ERROR modification/4 regex: #{regex.modification} string: #{str}")
    end
  end

  def commencement_heading(
        %{country: :UK} = regex,
        "[::commencement_heading::]" <> str,
        last_record,
        _type
      ) do
    case Regex.run(~r/#{regex.commencement_heading}/, str) do
      [cmc_hd] ->
        %{
          last_record
          | type:
              Legl.Utility.csv_quote_enclosure("#{regex.commencement_name},#{regex.heading_name}"),
            text: cmc_hd
        }
        |> fields_reset(:section, regex)
    end
  end

  def commencement(%{country: :UK} = regex, "[::commencement::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.commencement}/, str) do
      [_, code, num, str] ->
        last_record =
          if last_record.max_commencements < String.to_integer(num),
            do: %{last_record | max_commencements: String.to_integer(num)},
            else: last_record

        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.commencement_name},content"),
            text: code <> num <> str,
            amendment: num,
            sub_section: ""
        }
    end
  end

  def extent_heading(%{country: :UK} = regex, "[::extent_heading::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.extent_heading}/, str) do
      [cmc_hd] ->
        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.extent_name},#{regex.heading_name}"),
            text: cmc_hd
        }
        |> fields_reset(:section, regex)
    end
  end

  def extent(%{country: :UK} = regex, "[::extent::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.extent}/, str) do
      [_, code, num, str] ->
        last_record =
          if last_record.max_extents < String.to_integer(num),
            do: %{last_record | max_extents: String.to_integer(num)},
            else: last_record

        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.extent_name},content"),
            text: code <> num <> str,
            amendment: num,
            sub_section: ""
        }
    end
  end

  def editorial_heading(
        %{country: :UK} = regex,
        "[::editorial_heading::]" <> str,
        last_record,
        _type
      ) do
    case Regex.run(~r/#{regex.editorial_heading}/, str) do
      [hd] ->
        %{
          last_record
          | type:
              Legl.Utility.csv_quote_enclosure("#{regex.editorial_name},#{regex.heading_name}"),
            text: hd
        }
        |> fields_reset(:section, regex)
    end
  end

  def editorial(%{country: :UK} = regex, "[::editorial::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.editorial}/, str) do
      [_, code, num, str] ->
        last_record =
          if last_record.max_extents < String.to_integer(num),
            do: %{last_record | max_editorials: String.to_integer(num)},
            else: last_record

        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.editorial_name},content"),
            text: code <> num <> str,
            amendment: num,
            sub_section: ""
        }
    end
  end

  def approval(regex, "[::approval::]" <> str, last_record, _type) do
    %{
      last_record
      | flow: "pre",
        type: "#{regex.approval_name}",
        text: str
    }
    |> fields_reset(:all, regex)
  end

  def signed(regex, "[::signed::]" <> str, last_record, _type) do
    %{
      last_record
      | flow: "signed",
        type: "#{regex.signed_name}",
        text: str
    }
    |> fields_reset(:all, regex)
  end

  @doc """
  Uses a counter to increment table number
  """
  def table(regex, "[::table::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.table}/, str) do
      [txt] ->
        table_num = last_record.table_counter + 1

        %{
          last_record
          | type: regex.table_name,
            text: txt,
            para: table_num,
            table_counter: table_num
        }

        # |> IO.inspect()
    end
  end

  def figure(regex, "[::figure::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.figure}/, str) do
      [txt] ->
        figure_num = last_record.figure_counter + 1

        %{
          last_record
          | type: regex.figure_name,
            text: txt,
            para: figure_num,
            table_counter: figure_num
        }
    end
  end

  def sub_table(regex, "[::sub_table::]" <> str, last_record, _type) do
    [_, table_num, text] = Regex.run(~r/#{regex.table}/, str)

    # IO.puts("___ST___\ntype: #{last_record.type}\nsection: #{last_record.section}\nsub_section: #{last_record.sub_section}\npara: #{last_record.para}")

    field =
      cond do
        last_record.section == "" -> :section
        last_record.sub_section == "" -> :sub_section
        true -> :para
      end

    Map.merge(
      last_record,
      %{type: regex.sub_table_name, text: text, "#{field}": table_num}
    )
    |> IO.inspect()
    |> fields_reset(field, regex)
  end

  def note(regex, "[::note::]" <> str, last_record, _type) do
    [_, note] = Regex.run(~r/#{regex.note}/, str)

    %{
      last_record
      | type: regex.note_name,
        text: note
    }
    |> fields_reset(:all, regex)
  end

  def footnote(regex, "[::footnote::]" <> str, last_record, _type) do
    [_, ftn] = Regex.run(~r/#{regex.note}/, str)

    %{
      last_record
      | type: "#{last_record.type}, #{regex.footnote_name}",
        text: ftn
    }

    # |> fields_reset(:all, regex)
  end

  defp is_para_num(str) do
    case Integer.parse(str) do
      :error -> ""
      _ -> str
    end
  end

  @doc """
  Resets all numeric fields to "" in the hierarchy below the field
  If the optional step is set to 0 then the given field is also set to ""
  """

  def fields_reset(record, field, regex, step \\ 1)

  def fields_reset(record, :all, %{number_fields: fields}, _step) do
    Enum.reduce(fields, record, fn x, acc -> Map.replace(acc, x, "") end)
  end

  def fields_reset(record, field, %{number_fields: fields}, step) do
    index = Enum.find_index(fields, fn x -> x == field end) |> (&Kernel.+(&1, step)).()
    {_, fields} = Enum.split(fields, index)
    Enum.reduce(fields, record, fn x, acc -> Map.replace(acc, x, "") end)
  end

  def reset_region(record) do
    %{record | region: ""}
  end

  def increment(""), do: "1"

  def increment(" "), do: "1"

  def increment(value) do
    String.to_integer(value)
    |> (&Kernel.+(&1, 1)).()
    |> Integer.to_string()
  end

  def flow(%{flow: flow}) do
    case flow do
      "pre" -> "main"
      "" -> "main"
      _ -> flow
    end
  end
end
