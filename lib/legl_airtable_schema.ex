defmodule Legl.Airtable.Schema do
  @moduledoc """

  """

  @act_csv "airtable_act"
  @regulation_csv "airtable_regulation"
  @airtable_columns [
    "ID",
    "UK",
    "Flow",
    "Record_Type",
    "Part",
    "Chapter",
    "Heading",
    "Section||Regulation",
    "Sub_Section||Sub_Regulation",
    "Paragraph",
    "Sub_Paragraph",
    "Amendment",
    "paste_text_here",
    "Region",
    "Changes"
  ]

  def at_cols(), do: Enum.join(@airtable_columns, ",")

  def open_file(:act) do
    {:ok, csv} = "lib/#{@act_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])

    IO.puts(
      csv,
      at_cols()
    )

    csv
  end

  def open_file(:regulation) do
    {:ok, csv} = "lib/#{@regulation_csv}.csv" |> Path.absname() |> File.open([:utf8, :write])

    IO.puts(
      csv,
      at_cols()
    )

    csv
  end

  def component_for_regex(name) when is_atom(name) do
    Types.Component.mapped_components_for_regex() |> Map.get(name)
  end

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

    file = open_file(opts.type)

    records =
      records(binary, regex, opts)
      |> Enum.reduce([], fn record, acc ->
        record = Map.put(record, :name, opts.name) |> add_id_to_record(opts)
        [record | acc]
      end)

    # Find any dupes
    dupes =
      Enum.reduce(records, [], fn x, acc -> Map.get(x, :id) |> (&[&1 | acc]).() end)
      |> Legl.Utility.duplicate_records()
      |> IO.inspect(label: "Duplicates", limit: :infinity)

    # Dedupe the records if there are duplicate IDs
    records =
      case opts.dedupe do
        true ->
          case Enum.count(dupes) do
            0 -> records
            _ -> make_record_duplicates_uniq(dupes, records, opts)
          end

        _ ->
          records
      end

    if opts.dedupe,
      # Check the deduping worked
      do:
        Enum.reduce(records, [], fn x, acc -> Map.get(x, :id) |> (&[&1 | acc]).() end)
        |> Legl.Utility.duplicate_records()
        |> IO.inspect(label: "\nDuplicates after Codification", limit: :infinity)

    records = Enum.map(records, &convert_region_code(&1))

    # 'Changes' field holds list of changes (amendments, mods) applying to that record
    r = List.last(records)

    change_stats = [
      amendments: {r.max_amendments, "F"},
      modifications: {r.max_modifications, "C"},
      commencements: {r.max_commencements, "I"},
      extents: {r.max_extents, "E"}
    ]

    # Print change stats to the console
    Enum.each(change_stats, fn {k, {total, code}} -> IO.puts("#{k} #{total} code: #{code}") end)

    # rng = List.last(records).max_amendments |> IO.inspect(label: "Amendments (Fs)")
    records =
      Enum.map(records, fn record ->
        Enum.reduce(change_stats, record, fn {_k, {total, code}}, acc ->
          case total == 0 do
            true ->
              acc

            _ ->
              find_change_in_record(code, total, acc)
          end
        end)
      end)

    Enum.count(records) |> (&IO.puts("number of records = #{&1}")).()

    Enum.each(records, fn record ->
      copy_to_csv(file, record)
    end)

    File.close(file)

    # A proxy of the Airtable table useful for debugging 'at_tabulated.txt'
    Legl.Countries.Uk.AirtableArticle.UkArticlePrint.make_tabular_txtfile(records, opts)
    |> IO.puts()

    Enum.map(records, fn x -> conv_map_to_record_string(x, opts) end)
    # |> Enum.reverse()
    |> Enum.join("\n")
  end

  @doc """
  Search for the change markers in the provision texts only
  """
  def find_change_in_record(code, rng, %{type: "section"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "sub-section"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "article"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(code, rng, %{type: "sub-article"} = record),
    do: find_change_in_record({code, rng, record})

  def find_change_in_record(_code, _rng, record), do: record

  def find_change_in_record({code, rng, record}) do
    Enum.reduce(1..rng, record, fn n, acc ->
      case String.contains?(record.text, ~s/#{code}#{n} /) do
        true ->
          changes = [~s/#{code}#{n}/ | acc.changes]
          %{acc | changes: changes}

        false ->
          acc
      end
    end)
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
              this_record =
                Kernel.apply(__MODULE__, String.to_atom(tag), [regex, str, last_record, opts.type])

              [this_record | acc]

            nil ->
              IO.inspect(tag, label: "error")
          end

        _ ->
          acc
      end
    end)
  end

  @spec conv_map_to_record_string(map, any) :: binary
  def conv_map_to_record_string(%_{} = record, %{fields: fields} = _opts) do
    Map.from_struct(record)
    |> conv_map_to_record_string(fields)
  end

  def conv_map_to_record_string(%{sub: 0} = record, fields) when is_map(record),
    do: conv_map_to_record_string(%{record | sub: ""}, fields)

  def conv_map_to_record_string(record, fields) when is_map(record) do
    fields
    |> Enum.reduce([], fn x, acc -> [Map.get(record, x) | acc] end)
    |> Enum.reduce(
      [],
      fn
        nil, acc -> acc
        x, acc -> [x | acc]
      end
    )
    |> Enum.join("\t")
  end

  def copy_to_csv(
        file,
        %{
          id: id,
          name: name,
          flow: flow,
          type: record_type,
          part: part,
          chapter: chapter,
          heading: heading,
          section: section,
          sub_section: sub_section,
          para: para,
          sub_para: sub_para,
          amendment: amendment,
          region: region,
          text: text,
          changes: changes
        } = _record
      ) do
    changes =
      changes
      |> Enum.reverse()
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()

    [
      id,
      name,
      flow,
      record_type,
      part,
      chapter,
      heading,
      section,
      sub_section,
      para,
      sub_para,
      amendment,
      Legl.Utility.csv_quote_enclosure(text),
      region,
      changes
    ]
    # |> IO.inspect()
    |> Enum.join(",")
    |> (&IO.puts(file, &1)).()
  end

  @doc """

  """
  def add_id_to_record(record, %{country: :uk} = _opts) do
    Legl.Countries.Uk.AirtableArticle.UkArticleId.make_id(record)
  end

  def make_record_duplicates_uniq(dupes, records, %{country: :uk} = _opts) do
    Legl.Countries.Uk.AirtableArticle.UkArticleId.make_record_duplicates_uniq(dupes, records)
  end

  @doc """

  """

  def convert_region_code(%{region: ""} = record), do: record

  def convert_region_code(%{region: "U.K."} = record) do
    region = Legl.Utility.csv_quote_enclosure("UK,England,Wales,Scotland,Northern Ireland")
    %{record | region: region}
  end

  def convert_region_code(%{region: "E+W+S"} = record) do
    region = Legl.Utility.csv_quote_enclosure("GB,England,Wales,Scotland")
    %{record | region: region}
  end

  def convert_region_code(%{region: "E"} = record), do: %{record | region: "England"}

  def convert_region_code(%{region: "S"} = record), do: %{record | region: "Scotland"}

  def convert_region_code(%{region: "W"} = record), do: %{record | region: "Wales"}

  def convert_region_code(%{region: "N.I."} = record), do: %{record | region: "Northern Ireland"}

  def convert_region_code(%{region: region} = record) when region in ["E+W", "E+W+N.I."] do
    region =
      String.split(region, "+")
      |> Enum.reduce([], fn x, acc ->
        cond do
          x == "E" -> ["England" | acc]
          x == "W" -> ["Wales" | acc]
          x == "N.I." -> ["Northern Ireland" | acc]
          x == "S" -> ["Scotland" | acc]
          true -> IO.inspect(x, label: "convert_region_code/1")
        end
      end)
      |> Enum.reverse()
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()

    %{record | region: region}
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

  def heading(regex, "[::heading::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.heading}/, str) do
      [_, value, text, region] ->
        %{
          last_record
          | flow: flow(last_record),
            type: "#{regex.heading_name}",
            heading: value,
            text: text,
            region: region
        }
        |> fields_reset(:heading, regex)

      [_, value, str] ->
        %{
          last_record
          | flow: flow(last_record),
            type: "#{regex.heading_name}",
            heading: value,
            text: str
        }
        |> fields_reset(:heading, regex)

      nil ->
        IO.inspect("ERROR heading/4 #{regex.heading} #{str}")
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
            |> fields_reset(:article, regex)
        end

      [_, article, "", text, region] ->
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
              text: t
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
        IO.inspect("ERROR #{regex.annex} #{str}")
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

  def amendment_heading(
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
        |> fields_reset(:section, regex)
    end
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
      | flow: flow(last_record),
        type: "#{regex.signed_name}",
        text: str
    }
    |> fields_reset(:all, regex)
  end

  # takes the section number of the preceding section
  def table_heading(
        %{country: :UK} = regex,
        "[::table_heading::]" <> str,
        last_record,
        _type
      ) do
    case Regex.run(~r/#{regex.table_heading}/, str) do
      [_, txt, _, region] ->
        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.table_name},#{regex.heading_name}"),
            text: txt,
            region: region
        }
        |> fields_reset(:section, regex)

      [_, txt] ->
        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.table_name},#{regex.heading_name}"),
            text: txt
        }
        |> fields_reset(:section, regex)
    end
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
            amendment: table_num,
            table_counter: table_num,
            sub_section: ""
        }

        # |> IO.inspect()
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
