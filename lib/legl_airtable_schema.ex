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
    "paste_text_here",
    "Region"
  ]

  def at_cols(), do: Enum.join(@airtable_columns, ",")

  def open_file(:act) do
    {:ok, csv} = "lib/#{@act_csv}.csv" |> Path.absname() |> File.open([:utf8, :write, :read])
    IO.puts(
      csv,
      at_cols()
    )
    csv
  end
  def open_file(:regulation) do
    {:ok, csv} = "lib/#{@regulation_csv}.csv" |> Path.absname() |> File.open([:utf8, :write, :read])
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
    records: Types.Component.components_as_list()
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
      #|> Enum.reverse()
      |> Enum.reduce([], fn record, acc ->
        #IO.inspect(record)
        record = add_id_and_name_to_record(opts.name, record)
        #copy_to_csv(file, record)
        [record | acc]
      end)

    Enum.each(records, fn record ->
      #IO.inspect(record)
      copy_to_csv(file, record)
    end)

    #Find any dupes
    Enum.reduce(records, [], fn x, acc -> Map.get(x, :id) |> (&([&1 | acc])).() end)
    |> Legl.Utility.duplicate_records()
    |> IO.inspect(label: "Duplicates")

    File.close(file)

    Enum.count(records)
    |> IO.inspect(label: "number of records = ")

    Enum.map(records, fn x -> conv_map_to_record_string(x, opts.fields) end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def records(binary, regex, opts) do

    #Regex OR structure "title|content|part|chapter|section|sub_section..."
    record_types =
      opts.records |> Enum.join("|")

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

      last_record = hd(acc) |> reset_region()

      case Regex.match?(~r/^\[::(#{record_types})::\]/, str) do
        true ->
          [tag] = Regex.run(~r/^#{Types.Component.components_for_regex_or()}/, str)

          case Regex.run(~r/^\[::([a-z_]+)::\]$/, tag) do
            [_m, tag] ->
              this_record = Kernel.apply(__MODULE__, String.to_atom(tag), [regex, str, last_record, opts.type])

              #if tag == "heading" do IO.inspect(this_record) end
              this_record = convert_region_code(this_record)

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
  def conv_map_to_record_string(%_{} = record, opts) do
    Map.from_struct(record)
    |> conv_map_to_record_string(opts)
  end

  def conv_map_to_record_string(%{sub: 0} = record, opts) when is_map(record),
    do: conv_map_to_record_string(%{record | sub: ""}, opts)

  def conv_map_to_record_string(record, opts) when is_map(record) do
    opts
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
  @doc """
   Shape of a .csv record
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
    "paste_text_here"
  """
  def add_id_and_name_to_record(name, record) do
    id =
      make_id(name, record)
      |> amending?(record)
      |> commencing?(record)
    Map.put(record, :id, id)
    |> Map.put(:name, name)
  end

  def copy_to_csv(file,
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
    region: region,
    text: text
  } = _record) do
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
      Legl.Utility.csv_quote_enclosure(text),
      region
    ]
    |> Enum.join(",")
    |> (&(IO.puts(file, &1))).()
  end



  def make_id(name, %{flow: "pre"} = r), do:
    ~s/#{name}#{make_id(r)}/

  def make_id(name, %{flow: ""} = r), do:
    make_id(name, %{r | flow: "main"})

  def make_id(name, %{flow: "main"} = r), do:
    ~s/#{name}_#{make_id(r)}/

  def make_id(name, %{flow: "post"} = _r), do:
    ~s/#{name}-/

  def make_id(name, %{flow: "signed"} = _r), do: name

  def make_id(name, %{flow: flow} = r), do:
  ~s/#{name}-#{flow}_#{make_id(r)}/
  |> String.trim_trailing("_")

  def make_id(r), do:
    ~s/#{r.part}_#{r.chapter}_#{r.heading}_#{r.section}_#{r.sub_section}_#{r.para}/
    |> String.trim_trailing("_")

  def amending?(id, %{type: ~s/"amendment,textual"/} = _record), do: id <> "_at"
  def amending?(id, %{type: ~s/"amendment,extent"/} = _record), do: id <> "_ae"
  def amending?(id, %{type: ~s/"amendment,modification"/} = _record), do: id <> "_am"
  def amending?(id, %{type: ~s/"amendment/ <> _type} = record) do
    IO.puts("#{record.type}")
    id
  end
  def amending?(id, _), do: id

  def commencing?(id, %{type: "commencement"} = _record), do: id <> "_c"
  def commencing?(id, _), do: id

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
                  section: value,
                  text: text
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

  def heading(regex, "[::heading::]" <> str, last_record, type \\ :regulation) do
      case Regex.run(~r/#{regex.heading}/, str) do
        [_, value, text, region] ->
          case type do
            :act ->
              %{
                last_record
                | flow: flow(last_record),
                  type: "#{regex.heading_name}",
                  heading: value,
                  text: text,
                  region: region
              }
              |> fields_reset(:heading, regex)
            :regulation ->
              %{
                last_record
                | flow: flow(last_record),
                  type: "#{regex.heading_name}",
                  article: value,
                  text: str
              }
              |> fields_reset(:article, regex)
          end

        [_, value, str] ->
          case type do
            :act ->
              %{
                last_record
                | flow: flow(last_record),
                  type: "#{regex.heading_name}",
                  heading: value,
                  text: str
              }
              |> fields_reset(:heading, regex)
            :regulation ->
              %{
                last_record
                | flow: flow(last_record),
                  type: "#{regex.heading_name}",
                  article: value,
                  text: str
              }
              |> fields_reset(:article, regex)
          end
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
          IO.inspect("#{str}", label: "ERROR: SECTION")

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
      end

    fields_reset(record, :sub_section, regex)
  end

  @doc """
  ## Regex

  To return the article number in the 1st capture group
  To return the sub-article number in the 2nd capture group

  * FIN `^(\d+)`
  * UK `^(\d+)\.(#{<<226, 128, 148>>}|\-)\((\d+)\)`
  * AUT `^§[ ](\d+)`
  """
  def article(regex, "[::article::]" <> str, last_record, _type) do
    case Regex.run(~r/#{regex.article}/, str) do
      nil ->
        case last_record.flow do
          "post" ->
            [_, value] = Regex.run(~r/^(\d+)\./, str)
            %{last_record | type: "annex, #{regex.article_name}", para: value, text: str}

          _ ->
            %{last_record | type: regex.article_name, text: str}
            |> fields_reset(:article, regex)
        end

      [_, value, str] ->
        %{last_record | flow: flow(last_record), type: regex.article_name, article: value, text: str}
        |> fields_reset(:article, regex)

      [_, art, sub, str] ->
        %{
          last_record
          | type: "#{regex.article_name}",
            article: art,
            para: sub,
            text: str
        }

      [_, article, _, para, str] ->
        %{
          last_record
          | type: "#{regex.article_name}",
            article: article,
            para: para,
            text: str
        }
    end
  end

  @doc """

  """
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

        [_, annex_num, annex, region] ->

          annex_num = if annex_num != "", do: annex_num, else: "post"

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

  def amendment(%{country: :UK} = regex,  "[::amendment::]" <> str, last_record, _type) do

    sub_section =
      case last_record.sub_section do
        "" -> "1"
        _ ->
          Map.get(last_record, :sub_section) |> String.to_integer() |> (&(Kernel.+(&1, 1))).() |> Integer.to_string()
      end

    case Regex.run(~r/#{regex.amendment}/, str) do

      [_, amd_code, str] ->
        %{
          last_record
          | type: Legl.Utility.csv_quote_enclosure("#{regex.amendment_name},#{amd_code(amd_code)}"),
            text: amd_code<>str,
            sub_section: sub_section
        }
        |> fields_reset(:sub_section, regex)
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

  def commencement(%{country: :UK} = regex,  "[::commencement::]" <> str, last_record, _type) do
    sub_section =
      case last_record.sub_section do
        "" -> "1"
        _ ->
          Map.get(last_record, :sub_section) |> String.to_integer() |> (&(Kernel.+(&1, 1))).() |> Integer.to_string()
      end

      %{
        last_record
        | type: "#{regex.commencement_name}",
          text: str,
          sub_section: sub_section
      }
      |> fields_reset(:sub_section, regex)

  end

  def amd_code(code) do
    case code do
      "T" -> "textual"
      "M" -> "modification"
      "E" -> "extent"
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

  def table(regex, "[::table::]" <> str, last_record, _type) do
    [_, table_num, table] = Regex.run(~r/#{regex.table}/, str)

    %{
      last_record
      | type: regex.table_name,
        part: table_num,
        text: table,
        flow: "post"
    }
    |> fields_reset(:part, regex)
  end

  def note(regex, "[::note::]" <> str, last_record, _type) do
    [_, note] = Regex.run(~r/#{regex.note}/, str)

    %{
      last_record
      | type: regex.note_name,
        text: note,
        flow: "post"
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

  def fields_reset(record, :all, %{number_fields: fields}) do
    Enum.reduce(fields, record, fn x, acc -> Map.replace(acc, x, "") end)
  end

  def fields_reset(record, field, %{number_fields: fields}) do
    index = Enum.find_index(fields, fn x -> x == field end) |> (&Kernel.+(&1, 1)).()
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

  def convert_region_code(%{region: ""} = record), do: record

  def convert_region_code(%{region: "U.K."} = record) do
    region = Legl.Utility.csv_quote_enclosure("England,Wales,Scotland,Northern Ireland")
    %{record | region: region}
  end

  def convert_region_code(%{region: region} = record) do
    region =
      String.split(region, "+")
      |> Enum.reduce([], fn x, acc ->
        cond do
          x == "E" -> ["England" | acc]
          x == "W" -> ["Wales" | acc]
          x == "N.I." -> ["Nothern Ireland" | acc]
          x == "S" -> ["Scotland" | acc]
          true -> IO.inspect(x, label: true)
        end
      end)
      |> Enum.join(",")
      |> Legl.Utility.csv_quote_enclosure()
    %{record | region: region}
  end
end
