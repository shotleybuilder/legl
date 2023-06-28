defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib do
  @moduledoc """
  Functions to create a list of dutyholder tags for a piece of text

  """

  def workflow(text) do
    {_, classes} =
      {text, []}
      # |> pre_process(blacklist())
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
    |> Enum.filter(fn x -> x != nil end)
    |> Enum.reverse()

    # if classes == [],
    #  do: [""],
    #  else:
    #    classes
    #    |> Enum.reverse()
  end

  def print_list_to_console() do
    classes =
      business() ++
        person() ++
        public() ++
        specialist() ++
        government() ++ cdm() ++ supply_chain() ++ servicer() ++ environmentalist()

    Enum.map(classes, fn {_, class} -> class end)
    |> IO.inspect(limit: :infinity)
  end

  defp process(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, class}, {text, classes} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          # A specific term (approved person) should be removed from the text to avoid matching on 'person'
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
      # not a 'person' duty
      "[ “][Aa] person guilty of an offence",
      "person is ordered",
      "person shall not be liable",
      "person.?shall be liable",
      "person is given a notice",
      "person who commits an offence"
    ]
  end

  defp business() do
    [
      {"[ “][Ii]nvestors?[ \\.,:;”]", "Investor"},
      {"[ “][Oo]wners?[ \\.,:;”]", "Owner"},
      {"[ “][Ll]essees?[ \\.,:;”]", "Lessee"},
      {"[ “][Oo]ccupiers?[ \\.,:;”]|[Pp]erson who is in occupation", "Occupier"},
      {"[ “][Ee]mployers?[ \\.,:;”]", "Employer"},
      {"([ “][Cc]ompany?i?e?s?[ \\.,:;”]| [Bb]usinesse?s?[ \\.,:;”]| [Oo]rganisations?[ \\.,:;”]| [Ee]nterprises?[ \\.,:;”])",
       "Company"}
    ]
  end

  defp person() do
    [
      {"[ “][Ee]mployees?[ \\.,:;”]", "Employee"},
      {"[ “][Ww]orkers?[ \\.,:;”]", "Worker"},
      {"[ “][Aa]ppropriate [Pp]ersons?[ \\.,:;”]", "Appropriate Person"},
      {"[ “][Rr]esponsible [Pp]ersons?[ \\.,:;”]", "Responsible Person"},
      {"[ “][Cc]ompetent [Pp]ersons?[ \\.,:;”]", "Competent Person"},
      {"[ “][Aa]uthorised [Pp]erson[ \\.,:;”]|[Aa]uthorised [Bb]ody[ \\.,:;”]",
       "Authorised Person"},
      {"[ “][Aa]ppointed [Pp]ersons?[ \\.,:;”]", "Appointed Person"},
      {"[ “][Rr]elevant [Pp]erson", "Relevant Person"},
      {"[ “][Oo]perators?[ \\.,:;”]|[Pp]erson who operates the plant", "Operator"},
      {"[ “][Pp]erson", "Person"},
      {"[ “][Dd]uty [Hh]olders?[ \\.,:;”]", "Duty Holder"},
      {"[ “][Hh]olders?[ \\.,:;”]", "Holder"},
      {"[ “][Uu]sers?[ \\.,:;”]", "User"}
    ]
  end

  defp public() do
    [
      {"[Pp]ublic (nature|sewer|importance|functions?|interest|[Ss]ervices)", nil},
      {"([Pp]ublic[ \\.,:;”]|[Ee]veryone[ \\.,:;”]|[Cc]itizens?[ \\.,:;”])", "Public"}
    ]
  end

  defp specialist() do
    [
      {"[ “][Aa]dvis[oe]r[ \\.,:;”]", "Advisor"},
      {"[ “][Nn]urse[ \\.,:;”]|[Pp]hysician[ \\.,:;”]|[Dd]octor[ \\.,:;”]", "OH Advisor"},
      {"[Rr]epresentatives? of", nil},
      {"[ “][Rr]epresentatives?[ \\.,:;”]", "Representative"},
      {"[ “][Tt]rade [Uu]nions?[ \\.,:;”]", "Trade Union"},
      {"[ “][Aa]ssessors?[ \\.,:;”]", "Assessor"},
      {"[ “][Ii]nspectors?[ \\.,:;”]", "Inspector"}
    ]
  end

  defp government() do
    [
      {"[ “]Secretary of State[ \\.,:;”]|[ “][Mm]iniste?ry?[ \\.,:;”]", "Minister"},
      {"[ “]Secretary of State or other person|[ “][Mm]iniste?ry?[ \\.,:;”]", "Minister"},
      {"[Pp]ublic [Aa]uthority?i?e?s?[ \\.,:;”]", "Public Sector"},
      {"[Ll]ocal [Aa]uthority?i?e?s?[ \\.,:;”]", "Public Sector"},
      {"[ “][Rr]egulati?on?r?y? [Aa]uthority?i?e?s?[ \\.,:;”]", "Regulator"},
      {"an authority[ \\.,:;”]", "Regulator"},
      {"[ “][Rr]egulators?[ \\.,:;”]", "Regulator"},
      {"[ “][Ee]nforce?(?:ment|ing) [Aa]uthority?i?e?s?[ \\.,:;”]", "Regulator"},
      {"[ “][Aa]uthorised [Oo]fficer[ \\.,:;”]", "Officer"}
    ]
  end

  defp cdm() do
    [
      {"[ “][Pp]rincipal [Dd]esigner[ \\.,:;”]", "Principal Designer"},
      {"[ “][Dd]esigner[ \\.,:;”]", "Designer"},
      {"[ “][Cc]onstructor[ \\.,:;”]", "Constructor"},
      {"[ “][Pp]rincipal [Cc]ontractor", "Principal Contractor"},
      {"[ “][Cc]ontractor[ \\.,:;”]", "Contractor"}
    ]
  end

  defp supply_chain() do
    [
      {"[ “][Aa]gent?s[ \\.,:;”]", "Agent"},
      {" person who.*?keeps*?[—\\.]", "Keeper"},
      {"[ “][Mm]anufacturer[ \\.,:;”]", "Manufacturer"},
      {"[ “][Pp]roducer[ \\.,:;”]|person who.*?produces*?[—\\.]", "Producer"},
      {"[ “][Aa]dvertiser[ \\.,:;”]|[Mm]arketer[ \\.,:;”]", "Marketer"},
      {"[ “][Ss]upplier[ \\.,:;”]", "Supplier"},
      {"[ “][Dd]istributor[ \\.,:;”]", "Distributor"},
      {"[ “][Ss]eller[ \\.,:;”]", "Seller"},
      {"[ “][Rr]etailer[ \\.,:;”]", "Retailer"},
      {"[ “][Ss]torer[ \\.,:;”]", "Storer"},
      {"[ “][Cc]onsignor[ \\.,:;”]", "Consignor"},
      {"[ “][Hh]andler[ \\.,:;”]", "Handler"},
      {"[ “][Cc]onsignee[ \\.,:;”]", "Consignee"},
      {"[ “][Tt]ransporter[ \\.,:;”]|person who.*?carries[—\\.]", "Carrier"},
      {"[ “][Dd]river[ \\.,:;”]", "Driver"},
      {"[ “][Ii]mporter[ \\.,:;”]|person who.*?imports*?[—\\.]", "Importer"},
      {"[ “][Ee]xporter[ \\.,:;”]|person who.*?exports*?[—\\.]", "Exporter"}
    ]
  end

  defp servicer() do
    [
      {"[ “][Ii]nstaller[ \\.,:;”]", "Installer"},
      {"[ “][Mm]aintainer[ \\.,:;”]", "Maintainer"},
      {"[ “][Rr]epairer[ \\.,:;”]", "Repairer"}
    ]
  end

  defp environmentalist() do
    [
      {"[ “][Rr]euser[ \\.,:;”]", "Reuser"},
      {" person who.*?treats*?[—\\.]", "Treater"},
      {"[ “][Rr]ecycler[ \\.,:;”]", "Recycler"},
      {"[ “][Dd]isposer[ \\.,:;”]", "Disposer"},
      {"[ “][Pp]olluter[ \\.,:;”]", "Polluter"}
    ]
  end
end
