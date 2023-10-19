defmodule Legl.Services.LegislationGovUk.Parsers.Html do
  @moduledoc """
  Use the Floki library
  https://github.com/philss/floki
  """
  alias Legl.Countries.Uk.UkHelpers, as: UK
  alias Legl.Airtable.AirtableTitleField, as: Title

  def amendment_parser(html) do
    {:ok, document} = Floki.parse_document(html)
    # IO.inspect(document, limit: :infinity)
    case Floki.find(document, "tbody") do
      [] ->
        :no_records

      body ->
        # IO.inspect(body, label: "TBODY: ")
        {:ok, body}
    end
  end

  @doc """
  Function transforms the returned html
  Then calls traverse to return a lst of maps
  [%{Number: "xxxx", Title_EN: title, Year: 1234, md_description: "text", type_code: "uksi"}]
  """
  def new_law_parser(html) do
    {:ok, document} = Floki.parse_document(html)

    content = Floki.find(document, ".p_content")

    content =
      content
      |> List.first()
      |> Floki.children()
      |> List.first()
      |> Floki.children()

    traverse(content)
    |> (&{:ok, &1}).()
  end

  def traverse(content) do
    content
    |> Enum.reduce([], fn
      {"h6", _, [{"a", [{"href", path}], title}, _, _]}, acc ->
        make_map(path, title, acc)

      {"h6", _, [{"a", [{"href", path}], title}]}, acc ->
        make_map(path, title, acc)

      {"p", _, description}, acc ->
        description =
          case description do
            [] ->
              ""

            _ ->
              description
              |> Enum.join(" ")
              |> String.trim()
              |> String.replace("\t", "")
              |> String.replace("\n", " ")
          end

        {v, acc} = List.pop_at(acc, 0)

        Map.put(v, :md_description, description)
        |> (&[&1 | acc]).()

      {"h4", _, _}, acc ->
        acc

      {"h5", _, _}, acc ->
        acc

      no_match, acc ->
        IO.puts("ERROR! No match with #{inspect(no_match)}")
        acc
    end)
  end

  defp make_map(path, title, acc) do
    with {:ok, type_code, year, number} <- UK.split_path(path),
         title =
           title
           |> Enum.join(" ")
           |> UK.split_title()
           |> Title.title_clean() do
      [
        %{
          Title_EN: title,
          type_code: type_code,
          Year: String.to_integer(year),
          Number: number
        }
        | acc
      ]
    end
  end

  def traverse_and_update(content) do
    IO.inspect(content, limit: :infinity)

    Floki.traverse_and_update(content, [], fn
      {"a", [{"href", path}] = attr, children}, acc ->
        children = Enum.join(children, " ")

        with {:ok, type_code, year, number} <- UK.split_path(path),
             title = UK.split_title(children) |> Title.title_clean() do
          [
            %{
              Title_EN: title,
              type_code: type_code,
              Year: String.to_integer(year),
              Number: number
            }
            | acc
          ]
          |> (&{{"a", attr, children}, &1}).()
        end

      {"p", attr, children}, acc ->
        children
        |> Enum.join(" ")
        |> String.trim()
        |> String.replace("\t", "")
        |> String.replace("\n", " ")
        |> (&[&1 | acc]).()
        |> (&{{"p", attr, children}, &1}).()

      tag, acc ->
        {tag, acc}
    end)
    |> elem(1)
  end
end
