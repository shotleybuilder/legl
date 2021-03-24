defmodule Legl.Airtable.Schema do
  @moduledoc """

  """

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

  alias __MODULE__

  defstruct flow: "",
            type: "",
            part: "",
            chapter: "",
            subchapter: "",
            article: "",
            para: "",
            sub: 0,
            text: ""

  @typedoc """
  Country code

  * :fin
  * :uk
  """
  @type country_code :: atom

  @doc """
  Creates a tab-delimited binary suitable for copying into Airtable.
  """
  @spec schema(country_code, String.t()) :: String.t()
  def schema(country_code, binary) do
    regex = Map.get(Legl.regex(), country_code)

    # First line is always the title
    [head | tail] = String.split(binary, "\n", trim: true)

    records = [
      %{%Schema{} | type: "title", text: head}
    ]

    # a _record_ represents a single line/row entry in Airtable
    # and is the rolling history of what's been
    # _records_ is a `t:list/0` of the set of records
    records =
      tail
      |> Enum.reduce(records, fn str, acc ->
        last_record = hd(acc)

        this_record =
          cond do
            Regex.match?(~r/^#{article_emoji()}/, str) -> article(regex.article, str, last_record)
            Regex.match?(~r/^#{sub_article_emoji()}/, str) -> sub_article(str, last_record)
            Regex.match?(~r/^#{heading_emoji()}/, str) -> heading(str, last_record)
            Regex.match?(~r/^#{annex_emoji()}/, str) -> annex(str, last_record)
            # Regex.match?(~r/^#{annex_heading_emoji()}/, str) -> annex_heading(str, acc.record)
            Regex.match?(~r/^#{part_emoji()}/, str) -> part(str, last_record)
            Regex.match?(~r/^#{chapter_emoji()}/, str) -> chapter(regex.chapter, str, last_record)
            true -> sub(str, last_record)
          end

        [this_record | acc]
      end)

    Enum.count(records) |> IO.inspect(label: "records")

    Enum.map(records, &conv_map_to_record_string/1)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @doc false
  def conv_map_to_record_string(%Schema{
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

  def part(str, last_record, type \\ :regulation) do
    str = String.replace(str, part_emoji(), "")
    [_, value, part, i, str] = Regex.run(~r/^(\d+[ ])(PART|Part)[ ](\d|[A-Z])+[ ](.*)/, str)

    article_type =
      case last_record.flow do
        "post" -> "schedule, part"
        _ -> "part"
      end

    case type do
      :act ->
        %{
          last_record
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
          last_record
          | type: article_type,
            subchapter: value,
            article: "",
            para: "",
            text: part <> str
        }
    end
  end

  @doc """
  A chapter inherits any Part numbering and sets a new Chapter level numbering
  on subsequent articles

  ## Regex

  To return the chapter number in the first capture group

  * FIN `^(\\d+)`
  * UK `^Chapter[ ](\\d+)`
  """
  def chapter(regex, str, last_record) do
    str = String.replace(str, chapter_emoji(), "")

    value =
      case Regex.run(~r/#{regex}/m, str) do
        [_, value] -> value
        value -> value
      end

    %{
      last_record
      | type: "chapter",
        chapter: value,
        subchapter: "",
        article: "",
        para: "",
        text: str
    }
  end

  def heading(str, last_record) do
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
      case last_record.flow do
        "post" -> "schedule, heading"
        _ -> "article, heading"
      end

    %{last_record | type: article_type, article: value, para: "", sub: 0, text: str}
  end

  @doc """
  ## Regex

  To return the article number in the 1st capture group
  To return the sub-article number in the 2nd capture group

  * FIN `^(\d+)`
  * UK `^(\d+)\.(#{<<226, 128, 148>>}|\-)\((\d+)\)`
  """
  def article(regex, str, last_record) do
    str = String.replace(str, article_emoji(), "")

    case Regex.run(~r/#{regex}/, str) do
      nil ->
        case last_record.flow do
          "post" ->
            [_, value] = Regex.run(~r/^(\d+)\./, str)
            %{last_record | type: "annex, article", para: value, text: str}

          _ ->
            %{last_record | type: "article", para: " ", text: str}
        end

      [_, value] ->
        %{last_record | type: "article", article: value, para: "", text: str}

      [_, article, _, para] ->
        %{last_record | type: "article, sub-article", article: article, para: para, text: str}
    end
  end

  @doc """

  """
  def sub_article(str, last_record) do
    str = String.replace(str, sub_article_emoji(), "")
    [_, value] = Regex.run(~r/^\((\d+)\)/, str)
    %{last_record | type: "sub-article", para: value, text: str}
  end

  def sub(str, last_record) do
    rest =
      case Regex.match?(~r/^#{numbered_para_emoji()}/, str) do
        true ->
          <<_::binary-size(3), rest::binary>> = str
          rest

        false ->
          <<_::binary-size(4), rest::binary>> = str
          rest
      end

    %{last_record | type: "para", sub: last_record.sub + 1, text: rest}
  end

  @doc """

  """
  def annex(str, last_record) do
    str = String.replace(str, annex_emoji(), "")

    value =
      case Regex.run(~r/^SCHEDULE[ ](\d+)/, str) do
        [_, value] -> value
        nil -> ""
      end

    %{
      last_record
      | type: "schedule",
        chapter: "s" <> value,
        article: "",
        para: "",
        sub: 0,
        text: str,
        flow: "post"
    }
  end
end
