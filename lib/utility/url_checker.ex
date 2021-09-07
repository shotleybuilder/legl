defmodule URL_Check do
  def run(limit \\ :all) do
    with binary <- Legl.txt("urls") |> Path.absname() |> File.read!(),
         result <- url_test(binary, limit) do
      save_to_file(result)
    end
  end

  def url_test(binary, limit) do
    status = %{200 => "Working", 404 => "Broken"}
    today = Date.utc_today()
    today = "#{today.day}/#{today.month}/#{today.year}"

    urls = String.split(binary, "\n")

    case limit do
      :all ->
        Enum.reduce(urls, [], fn str, acc ->
          case str do
            "" ->
              acc

            _ ->
              {:ok, env} = Tesla.get(str)

              result = "#{today}\t#{status[env.status]}\n"
              IO.puts("#{env.url}\t#{result}")
              [result | acc]
          end
        end)
        |> Enum.reverse()

      _ ->
        Enum.reduce_while(urls, %{limit: 0, acc: []}, fn str, acc ->
          {:ok, env} = Tesla.get(str)

          result = "#{today}\t#{status[env.status]}\n"

          if acc.limit < limit,
            do: {:cont, %{limit: acc.limit + 1, acc: [result | acc.acc]}},
            else: {:halt, acc.acc}
        end)
        |> Enum.reverse()
    end
  end

  def save_to_file(results) do
    Legl.txt("url_test_results")
    |> Path.absname()
    |> File.write(results)
  end

  def url_size_of_title do
    binary = Legl.txt("urls") |> Path.absname() |> File.read!()

    String.split(binary, "\n")
    |> Enum.reduce([], fn str, acc ->
      case Regex.run(~r/^\d*\/?(.*)$/, str) do
        [_m, g1] ->
          [String.length(g1) | acc]

        _ ->
          [nil | acc]
      end
    end)
  end
end
