defmodule DutyholderDefinitions do
  @moduledoc """
  Functions to build search Regex expressions
  """

  def dutyholder_library() do
    # Adds the separate dutyholder libraries together into a single keyword list
    government() ++ governed()
  end

  def governed(),
    do:
      business() ++
        person() ++
        public() ++
        specialist() ++
        cdm() ++
        supply_chain() ++
        servicer() ++
        environmentalist()

  # |> process_library()

  def government() do
    authority =
      [
        "[Pp]ublic",
        "[Ll]ocal",
        "[Ww]aste disposal",
        "[Ww]aste collection",
        "[Dd]isposal",
        "monitoring"
      ]
      |> Enum.join("|")

    ([
       "Gvt: Minister": [
         "Secretary of State",
         "[Mm]iniste?ry?s?",
         "National Assembly for Wales",
         "Assembly"
       ],
       "Gvt: Treasury": "[Tt]reasury",
       "Gvt: Commissioners": "[Cc]ommissioners",
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
       "Gvt: Judiciary": ["court", "justice of the peace"],
       "Gvt: Police": "[Cc]onstable"
     ] ++ secretary_of_state())
    |> Enum.sort()

    # |> process_library()
  end

  defp secretary_of_state() do
    [
      "Gvt: Minister: Secretary of State for Defence": "Secretary of State for Defence"
    ]
  end

  def blacklist() do
    [
      "local authority collected municipal waste",
      "[Pp]ublic (?:nature|sewer|importance|functions?|interest|[Ss]ervices)",
      "[Rr]epresentatives? of"
    ]
  end

  defp business() do
    [
      "Org: Investor": "[Ii]nvestors",
      "Org: Owner": "[Oo]wner",
      "Org: Lessee": "[Ll]essee",
      "Org: Occupier": ["[Oo]ccupiers?", "[Pp]erson who is in occupation"],
      "Org: Employer": "[Ee]mployers?",
      "Org: Company": [
        "[Cc]ompany?i?e?s?",
        "[Bb]usinesse?s?",
        "[Ee]nterprises?",
        "[Bb]ody?i?e?s? corporate"
      ],
      "Org: Partnership": [
        "[Pp]artnership",
        "[Uu]nincorporated body?i?e?s?"
      ],
      Organisation: "[Oo]rganisations?"
    ]
  end

  defp person() do
    [
      "Ind: Employee": "[Ee]mployees?",
      "Ind: Worker": "[Ww]orkers?",
      "Ind: Self-employed Worker": "[Ss]elf-employed [Pp]ersons?",
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
    [Public: ["[Pp]ublic", "[Ee]veryone", "[Cc]itizens?"]]
  end

  defp specialist() do
    [
      "Spc: Advisor": "[Aa]dvis[oe]r",
      "Spc: OH Advisor": ["[Nn]urse", "[Pp]hysician", "[Dd]octor"],
      "Spc: Representative": "[Rr]epresentatives?",
      "Spc: Trade Union": "[Tt]rade [Uu]nions?",
      "Spc: Assessor": "[Aa]ssessors?",
      "Spc: Inspector": "[Ii]nspectors?"
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
      "SC: Customer": "[Cc]ustomer",
      "SC: Consumer": "[Cc]onsumer",
      "SC: Storer": "[Ss]torer",
      "SC: Consignor": "[Cc]onsignor",
      "SC: Handler": "[Hh]andler",
      "SC: Consignee": "[Cc]onsignee",
      "SC: Carrier": ["[Tt]ransporter", "person who.*?carries", "[Cc]arriers?"],
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

  @doc """
  Function pre-process a library to the correct shape to be consumed by
  process/2 eg [ {"[ “][Ii]nvestors[ \\.,:;”]", "Investor"}, {"[ “][Oo]wner[
  \\.,:;”]", "Owner"}, {"[ “][Ll]essee[ \\.,:;”]", "Lessee"}, {"(?:[ “][Pp]erson
  who is in occupation[ \\.,:;”]|[ “][Oo]ccupiers?[ \\.,:;”])", "Occupier"}, {"[
  “][Ee]mployers[ \\.,:;”]", "Employer"}, {"(?:[ “][Ee]nterprises?[ \\.,:;”]|[
  “][Bb]usinesse?s?[ \\.,:;”]|[ “][Cc]ompany?i?e?s?[ \\.,:;”])", "Company"}, {"[
  “][Oo]rganisations?[ \\.,:;”]", "Organisation"}]
  """
  @spec process_library(list()) :: list()
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
