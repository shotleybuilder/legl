defmodule UK.Schema do
  @moduledoc false

  # Schema defines a struct to hold the data that is tranlsated into a .txt file and ultimately copied and pasted into Airtable.
  # :TODO make this universal to all countries and not just implemented in UK

  import Legl,
    only: [
      part_emoji: 0,
      chapter_emoji: 0,
      # sub_chapter_emoji: 0,
      heading_emoji: 0,
      # annex_heading_emoji: 0,
      article_emoji: 0,
      sub_article_emoji: 0,
      numbered_para_emoji: 0,
      annex_emoji: 0
      # signed_emoji: 0,
      # pushpin_emoji: 0,
      # amendment_emoji: 0
    ]

  defstruct flow: "",
            type: "",
            # c also used for schedules with the "s" prefix
            part: "",
            chapter: "",
            # sc also used for schedule part
            subchapter: "",
            article: "",
            para: "",
            sub: 0,
            text: ""

  def schemas(type, binary, fields) when is_binary(binary) do
    # First line is always the title
    [head | tail] = String.split(binary, "\n", trim: true)
    schema = %UK.Schema{}
    txts = [%{schema | type: "title", text: head}]

    # txts = [~s(\ttitle\t\t\t\t\t\t#{head})]

    schemas =
      tail
      |> Enum.reduce(%{txts: txts, record: schema}, fn str, acc ->
        record =
          cond do
            Regex.match?(~r/^#{article_emoji()}/, str) -> article(type, str, acc.record)
            Regex.match?(~r/^#{sub_article_emoji()}/, str) -> sub_article(type, str, acc.record)
            Regex.match?(~r/^#{heading_emoji()}/, str) -> heading(type, str, acc.record)
            Regex.match?(~r/^#{annex_emoji()}/, str) -> annex(str, acc.record)
            # Regex.match?(~r/^#{annex_heading_emoji()}/, str) -> annex_heading(str, acc.record)
            Regex.match?(~r/^#{part_emoji()}/, str) -> part(type, str, acc.record)
            Regex.match?(~r/^#{chapter_emoji()}/, str) -> chapter(type, str, acc.record)
            true -> sub(str, acc.record)
          end

        %{acc | txts: [record | acc.txts], record: record}
      end)

    Enum.count(schemas.txts) |> IO.inspect(label: "txts")

    case fields do
      [] -> Enum.map(schemas.txts, &conv_map_to_record_string/1)
      _ -> limit_fields(schemas.txts, fields)
    end
    |> Enum.reverse()
    |> Enum.join("\n")
    |> (&File.write(Legl.txts(), &1)).()
  end

  defp limit_fields(records, fields) when fields != [] do
    Enum.reduce(records, [], fn record, acc ->
      str =
        Enum.reduce(fields, "", fn field, str ->
          str <> <<9>> <> Map.get(record, field)
        end)

      [str | acc]
    end)
    |> Enum.map(&String.trim/1)
    |> Enum.reverse()
    |> IO.inspect()
  end

  defp limit_fields(records, _fields), do: records

  defp conv_map_to_record_string(%UK.Schema{
         flow: flow,
         type: type,
         part: part,
         chapter: chapter,
         subchapter: subchapter,
         article: article,
         para: para,
         sub: sub,
         text: text
       }) do
    sub = if sub == 0, do: "", else: sub
    ~s(#{flow}\t#{type}\t#{part}\t#{chapter}\t#{subchapter}\t#{article}\t#{para}\t#{sub}\t#{text})
  end

  @doc """
  Build Airtable record for an article_emoji
  Articles w/o sub-articles have a ref of " "
  """
  def article(:act, str, record) do
    str = String.replace(str, article_emoji(), "")
    [_, _, value] = Regex.run(~r/(\[F\d*[ ])?(\d+)/, str)
    %{record | type: "section", article: value, para: "", text: str}
  end

  def article(:regulation, str, record) do
    str = String.replace(str, article_emoji(), "")

    case Regex.run(~r/^(\d+)\.(#{<<226, 128, 148>>}|\-)\((\d+)\)/, str) do
      nil ->
        case record.flow do
          "post" ->
            [_, value] = Regex.run(~r/^(\d+)\./, str)
            %{record | type: "schedule, article", para: value, text: str}

          _ ->
            %{record | type: "article", para: " ", text: str}
        end

      [_, article, _, para] ->
        %{record | type: "article, sub-article", article: article, para: para, text: str}
    end
  end

  def sub_article(:act, str, record) do
    str = String.replace(str, sub_article_emoji(), "")
    [_, value] = Regex.run(~r/\((\d+)\)/, str)
    %{record | type: "sub-section", para: value, text: str}
  end

  def sub_article(:regulation, str, record) do
    str = String.replace(str, sub_article_emoji(), "")
    [_, value] = Regex.run(~r/^\((\d+)\)/, str)
    %{record | type: "sub-article", para: value, text: str}
  end

  def heading(:act, str, record) do
    str = String.replace(str, heading_emoji(), "")

    %{
      record
      | type: "section, heading",
        subchapter: increment_string(record.subchapter),
        article: "",
        para: "",
        text: str
    }
  end

  def heading(:regulation, str, record) do
    str = String.replace(str, heading_emoji(), "")

    {value, str} =
      case Regex.run(~r/^(\d+)[ ](.*)/, str) do
        [_, value, str] ->
          {value, str}

        nil ->
          IO.inspect(str)
          {"NaN", str}
      end

    article_type =
      case record.flow do
        "post" -> "schedule, heading"
        _ -> "article, heading"
      end

    %{record | type: article_type, article: value, para: "", sub: 0, text: str}
  end

  def annex(str, record) do
    str = String.replace(str, annex_emoji(), "")

    value =
      case Regex.run(~r/^SCHEDULE[ ](\d+)/, str) do
        [_, value] -> value
        nil -> ""
      end

    %{
      record
      | type: "schedule",
        chapter: "s" <> value,
        article: "",
        para: "",
        sub: 0,
        text: str,
        flow: "post"
    }
  end

  def part(type, str, record) do
    str = String.replace(str, part_emoji(), "")
    [_, value, part, i, str] = Regex.run(~r/^(\d+[ ])(PART|Part)[ ](\d|[A-Z])+[ ](.*)/, str)

    article_type =
      case record.flow do
        "post" -> "schedule, part"
        _ -> "part"
      end

    case type do
      :act ->
        %{
          record
          | type: article_type,
            part: value,
            chapter: "",
            subchapter: "",
            article: "",
            para: "",
            text: ~s/#{part} #{i} #{str}/
        }

      :regulation ->
        %{
          record
          | type: article_type,
            subchapter: value,
            article: "",
            para: "",
            text: part <> str
        }
    end
  end

  def chapter(_type, str, record) do
    str = String.replace(str, chapter_emoji(), "")
    [_, value] = Regex.run(~r/^Chapter[ ](\d+)/, str)
    %{record | type: "chapter", chapter: value, subchapter: "", article: "", para: "", text: str}
  end

  def sub(str, record) do
    rest =
      case Regex.match?(~r/^#{numbered_para_emoji()}/, str) do
        true ->
          <<_::binary-size(3), rest::binary>> = str
          rest

        false ->
          <<_::binary-size(4), rest::binary>> = str
          rest
      end

    %{record | type: "para", sub: record.sub + 1, text: rest}
  end

  def increment_string(b) when is_binary(b) do
    case b do
      "" -> "1"
      _ -> String.to_integer(b) |> (&(&1 + 1)).() |> Integer.to_string()
    end
  end
end
