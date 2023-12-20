defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib do
  @moduledoc """
  Functions to create a list of dutyholder tags for a piece of text

  """

  import DutyholderDefinitions

  @dutyholder_library dutyholder_library()
  @government government()
  @governed governed()

  @type actor :: atom()
  @type regex :: binary()
  @type library :: keyword({actor(), regex()})

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
    |> blacklister(blacklist())
    |> process(@dutyholder_library, true)
    |> elem(1)
    |> Enum.reverse()
  end

  @spec workflow(binary(), :"Duty Actor") :: list()
  def workflow(text, :"Duty Actor") do
    {text, []}
    |> blacklister(blacklist())
    |> process(@governed, true)
    |> elem(1)
    |> Enum.sort()
  end

  @spec workflow(binary(), :"Duty Actor Gvt") :: list()
  def workflow(text, :"Duty Actor Gvt") do
    {text, []}
    |> blacklister(blacklist())
    |> process(@government, true)
    |> elem(1)
    |> Enum.sort()
  end

  @spec workflow(binary(), list()) :: list()
  def workflow(text, library) when is_list(library) do
    {text, []}
    |> process(library, true)
    |> elem(1)
    |> Enum.sort()
  end

  defp blacklister({text, collector}, blacklist) do
    Enum.reduce(blacklist, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/m, acc, "")
    end)
    |> (&{&1, collector}).()
  end

  @spec process({binary(), []}, library(), boolean()) :: {binary(), list()}
  def process(collector, library, rm?) do
    # library = process_library(library)

    Enum.reduce(library, collector, fn {actor, regex}, {text, actors} = acc ->
      # if class == "Gvt: Authority", do: IO.puts("#{regex}")

      case Regex.match?(~r/#{regex}/, text) do
        true ->
          actor = Atom.to_string(actor)

          case rm? do
            true ->
              {Regex.replace(~r/#{regex}/m, text, ""), [actor | actors]}

            false ->
              {text, [actor | actors]}
          end

        false ->
          acc
      end
    end)
  end

  def custom_dutyholders(actors, library) do
    custom_dutyholder_library(actors, library)
    |> dutyholders_regex()
  end

  @doc """
  Function builds a custom library using a list of Duty Actors
  This library is used for Duty Type and Dutyholder tagging
  """
  @spec custom_dutyholder_library(list(), keyword()) :: keyword({actor(), binary()})
  def custom_dutyholder_library(actors, library) when is_list(actors) do
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
