defmodule LocalAuthority do
  # @url "https://www.local.gov.uk/our-support/guidance-and-resources/communications-support/digital-councils/social-media/go-further/a-z-councils-online"
  @text ~s[lib/legl/data_files/txt/org-name.txt] |> Path.absname()
  # @las_url ~s[lib/legl/data_files/txt/local-authorities-url.txt] |> Path.absname()
  @construction "https://www.theconstructionindex.co.uk/market-data/top-100-construction-companies/2020"
  # @pretty ~s[lib/legl/data_files/html/original_pretty.html] |> Path.absname()

  def getNames do
    with %HTTPoison.Response{
           status_code: 200,
           body: body,
           headers: _headers
         } <-
           HTTPoison.get!(@construction),
         {:ok, html} <- Floki.parse_document(body),
         # File.write(@pretty, Floki.raw_html(html, pretty: true)),

         # :ok <- process(html),
         :ok <-
           website(html) do
      IO.puts("Processed source text saved to file")
    else
      %HTTPoison.Error{reason: error} ->
        IO.puts("#{error}")

      {:error, reason} ->
        IO.puts("ERROR saving source text #{reason}")
    end
  end

  def process(html) do
    text = Floki.text(html, sep: "\n")
    File.write(@text, text)
  end

  def website(html) do
    html =
      Floki.traverse_and_update(html, fn
        {"a", [{"href", "/news-search" <> _href}] = attr, children} ->
          concat(children, " ")
          |> IO.inspect()
          |> (&{"a", attr, [~s/>>#{&1}/]}).()

        {"td", [{"class", "text" <> _class}] = attr, children} ->
          concat(children, " ")
          |> IO.inspect()
          |> (&{"td", attr, [~s/>>#{&1}/]}).()

        other ->
          other
      end)
      |> IO.inspect()

    text = Floki.text(html, sep: "\n")
    File.write(@text, text)
  end

  defp concat(children, joiner) do
    Enum.reduce(children, [], fn
      x, acc when is_binary(x) -> [x | acc]
      {_, _, [x]}, acc when is_binary(x) -> [x | acc]
      {_, _, n}, acc when is_list(n) -> concat(n, " ") |> (&[&1 | acc]).()
    end)
    |> Enum.reverse()
    |> Enum.join(joiner)
    |> String.trim(" ")
  end
end
