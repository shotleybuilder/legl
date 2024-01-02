defmodule Legl.Countries.Uk.Article.Taxa.Actor.ActorLib do
  @moduledoc """
  Functions to create a list of dutyholder tags for a piece of text

  """

  alias ActorDefinitions

  @dutyholder_library ActorDefinitions.dutyholder_library()
  @government ActorDefinitions.government()
  @governed ActorDefinitions.governed()

  @type actor :: atom()
  @type regex :: binary()
  @type library() :: keyword({actor(), regex()})

  def print_dutyholders_to_console() do
    classes = @dutyholder_library

    Enum.map(classes, fn {class, _} -> Atom.to_string(class) end)
    |> Enum.each(fn x -> IO.puts(x) end)
  end

  @spec workflow(binary()) :: []
  def workflow(""), do: []

  @spec workflow(binary(), :actor) :: list()
  def workflow(text, :actor) do
    {text, []}
    |> blacklister()
    |> process(@dutyholder_library, true)
    |> elem(1)
    |> Enum.reverse()
  end

  @spec workflow(binary(), list()) :: list()
  def workflow(text, library) when is_list(library) do
    {text, []}
    |> process(library, true)
    |> elem(1)
    |> Enum.sort()
  end

  defp blacklister({text, collector}) do
    Enum.reduce(ActorDefinitions.blacklist(), text, fn regex, acc ->
      Regex.replace(~r/#{regex}/m, acc, "")
    end)
    |> (&{&1, collector}).()
  end

  @spec process({binary(), []}, library(), boolean()) :: {binary(), list()}
  def process(collector, library, rm?) do
    # library = process_library(library)

    Enum.reduce(library, collector, fn {actor, regex}, {text, actors} = acc ->
      regex_c =
        case Regex.compile(regex, "m") do
          {:ok, regex} ->
            # IO.puts(~s/#{inspect(regex)}/)
            regex

          {:error, error} ->
            IO.puts(~s/ERROR: Duty Actor Regex doesn't compile\n#{error}\n#{regex}/)
        end

      case Regex.run(regex_c, text) do
        [_match] ->
          actor = Atom.to_string(actor)

          text = if rm?, do: Regex.replace(regex_c, text, ""), else: text

          {text, [actor | actors]}

        nil ->
          acc

        match ->
          IO.puts(
            "ERROR:\nText:\n#{text}\nRegex:\n#{regex}\nMATCH:\n#{inspect(match)}\n[#{__MODULE__}.process_dutyholder/3]"
          )
      end
    end)
  end

  @doc """
  Function builds a custom library using a list of Duty Actors
  This library is used for Duty Type and Dutyholder tagging
  """
  @spec custom_actor_library(list(), keyword()) :: keyword({actor(), regex()})
  def custom_actor_library(actors, library) when is_list(actors) do
    library =
      cond do
        library == :government -> @government
        library == :governed -> @governed
        true -> @dutyholder_library
      end

    actors = Enum.map(actors, &String.to_atom/1)

    Enum.reduce(actors, [], fn actor, acc ->
      case Keyword.has_key?(library, actor) do
        true ->
          [{actor, Keyword.get(library, actor)} | acc]

        false ->
          IO.puts(~s/ERROR: #{actor} not found in library\n#{inspect(library)}/)
          acc
      end
    end)
  end

  @doc """
  Function returns the given library as a single regex OR group string Eg "(?:[
  “][Oo]rganisations?[ \\.,:;”]|[ “][Ee]nterprises?[ \\.,:;”]|[
  “][Bb]usinesse?s?[ \\.,:;”]|[ “][Cc]ompany?i?e?s?[ \\.,:;”]|[ “][Ee]mployers[
  \\.,:;”]|[ “][Pp]erson who is in occupation[ \\.,:;”]|[ “][Oo]ccupiers?[
  \\.,:;”]|[ “][Ll]essee[ \\.,:;”]|[ “][Oo]wner[ \\.,:;”]|[ “][Ii]nvestors[
  \\.,:;”])"
  """
  def dutyholders_regex(library) do
    library
    |> Enum.reduce([], fn
      {k, v}, acc when is_binary(v) ->
        "[ “]#{v}[ \\.,:;”\\]]"
        |> (fn x -> ~s/(?:#{x})/ end).()
        |> (&[{k, {v, &1}} | acc]).()

      {k, v}, acc when is_list(v) ->
        Enum.reduce(v, [], fn x, accum ->
          ["[ “]#{x}[ \\.,:;”\\]]" | accum]
        end)
        |> Enum.join("|")
        |> (fn x -> ~s/(?:#{x})/ end).()
        |> (&[{k, {v, &1}} | acc]).()
    end)
  end
end
