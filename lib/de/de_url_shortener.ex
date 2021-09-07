defmodule DE_URL_Shortener do
  def run do
    with binary <- Legl.txt("dguv") |> Path.absname() |> File.read!(),
         results <- url_shorten(binary) do
      save_to_file(results)
    end
  end

  def url_shorten(binary) do
    String.split(binary, "\n")
    |> Enum.reduce([], fn str, acc ->
      case str do
        "" ->
          acc

        _ ->
          case Regex.run(
                 ~r/https:\/\/publikationen.dguv.de\/regelwerk\/dguv-informationen\/\d+\/(.*)$/,
                 str
               ) do
            [_, g1] ->
              l = String.length(g1)
              IO.puts("#{l} >>> #{g1}")
              [l | acc]

            _ ->
              [nil | acc]
          end
      end
    end)
    |> Enum.reverse()
    |> IO.inspect(charlists: :as_lists, limit: :infinity)
  end

  def save_to_file(results) do
    Legl.txt("url_short")
    |> Path.absname()
    |> File.write(results)
  end
end
