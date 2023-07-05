defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib do
  @moduledoc """
  Functions to create a list of dutyholder tags for a piece of text

  """

  import DutyholderDefinitions

  @dutyholder_library dutyholder_library()
  @government government()
  @governed governed()

  def print_dutyholders_to_console() do
    classes = @dutyholder_library

    Enum.map(classes, fn {class, _} -> Atom.to_string(class) end)
    |> Enum.each(fn x -> IO.puts(x) end)
  end

  def workflow(""), do: []

  def workflow(text, :actor) do
    {_, classes} =
      {text, []}
      |> blacklister(blacklist())
      |> process(@dutyholder_library, true)

    classes
    |> Enum.reverse()
  end

  def workflow(text, library) when is_list(library) do
    {text, []}
    |> process(library, true)
    |> elem(1)
    |> Enum.reverse()
  end

  defp blacklister({text, collector}, blacklist) do
    Enum.reduce(blacklist, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/m, acc, "")
    end)
    |> (&{&1, collector}).()
  end

  defp process(collector, library, rm?) do
    library = process_library(library)

    Enum.reduce(library, collector, fn {regex, class}, {text, classes} = acc ->
      # if class == "Gvt: Authority", do: IO.puts("#{regex}")

      case Regex.match?(~r/#{regex}/, text) do
        true ->
          case rm? do
            true ->
              {Regex.replace(~r/#{regex}/m, text, ""), [class | classes]}

            false ->
              {text, [class | classes]}
          end

        false ->
          acc
      end
    end)
  end

  def custom_dutyholders(actors, library) do
    lib = custom_dutyholder_library(actors, library)
    {dutyholders_regex(lib), lib}
  end

  @doc """
  Function builds a custom library based on the results of the Duty Actor tagging
  This library is used for Duty Type and Dutyholder tagging
  """
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
      {_k, v}, acc when is_binary(v) ->
        ["[ “]#{v}[ \\.,:;”\\]]" | acc]

      {_k, v}, acc when is_list(v) ->
        Enum.reduce(v, [], fn x, accum ->
          ["[ “]#{x}[ \\.,:;”\\]]" | accum]
        end)
        |> Enum.join("|")
        |> (&[&1 | acc]).()
    end)
    |> Enum.join("|")
    |> (fn x -> ~s/(?:#{x})/ end).()
  end

  @doc """
  Function pre-process a library to the correct shape to be consumed by
  process/2 eg [ {"[ “][Ii]nvestors[ \\.,:;”]", "Investor"}, {"[ “][Oo]wner[
  \\.,:;”]", "Owner"}, {"[ “][Ll]essee[ \\.,:;”]", "Lessee"}, {"(?:[ “][Pp]erson
  who is in occupation[ \\.,:;”]|[ “][Oo]ccupiers?[ \\.,:;”])", "Occupier"}, {"[
  “][Ee]mployers[ \\.,:;”]", "Employer"}, {"(?:[ “][Ee]nterprises?[ \\.,:;”]|[
  “][Bb]usinesse?s?[ \\.,:;”]|[ “][Cc]ompany?i?e?s?[ \\.,:;”])", "Company"}, {"[
  “][Oo]rganisations?[ \\.,:;”]", "Organisation"}]
  """

  def process_library(library) do
    library
    |> Enum.reduce([], fn
      {k, v}, acc when is_binary(v) ->
        [{"[ “]#{v}[ \\.,:;”\\]]", Atom.to_string(k) |> Legl.Utility.upcaseFirst()} | acc]

      {k, v}, acc when is_list(v) ->
        Enum.reduce(v, [], fn x, accum ->
          ["[ “]#{x}[ \\.,:;”\\]]" | accum]
        end)
        |> Enum.join("|")
        |> (fn x -> ~s/(?:#{x})/ end).()
        |> (&{&1, Atom.to_string(k) |> Legl.Utility.upcaseFirst()}).()
        |> (&[&1 | acc]).()
    end)
    |> Enum.reverse()
  end
end
