defmodule Legl.Countries.Uk.AtArticle.AtTaxa.AtTaxaDutyholder.DutyholderLib do
  @moduledoc """
  Functions to create a list of dutyholder tags for a piece of text

  """

  def workflow(text) do
    {_, classes} =
      {text, []}
      |> business()
      |> person()
      |> public()
      |> specialist()
      |> government()
      |> cdm()
      |> supply_chain()
      |> servicer()
      |> environmentalist()

    classes
    |> Enum.reverse()
  end

  defp process(data, collector) do
    Enum.reduce(data, collector, fn {regex, class}, {text, classes} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          # A specific term (approved person) should be removed from the text to avoid matching on 'person'
          {Regex.replace(~r/#{regex}/, text, ""), [class | classes]}

        false ->
          acc
      end
    end)
  end

  defp business(collector) do
    [
      {"[ “][Ii]nvestors?[ \\.,:;”]", "Investor"},
      {"[ “][Oo]wners?[ \\.,:;”]", "Owner"},
      {"[ “][Ll]essees?[ \\.,:;”]", "Lessee"},
      {"[ “][Oo]ccupiers?[ \\.,:;”]|[Pp]erson who is in occupation", "Occupier"},
      {"[ “][Ee]mployers?[ \\.,:;”]", "Employer"},
      {"([ “][Cc]ompany?i?e?s?[ \\.,:;”]| [Bb]usinesse?s?[ \\.,:;”]| [Oo]rganisations?[ \\.,:;”]| [Ee]nterprises?[ \\.,:;”])",
       "Company"}
    ]
    |> process(collector)
  end

  defp person(collector) do
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
      {"[ “][Pp]erson", "Person"},
      {"[ “][Dd]uty [Hh]olders?[ \\.,:;”]", "Duty Holder"},
      {"[ “][Hh]olders?[ \\.,:;”]", "Holder"},
      {"[ “][Uu]sers?[ \\.,:;”]", "User"},
      {"[ “][Oo]perators?[ \\.,:;”]|[Pp]erson who operates the plant", "Operator"}
    ]
    |> process(collector)
  end

  defp public(collector) do
    [{"([Pp]ublic[ \\.,:;”]|[Ee]veryone[ \\.,:;”]|[Cc]itizens?[ \\.,:;”])", "Public"}]
    |> process(collector)
  end

  defp specialist(collector) do
    [
      {"[ “][Aa]dvis[oe]r[ \\.,:;”]", "Advisor"},
      {"[ “][Nn]urse[ \\.,:;”]|[Pp]hysician[ \\.,:;”]|[Dd]octor[ \\.,:;”]", "OH Advisor"},
      {"[ “][Rr]epresentatives?[ \\.,:;”]", "Representative"},
      {"[ “][Tt]rade [Uu]nions?[ \\.,:;”]", "TU"},
      {"[ “][Aa]ssessors?[ \\.,:;”]", "Assessor"},
      {"[ “][Ii]nspectors?[ \\.,:;”]", "Inspector"}
    ]
    |> process(collector)
  end

  defp government(collector) do
    [
      {"[ “]Secretary of State[ \\.,:;”]|[ “][Mm]iniste?ry?[ \\.,:;”]", "Minister"},
      {"[ “][Rr]egulators?[ \\.,:;”]", "Regulator"},
      {"[ “][Ll]ocal [Aa]uthority?i?e?s?[ \\.,:;”]", "Regulator"},
      {"[ “][Rr]egulati?on?r?y? [Aa]uthority?i?e?s?[ \\.,:;”]", "Regulator"},
      {"[ “][Ee]nforce?(?:ment|ing) [Aa]uthority?i?e?s?[ \\.,:;”]", "Regulator"},
      {"[ “][Aa]uthorised [Oo]fficer[ \\.,:;”]", "Officer"}
    ]
    |> process(collector)
  end

  defp cdm(collector) do
    [
      {"[ “][Pp]rincipal [Dd]esigner[ \\.,:;”]", "Principal Designer"},
      {"[ “][Dd]esigner[ \\.,:;”]", "Designer"},
      {"[ “][Cc]onstructor[ \\.,:;”]", "Constructor"},
      {"[ “][Pp]rincipal [Cc]ontractor", "Principal Contractor"},
      {"[ “][Cc]ontractor[ \\.,:;”]", "Contractor"}
    ]
    |> process(collector)
  end

  defp supply_chain(collector) do
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
    |> process(collector)
  end

  defp servicer(collector) do
    [
      {"[ “][Ii]nstaller[ \\.,:;”]", "Installer"},
      {"[ “][Mm]aintainer[ \\.,:;”]", "Maintainer"},
      {"[ “][Rr]epairer[ \\.,:;”]", "Repairer"}
    ]
    |> process(collector)
  end

  defp environmentalist(collector) do
    [
      {"[ “][Rr]euser[ \\.,:;”]", "Reuser"},
      {" person who.*?treats*?[—\\.]", "Treater"},
      {"[ “][Rr]ecycler[ \\.,:;”]", "Recycler"},
      {"[ “][Dd]isposer[ \\.,:;”]", "Disposer"},
      {"[ “][Pp]olluter[ \\.,:;”]", "Polluter"}
    ]
    |> process(collector)
  end
end
