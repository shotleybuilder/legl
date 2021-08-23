defmodule Legl.Airtable.Schema do
  @moduledoc """

  """

  def component_for_regex(name) when is_atom(name) do
    Types.Component.mapped_components_for_regex() |> Map.get(name)
  end

  # alias __MODULE__

  @doc """
  Creates a tab-delimited binary suitable for copying into Airtable.
  """
  @spec schema(AirtableSchema.t(), String.t(), %{}) :: String.t()
  def schema(fields, binary, regex, opts \\ []) do
    record_type_opts =
      Keyword.get(opts, :records, Types.Component.components_as_list())
      |> Enum.join("|")

    records = records(fields, binary, regex, record_type_opts)

    Enum.count(records) |> IO.inspect(label: "records")

    fields = Keyword.get(opts, :fields, opts)

    Enum.map(records, fn x -> conv_map_to_record_string(x, fields) end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def records(fields, binary, regex, record_types) do
    # First line is always the title
    [head | tail] = String.split(binary, "\n", trim: true)

    fields = Enum.into(Map.from_struct(fields), %{}, fn {k, _} -> {k, ""} end)

    # a _record_ represents a single line/row entry in Airtable
    # and is the rolling history of what's been
    # _records_ is a `t:list/0` of the set of records
    tail
    |> Enum.reduce([title(regex, head, fields)], fn str, acc ->
      last_record = hd(acc)

      case Regex.match?(~r/^\[::(#{record_types})::\]/, str) do
        true ->
          [tag] = Regex.run(~r/^#{Types.Component.components_for_regex_or()}/, str)

          case Regex.run(~r/^\[::([a-z_]+)::\]$/, tag) do
            [_m, tag] ->
              this_record = apply(__MODULE__, String.to_atom(tag), [regex, str, last_record])

              [this_record | acc]

            nil ->
              IO.inspect(tag, label: "error")
          end

        _ ->
          acc
      end
    end)
  end

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

  def title(regex, "[::title::]" <> str, last_record) do
    %{
      last_record
      | flow: "pre",
        type: regex.title_name,
        text: str
    }
  end

  def part(regex, "[::part::]" <> str, last_record, type \\ :regulation) do
    # str = String.replace(str, part_emoji(), "")

    article_type =
      case last_record.flow do
        "post" -> "#{regex.annex_name}, #{regex.part_name}"
        _ -> regex.part_name
      end

    record =
      case Regex.run(~r/#{regex.part}/, str) do
        [_, value, part, i, str] ->
          case type do
            :act ->
              %{
                last_record
                | flow: "",
                  type: article_type,
                  part: value,
                  text: ~s/#{part} #{i} #{str}/
              }

            :regulation ->
              %{
                last_record
                | flow: "",
                  type: article_type,
                  section: value,
                  text: part <> str
              }
          end

        [_, value, str] ->
          %{
            last_record
            | flow: "",
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
  def chapter(regex, "[::chapter::]" <> str, last_record) do
    record =
      case Regex.run(~r/#{regex.chapter}/m, str) do
        [_, chap_num, txt] ->
          %{
            last_record
            | flow: "",
              type: regex.chapter_name,
              chapter: chap_num,
              text: txt
          }

        [_, chap_num] ->
          %{
            last_record
            | flow: "",
              type: regex.chapter_name,
              chapter: chap_num,
              text: str
          }

        chap_num ->
          %{
            last_record
            | flow: "",
              type: regex.chapter_name,
              chapter: chap_num,
              text: str
          }
      end

    fields_reset(record, :chapter, regex)
  end

  def section(regex, "[::section::]" <> str, last_record) do
    record =
      case Regex.run(~r/#{regex.section}/m, str) do
        [_, section_number, text] ->
          %{
            last_record
            | flow: "",
              type: regex.section_name,
              section: section_number,
              text: text
          }

        [_, text] ->
          %{
            last_record
            | type: regex.section_name,
              section: increment(last_record.section),
              text: text
          }

        value ->
          value
      end

    fields_reset(record, :section, regex)
  end

  def sub_section(regex, "[::sub_section::]" <> str, last_record) do
    record =
      case Regex.run(~r/#{regex.sub_section}/m, str) do
        [_, n, t] ->
          %{
            last_record
            | flow: "",
              type: regex.sub_section_name,
              sub_section: n,
              text: t
          }
      end

    fields_reset(record, :sub_section, regex)
  end

  def heading(regex, "[::heading::]" <> str, last_record) do
    {value, str} =
      case Regex.run(~r/#{regex.heading}/, str) do
        [_, value, str] ->
          {value, str}

        nil ->
          IO.inspect(str)
          {"NaN", str}
      end

    %{
      last_record
      | flow: "",
        type: "#{regex.heading_name}",
        article: value,
        text: str
    }
    |> fields_reset(:article, regex)
  end

  @doc """
  ## Regex

  To return the article number in the 1st capture group
  To return the sub-article number in the 2nd capture group

  * FIN `^(\d+)`
  * UK `^(\d+)\.(#{<<226, 128, 148>>}|\-)\((\d+)\)`
  * AUT `^§[ ](\d+)`
  """
  def article(regex, "[::article::]" <> str, last_record) do
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
        %{last_record | flow: "", type: regex.article_name, article: value, text: str}
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
  def sub_article(regex, "[::sub_article::]" <> str, last_record) do
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

  def para(regex, "[::para::]" <> str, last_record) do
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

  def sub(regex, "[::sub::]" <> str, last_record) do
    [_, _article, _para, sub, txt] = Regex.run(~r/#{regex.sub}/, str)

    %{last_record | type: regex.sub_name, sub: sub, text: txt}
  end

  @doc """
  Creates an annex record

  Regex:
  * UK `^SCHEDULE[ ](\d+)`
  * AUT `^Anlage[ ](\d+)`

  """
  def annex(regex, "[::annex::]" <> str, last_record) do
    [_, annex_num, annex] = Regex.run(~r/#{regex.annex}/, str)
    annex_num = if annex_num != "", do: annex_num, else: "post"

    %{
      last_record
      | type: regex.annex_name,
        text: annex,
        flow: annex_num
    }
    |> fields_reset(:all, regex)
  end

  def form(regex, "[::form::]" <> str, last_record) do
    [_, form_num, form] = Regex.run(~r/#{regex.form}/, str)

    %{
      last_record
      | type: regex.form_name,
        part: form_num,
        text: form
    }
    |> fields_reset(:part, regex)
  end

  def amendment(regex, "[::amendment::]" <> str, last_record) do
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

      [_, str] ->
        %{
          last_record
          | type: "#{regex.amendment_name}",
            text: str
        }
    end
  end

  def approval(regex, "[::approval::]" <> str, last_record) do
    %{
      last_record
      | flow: "pre",
        type: "#{regex.approval_name}",
        text: str
    }
    |> fields_reset(:all, regex)
  end

  def table(regex, "[::table::]" <> str, last_record) do
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

  def note(regex, "[::note::]" <> str, last_record) do
    [_, note] = Regex.run(~r/#{regex.note}/, str)

    %{
      last_record
      | type: regex.note_name,
        text: note,
        flow: "post"
    }
    |> fields_reset(:all, regex)
  end

  def footnote(regex, "[::footnote::]" <> str, last_record) do
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

  def fields_reset(record, :all, %{number_fields: fields} = regex) do
    Enum.reduce(fields, record, fn x, acc -> Map.replace(acc, x, "") end)
  end

  def fields_reset(record, field, %{number_fields: fields} = regex) do
    index = Enum.find_index(fields, fn x -> x == field end) |> (&Kernel.+(&1, 1)).()
    {_, fields} = Enum.split(fields, index)
    Enum.reduce(fields, record, fn x, acc -> Map.replace(acc, x, "") end)
  end

  def increment(""), do: "1"

  def increment(" "), do: "1"

  def increment(value) do
    String.to_integer(value)
    |> (&Kernel.+(&1, 1)).()
    |> Integer.to_string()
  end
end
