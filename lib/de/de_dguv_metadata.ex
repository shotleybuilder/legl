defmodule DE_DGUV_Metadata do
  def run(opts) do
    with binary <- Legl.txt("urls") |> Path.absname() |> File.read!(),
         result <- metadata(binary, opts) do
      save_to_file(result)
    end
  end

  def metadata(binary, opts) do
    status = Keyword.get(opts, :status, true)
    subjects = Keyword.get(opts, :subjects, false)
    date = Keyword.get(opts, :date, false)
    limit = Keyword.get(opts, :limit, :all)

    urls = String.split(binary, "\n")
    limit = if limit == :all, do: Enum.count(urls), else: limit

    Enum.reduce_while(urls, %{limit: 1, acc: []}, fn url, acc ->
      result =
        case url do
          "" ->
            cond do
              status and subjects and date ->
                "\t\t\t\t\n"

              status and (subjects or date) ->
                "\t\t\n"

              date and subjects ->
                "\t\t\t\n"

              date or subjects ->
                "\t\n"

              status ->
                "\n"
            end

          _ ->
            {:ok, env} = Tesla.get(url)

            case env.status do
              x when x in [301, 404] ->
                cond do
                  status and subjects and date ->
                    "Broken\t\t\t\t\n"

                  status and (subjects or date) ->
                    "Broken\t\t\n"

                  date and subjects ->
                    "\t\t\t\n"

                  date or subjects ->
                    "\t\n"

                  status ->
                    "Broken\n"
                end

              200 ->
                ausgabedatum =
                  case Regex.run(
                         ~r/<strong[ ]class="entry--label">\nAusgabedatum.*\n<\/strong>\n<span[ ]class="entry--content">\n(\d{4})\.(\d{2})\n<\/span>/,
                         env.body
                       ) do
                    [_, g1, g2] ->
                      {g1, g2}

                    _ ->
                      IO.puts("No Date: #{url}")
                      {"", ""}
                  end

                fachbereich =
                  case Regex.run(
                         ~r/<a.*?title="Fachbereich.*?"[ ]target="_blank"[ ]rel="nofollow[ ]noopener">(.*?)<\/a>/,
                         env.body
                       ) do
                    [_, g1] ->
                      replace(g1)

                    _ ->
                      IO.puts("ERROR: fachbereich #{url}")
                      "n/a"
                  end

                sachgebiet =
                  case Regex.run(
                         ~r/<a.*?title="Sachgebiet.*?"[ ]target="_blank"[ ]rel="nofollow[ ]noopener">(.*?)<\/a>/,
                         env.body
                       ) do
                    [_, g1] ->
                      replace(g1)

                    _ ->
                      IO.puts("ERROR: sachgebiet #{url}")
                      "n/a"
                  end

                cond do
                  status and subjects and date ->
                    "Working\t#{fachbereich}\t#{sachgebiet}\t#{elem(ausgabedatum, 0)}\t#{elem(ausgabedatum, 1)}\n"

                  status and subjects ->
                    "Working\t#{fachbereich}\t#{sachgebiet}\n"

                  status and date ->
                    "Working\t#{elem(ausgabedatum, 0)}\t#{elem(ausgabedatum, 1)}\n"

                  date and subjects ->
                    "#{elem(ausgabedatum, 0)}\t#{elem(ausgabedatum, 1)}\t#{fachbereich}\t#{sachgebiet}\n"

                  subjects ->
                    "#{fachbereich}\t#{sachgebiet}\n"

                  date ->
                    "#{elem(ausgabedatum, 0)}\t#{elem(ausgabedatum, 1)}\n"

                  status ->
                    "Working\n"
                end
            end
        end

      if acc.limit == limit,
        do: {:halt, [result | acc.acc]},
        else: {:cont, %{limit: acc.limit + 1, acc: [result | acc.acc]}}
    end)
    |> Enum.reverse()
    |> IO.inspect()
  end

  def replace(term) do
    term
    |> String.replace("ä", "ae")
    |> String.replace("ö", "oe")
    |> String.replace("ü", "ue")
    |> String.replace("ß", "ss")
  end

  def save_to_file(results) do
    Legl.txt("dguv_metadata")
    |> Path.absname()
    |> File.write(results)
  end
end
