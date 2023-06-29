defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib do
  @moduledoc """
  Functions to create a list of dutyholder tags for a piece of text

  """
  def workflow(""), do: []

  def workflow(text) when is_binary(text) do
    {_, classes} =
      {text, []}
      |> pre_process(blacklist())
      |> process(government())
      |> process(business())
      |> process(person())
      |> process(public())
      |> process(specialist())
      |> process(cdm())
      |> process(supply_chain())
      |> process(servicer())
      |> process(environmentalist())

    classes
    |> Enum.filter(fn x -> x != "Nil" end)
    |> Enum.reverse()

    # if classes == [],
    #  do: [""],
    #  else:
    #    classes
    #    |> Enum.reverse()
  end

  def workflow(text, library) do
    library = library_picker(library)
    {_, classes} = process({text, []}, library)

    classes
    |> Enum.filter(fn x -> x != "Nil" end)
    |> Enum.reverse()
  end

  def print_list_to_console() do
    classes =
      business() ++
        person() ++
        public() ++
        specialist() ++
        government() ++ cdm() ++ supply_chain() ++ servicer() ++ environmentalist()

    Enum.map(classes, fn {class, _} -> Atom.to_string(class) end)
    |> Enum.each(fn x -> IO.puts(x) end)
  end

  @doc """
  Function returns the given library as a single regex OR group string Eg "(?:[
  “][Oo]rganisations?[ \\.,:;”]|[ “][Ee]nterprises?[ \\.,:;”]|[
  “][Bb]usinesse?s?[ \\.,:;”]|[ “][Cc]ompany?i?e?s?[ \\.,:;”]|[ “][Ee]mployers[
  \\.,:;”]|[ “][Pp]erson who is in occupation[ \\.,:;”]|[ “][Oo]ccupiers?[
  \\.,:;”]|[ “][Ll]essee[ \\.,:;”]|[ “][Oo]wner[ \\.,:;”]|[ “][Ii]nvestors[
  \\.,:;”])"
  """
  def dutyholders_list(library) do
    library_picker(library)
    |> Enum.reduce([], fn
      {_k, v}, acc when is_binary(v) ->
        ["[ “]#{v}[ \\.,:;”]" | acc]

      {_k, v}, acc when is_list(v) ->
        Enum.reduce(v, [], fn x, accum ->
          ["[ “]#{x}[ \\.,:;”]" | accum]
        end)
        |> Enum.join("|")
        |> (&[&1 | acc]).()
    end)
    |> Enum.join("|")
    |> (fn x -> ~s/(?:#{x})/ end).()
  end

  def library_picker(lib) do
    %{person: person(), business: business(), government: government()}
    |> Map.get(lib)
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
        [{"[ “]#{v}[ \\.,:;”]", Atom.to_string(k) |> Legl.Utility.upcaseFirst()} | acc]

      {k, v}, acc when is_list(v) ->
        Enum.reduce(v, [], fn x, accum ->
          ["[ “]#{x}[ \\.,:;”]" | accum]
        end)
        |> Enum.join("|")
        |> (fn x -> ~s/(?:#{x})/ end).()
        |> (&{&1, Atom.to_string(k) |> Legl.Utility.upcaseFirst()}).()
        |> (&[&1 | acc]).()
    end)
    |> Enum.reverse()
  end

  defp process(collector, library) do
    library = process_library(library)

    Enum.reduce(library, collector, fn {regex, class}, {text, classes} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          # A specific term (approved person) should be removed from the text to
          # avoid matching on 'person'
          {Regex.replace(~r/#{regex}/m, text, ""), [class | classes]}

        false ->
          acc
      end
    end)
  end

  defp pre_process({text, collector}, blacklist) do
    Enum.reduce(blacklist, text, fn regex, acc ->
      Regex.replace(~r/#{regex}/, acc, "")
    end)
    |> (&{&1, collector}).()
  end

  defp blacklist() do
    [
      "local authority collected municipal waste"
    ]
  end

  defp business() do
    [
      "Org: Investor": "[Ii]nvestors",
      "Org: Owner": "[Oo]wner",
      "Org: Lessee": "[Ll]essee",
      "Org: Occupier": ["[Oo]ccupiers?", "[Pp]erson who is in occupation"],
      "Org: Employer": "[Ee]mployers",
      "Org: Company": [
        "[Cc]ompany?i?e?s?",
        "[Bb]usinesse?s?",
        "[Ee]nterprises?",
        "[Bb]ody?i?e?s? corporate"
      ],
      Organisation: "[Oo]rganisations?"
    ]
  end

  defp person() do
    [
      "Ind: Employee": "[Ee]mployees?",
      "Ind: Worker": "[Ww]orkers?",
      "Ind: Responsible Person": "[Rr]esponsible [Pp]ersons?",
      "Ind: Competent Person": "[Cc]ompetent [Pp]ersons?",
      "Ind: Authorised Person": ["[Aa]uthorised [Pp]erson", "[Aa]uthorised [Bb]ody"],
      "Ind: Appointed Person": "[Aa]ppointed [Pp]ersons?",
      "Ind: Relevant Person": "[Rr]elevant [Pp]erson",
      "Ind: Operator": ["[Oo]perators?", "[Pp]erson who operates the plant"],
      "Ind: Person": ["[Pp]erson", "site manager"],
      "Ind: Duty Holder": "[Dd]uty [Hh]olders?",
      "Ind: Holder": "[Hh]olders?",
      "Ind: User": "[Uu]sers?",
      "Ind: Licensee": ["[Ll]icensee", "[Aa]pplicant"],
      "SC: Dealer": "(?:[Ss]crap metal )?[Dd]ealer"
    ]
  end

  defp public() do
    [
      nil: "[Pp]ublic (?:nature|sewer|importance|functions?|interest|[Ss]ervices)",
      Public: ["[Pp]ublic", "[Ee]veryone", "[Cc]itizens?"]
    ]
  end

  defp specialist() do
    [
      "Spc: Advisor": "[Aa]dvis[oe]r",
      "Spc: OH Advisor": ["[Nn]urse", "[Pp]hysician", "[Dd]octor"],
      nil: "[Rr]epresentatives? of",
      "Spc: Representative": "[Rr]epresentatives?",
      "Spc: Trade Union": "[Tt]rade [Uu]nions?",
      "Spc: Assessor": "[Aa]ssessors?",
      "Spc: Inspector": "[Ii]nspectors?"
    ]
  end

  defp government() do
    authority =
      [
        "[Pp]ublic",
        "[Ll]ocal",
        "[Ww]aste disposal",
        "[Ww]aste collection",
        "monitoring"
      ]
      |> Enum.join("|")

    [
      "Gvt: Minister": [
        "Secretary of State",
        "[Mm]iniste?ry?s?",
        "National Assembly for Wales",
        "Assembly"
      ],
      "Gvt: Agency": [
        "Environment Agency",
        "SEPA",
        "Scottish Environment Protection Agency",
        "Office for Environmental Protection",
        "OEP",
        "Natural Resources Body for Wales",
        "Department of the Environment",
        "[Tt]he Department",
        "[Aa]gency"
      ],
      "Gvt: Officer": ["[Aa]uthorised [Oo]fficer", "[Oo]fficer of a local authority"],
      "Gvt: Authority": [
        "(?:[Rr]egulati?on?r?y?|[Ee]nforce?(?:ment|ing)) [Aa]uthority?i?e?s?",
        "(?:[Tt]he|[Aa]n|appropriate|allocating) authority",
        "[Rr]egulators?",
        "(?:#{authority}) [Aa]uthority?i?e?s?"
      ],
      "Gvt: Appropriate Person": "[Aa]ppropriate [Pp]ersons?",
      Judiciary: ["court", "justice of the peace"]
    ]
  end

  defp cdm() do
    [
      "CDM: Principal Designer": "[Pp]rincipal [Dd]esigner",
      "CDM: Designer": "[Dd]esigner",
      "CDM: Constructor": "[Cc]onstructor",
      "CDM: Principal Contractor": "[Pp]rincipal [Cc]ontractor",
      "CDM: Contractor": "[Cc]ontractor"
    ]
  end

  defp supply_chain() do
    [
      "SC: Agent": "[Aa]gent?s",
      "SC: Keeper": "person who.*?keeps*?",
      "SC: Manufacturer": "[Mm]anufacturer",
      "SC: Producer": ["[Pp]roducer", "person who.*?produces*?"],
      "SC: Marketer": ["[Aa]dvertiser", "[Mm]arketer"],
      "SC: Supplier": "[Ss]upplier",
      "SC: Distributor": "[Dd]istributor",
      "SC: Seller": "[Ss]eller",
      "SC: Retailer": "[Rr]etailer",
      "SC: Storer": "[Ss]torer",
      "SC: Consignor": "[Cc]onsignor",
      "SC: Handler": "[Hh]andler",
      "SC: Consignee": "[Cc]onsignee",
      "SC: Carrier": ["[Tt]ransporter", "person who.*?carries"],
      "SC: Driver": "[Dd]river",
      "SC: Importer": ["[Ii]mporter", "person who.*?imports*?"],
      "SC: Exporter": ["[Ee]xporter", "person who.*?exports*?"]
    ]
  end

  defp servicer() do
    [
      "Svc: Installer": "[Ii]nstaller",
      "Svc: Maintainer": "[Mm]aintainer",
      "Svc: Repairer": "[Rr]epairer"
    ]
  end

  defp environmentalist() do
    [
      "Env: Reuser": "[Rr]euser",
      "Env: Treater": " person who.*?treats*?",
      "Env: Recycler": "[Rr]ecycler",
      "Env: Disposer": "[Dd]isposer",
      "Env: Polluter": "[Pp]olluter"
    ]
  end
end
