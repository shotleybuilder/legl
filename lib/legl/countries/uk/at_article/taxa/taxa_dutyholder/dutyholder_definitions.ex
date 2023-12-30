defmodule DutyholderDefinitions do
  @moduledoc """
  Functions to build search Regex expressions
  """

  def dutyholder_library() do
    # Adds the separate dutyholder libraries together into a single keyword list
    government() ++ governed()
  end

  def government() do
    ([
       "Gvt: Commissioners": "[Cc]ommissioners",
       "Gvt: Officer": ["[Aa]uthorised [Oo]fficer", "[Oo]fficer of a local authority"],
       "Gvt: Appropriate Person": "[Aa]ppropriate [Pp]ersons?",
       "Gvt: Judiciary": ["court", "[Jj]ustice of the [Pp]eace"],
       "Gvt: Emergency Services: Police": ["[Cc]onstable", "[Cc]hief of [Pp]olice"],
       "Gvt: Emergency Services": "[Ee]mergency [Ss]ervices?"
     ] ++
       authority() ++
       secretary_of_state() ++
       ministries() ++ agencies() ++ devolved_administrations() ++ forces())
    |> Enum.sort(:desc)
    |> process_library()
  end

  defp authority(),
    do: [
      "Gvt: Authority: Enforcement":
        "(?:[Rr]egulati?on?r?y?|[Ee]nforce?(?:ment|ing)) [Aa]uthority?i?e?s?",
      "Gvt: Authority: Local": "[Ll]ocal [Aa]uthority?i?e?s?",
      "Gvt: Authority: Public": "[Pp]ublic [Aa]uthority?i?e?s?",
      "Gvt: Authority: Traffic": "[Tt]raffic [Aa]uthority?i?e?s?",
      "Gvt: Authority: Waste":
        "(?:[Ww]aste collection|[Ww]aste disposal|[Dd]isposal) [Aa]uthority?i?e?s?",
      "Gvt: Authority": [
        "(?:[Tt]he|[Aa]n|appropriate|allocating|[Cc]ompetent|[Dd]esignated) authority",
        "[Rr]egulators?",
        "[Mm]onitoring [Aa]uthority?i?e?s?"
      ]
    ]

  defp devolved_administrations() do
    [
      "Gvt: Devolved Admin: National Assembly for Wales": [
        "National Assembly for Wales",
        "Senedd",
        "Welsh Parliament"
      ],
      "Gvt: Devolved Admin: Scottish Parliament": "Scottish Parliament",
      "Gvt: Devolved Admin: Northern Ireland Assembly": "Northern Ireland Assembly",
      "Gvt: Devolved Admin:": "Assembly"
    ]
  end

  defp agencies() do
    [
      "Gvt: Agency: Environment Agency": "Environment Agency",
      "Gvt: Agency: Health and Safety Executive": [
        "Health and Safety Executive",
        "[Tt]he Executive"
      ],
      "Gvt: Agency: Natural Resources Body for Wales": "Natural Resources Body for Wales",
      "Gvt: Agency: Office for Environmental Protection": [
        "Office for Environmental Protection",
        "OEP"
      ],
      "Gvt: Agency: Office for Nuclear Regulation": "Office for Nuclear Regulations?",
      "Gvt: Agency: Office of Rail and Road": "Office of Rail and Road?",
      "Gvt: Agency: Scottish Environment Protection Agency": [
        "Scottish Environment Protection Agency",
        "SEPA"
      ],
      "Gvt: Agency:": "[Aa]gency"
    ]
  end

  defp secretary_of_state() do
    [
      "Gvt: Minister: Secretary of State for Defence": "Secretary of State for Defence",
      "Gvt: Minister: Secretary of State for Transport": "Secretary of State for Transport",
      "Gvt: Minister": [
        "Secretary of State",
        "[Mm]inisters?"
      ]
    ]
  end

  defp ministries() do
    [
      "Gvt: Ministry: Ministry of Defence": "Ministry of Defence",
      "Gvt: Ministry: Department of the Environment": "Department of the Environment",
      "Gvt: Ministry:": "[Tt]he Department",
      "Gvt: Ministry: Treasury": "[Tt]reasury",
      "Gvt: Ministry:": "[Mm]inistry"
    ]
  end

  defp forces(),
    do: [
      "HM Forces: Navy": "(?:His|Her) Majesty's Navy"
    ]

  def blacklist() do
    [
      "local authority collected municipal waste",
      "[Pp]ublic (?:nature|sewer|importance|functions?|interest|[Ss]ervices)",
      "[Rr]epresentatives? of"
    ]
  end

  def governed(),
    do:
      (business() ++
         person() ++
         public() ++
         specialist() ++
         supply_chain() ++
         servicer() ++
         maritime() ++
         environmentalist())
      |> process_library()

  defp business() do
    [
      "Org: Investor": "[Ii]nvestors",
      "Org: Owner": "[Oo]wner",
      "Org: Lessee": "[Ll]essee",
      "Org: Occupier": ["[Oo]ccupiers?", "[Pp]erson who is in occupation"],
      "Org: Employer": "[Ee]mployers?",
      Operator: "[Oo]perators?",
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
      "Ind: Self-employed Worker": "[Ss]elf-employed (?:[Pp]ersons?|diver)",
      "Ind: Responsible Person": "[Rr]esponsible [Pp]ersons?",
      "Ind: Competent Person": "[Cc]ompetent [Pp]ersons?",
      "Ind: Authorised Person": [
        "[Aa]uthorised [Pp]erson",
        "[Aa]uthorised [Bb]ody",
        "[Aa]uthorised Representative"
      ],
      "Ind: Supervisor": "[Ss]upervisor",
      "Ind: Appointed Person": ["[Aa]ppointed [Pp]ersons?", "[Aa]ppointed body"],
      "Ind: Relevant Person": "[Rr]elevant [Pp]erson",
      Operator: "[Pp]erson who operates the plant",
      "Ind: Person": ["[Pp]ersons?", "site manager", "[Ii]ndividual"],
      "Ind: Dutyholder": ["[Dd]uty [Hh]olders?", "[Dd]utyholder"],
      "Ind: Holder": "[Hh]olders?",
      "Ind: User": "[Uu]sers?",
      "Ind: Licensee": ["[Ll]icensee", "[Aa]pplicant"],
      "Ind: Diver": "[Dd]iver"
    ]
  end

  defp public() do
    [Public: ["[Pp]ublic", "[Ee]veryone", "[Cc]itizens?"]]
  end

  defp specialist() do
    [
      "Spc: Advisor": "[Aa]dvis[oe]r",
      "Spc: OH Advisor": ["[Nn]urse", "[Pp]hysician", "[Dd]octor", "[Mm]edical examiner"],
      "Spc: Representative": "[Rr]epresentatives?",
      "Spc: Trade Union": "[Tt]rade [Uu]nions?",
      "Spc: Assessor": "[Aa]ssessors?",
      "Spc: Inspector": "[Ii]nspectors?",
      "Spc: Body": "[Aa]ppropriate [Bb]ody"
    ]
  end

  defp supply_chain() do
    # T&L = transport and logistics
    # C = construction
    [
      "SC: Agent": "(?<![Bb]iological )[Aa]gent?s",
      "SC: Keeper": "person who.*?keeps*?",
      "SC: Manufacturer": "[Mm]anufacturer",
      "SC: Producer": ["[Pp]roducer", "person who.*?produces*?"],
      "SC: C: Principal Designer": "[Pp]rincipal [Dd]esigner",
      "SC: C: Designer": "[Dd]esigner",
      "SC: C: Constructor": "[Cc]onstructor",
      "SC: C: Principal Contractor": "[Pp]rincipal [Cc]ontractor",
      "SC: C: Contractor": ["[Cc]ontractor", "[Dd]iving contractor"],
      "SC: Marketer": ["[Aa]dvertiser", "[Mm]arketer"],
      "SC: Supplier": "[Ss]upplier",
      "SC: Distributor": "[Dd]istributor",
      "SC: Seller": "[Ss]eller",
      "SC: Dealer": "(?:[Ss]crap metal )?[Dd]ealer",
      "SC: Retailer": "[Rr]etailer",
      "SC: Domestic Client": "[Dd]omestic [Cc]lient",
      "SC: Client": "[Cc]lients?",
      "SC: Customer": "[Cc]ustomer",
      "SC: Consumer": "[Cc]onsumer",
      "SC: Storer": "[Ss]torer",
      "SC: T&L: Consignor": "[Cc]onsignor",
      "SC: T&L: Handler": "[Hh]andler",
      "SC: T&L: Consignee": "[Cc]onsignee",
      "SC: T&L: Carrier": ["[Tt]ransporter", "person who.*?carries", "[Cc]arriers?"],
      "SC: T&L: Driver": "[Dd]river",
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

  defp maritime(),
    do: [
      "Maritime: crew": "crew of a ship",
      "Maritime: master": "master.*?of a ship"
    ]

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
  process/2 eg
  {"Gvt: Authority: Local", "[[:blank:][:punct:]“][Ll]ocal [Aa]uthority?i?e?s?[[:blank:][:punct:]”]"}
  """
  @spec process_library(list()) :: list()
  def process_library(library) do
    library
    |> Enum.reduce([], fn
      {k, v}, acc when is_binary(v) ->
        [{k, "[[:blank:][:punct:]“]#{v}[[:blank:][:punct:]”]"} | acc]

      # [{Atom.to_string(k), "[[:blank:][:punct:]“]#{v}[[:blank:][:punct:]”]"} | acc]

      {k, v}, acc when is_list(v) ->
        Enum.reduce(v, [], fn x, accum ->
          ["[[:blank:][:punct:]“]#{x}[[:blank:][:punct:]”]" | accum]
        end)
        |> Enum.join("|")
        |> (fn x -> ~s/(?:#{x})/ end).()
        |> (&{k, &1}).()
        # |> (&{Atom.to_string(k), &1}).()
        |> (&[&1 | acc]).()
    end)
    |> Enum.reverse()
  end
end
