REGEX_REPLACE(
    "" &
    IF(REGEX_MATCH(Text, "[ “][Ii]nvestor[ \.,:;”]"), "Investor, ") &
    IF(REGEX_MATCH(Text, "[ “][Oo]wner[ \.,:;”]"), "Owner, ") &
    IF(REGEX_MATCH(Text, "[ “][Ll]essee[ \.,:;”]"), "Lessee, ") &
    IF(REGEX_MATCH(Text, "[ “][Oo]ccupier[ \.,:;”]|[Pp]erson[ ]who[ ]is[ ]in[ ]occupation"), "Occupier, ") &
    IF(REGEX_MATCH(Text, "[ “][Ee]mployer[ \.,:;”]"), "Employer, ") &
    IF(REGEX_MATCH(Text, "[ “][Cc]ompany[ \.,:;”]|[ ][Bb]usiness[ \.,:;”]|[ ][Oo]rganisation[ \.,:;”]|[ ][Ee]nterprise[ \.,:;”]"), "Company, ") &
    IF(REGEX_MATCH(Text, "[ “][Ee]mployee[ \.,:;”]"), "Employee, ") &
    IF(REGEX_MATCH(Text, "[ “][Ww]orker[ \.,:;”]"), "Worker, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]ppropriate[ ][Pp]erson[ \.,:;”]"), "Appropriate Person, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]esponsible[ ][Pp]erson[ \.,:;”]"), "Responsible Person, ") &
    IF(REGEX_MATCH(Text, "[ “][Cc]ompetent[ ][Pp]erson[ \.,:;”]"), "Competent Person, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]uthorised[ ][Pp]erson[ \.,:;”]|[Aa]uthorised [Bb]ody[ \.,:;”]"), "Authorised Person, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]ppointed[ ][Pp]erson[ \.,:;”]"), "Appointed Person, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]elevant[ ][Pp]erson"), "Relevant Person, ") &
    IF(REGEX_MATCH(Text, "[ “][Hh]older[ \.,:;”]"), "Holder, ") &
    IF(REGEX_MATCH(Text, "[ “][Dd]uty[ ][Hh]older[ \.,:;”]"), "Duty Holder, ") &
    IF(REGEX_MATCH(Text, "[ “][Pp]erson[ \.,:;”]|[Ee]veryone[ \.,:;”]|[Cc]itizen[ \.,:;”]"), "Person, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]dvis[oe]r[ \.,:;”]"), "Advisor, ") &
    IF(REGEX_MATCH(Text, "[ “][Nn]urse[ \.,:;”]|[Pp]hysician[ \.,:;”]|[Dd]octor[ \.,:;”]"), "OH Advisor, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]epresentative[ \.,:;”]"), "Representative, ") &
    IF(REGEX_MATCH(Text, "[ “][Tt]rade[ ][Uu]nion[ \.,:;”]"), "TU, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]gent?s[ \.,:;”]"), "Agent, ") &
    IF(REGEX_MATCH(Text, "[ “]Secretary[ ]of[ ]State[ \.,:;”]|[ “][Mm]iniste?ry?[ \.,:;”]"), "Minister, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]egulators?[ \.,:;”]"), "Regulator, ") &
    IF(REGEX_MATCH(Text, "[ “][Ll]ocal[ ][Aa]uthority?i?e?s?[ \.,:;”]"), "Regulator, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]egulati?on?r?y?[ ][Aa]uthority?i?e?s?[ \.,:;”]"), "Regulator, ") &
    IF(REGEX_MATCH(Text, "[ “][Ee]nforce?(?:ment|ing)[ ][Aa]uthority?i?e?s?[ \.,:;”]"), "Regulator, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]uthorised[ ][Oo]fficer[ \.,:;”]"), "Officer, ") &
    IF(REGEX_MATCH(Text, "[ “][Pp]rincipal[ ][Dd]esigner[ \.,:;”]"), "Principal Designer, ") &
    IF(REGEX_MATCH(Text, "[ “][Dd]esigner[ \.,:;”]"), "Designer, ") &
    IF(REGEX_MATCH(Text, "[ “][Cc]onstructor[ \.,:;”]"), "Constructor, ") &
    IF(REGEX_MATCH(Text, "[ “][Mm]anufacturer[ \.,:;”]"), "Manufacturer, ") &
    IF(REGEX_MATCH(Text, "[ “][Pp]roducer[ \.,:;”]|person[ ]who.*?produces*?[—\.]"), "Producer, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]dvertiser[ \.,:;”]|[Mm]arketer[ \.,:;”]"), "Marketer, ") &
    IF(REGEX_MATCH(Text, "[ “][Ss]upplier[ \.,:;”]"), "Supplier, ") &
    IF(REGEX_MATCH(Text, "[ “][Dd]istributor[ \.,:;”]"), "Distributor, ") &
    IF(REGEX_MATCH(Text, "[ “][Ss]eller[ \.,:;”]"), "Seller, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]etailer[ \.,:;”]"), "Retailer, ") &
    IF(REGEX_MATCH(Text, "[ “][Ss]torer[ \.,:;”]"), "Storer, ") &
    IF(REGEX_MATCH(Text, "[ “][Cc]onsignor[ \.,:;”]"), "Consignor, ") &
    IF(REGEX_MATCH(Text, "[ “][Hh]andler[ \.,:;”]"), "Handler, ") &
    IF(REGEX_MATCH(Text, "[ “][Cc]onsignee[ \.,:;”]"), "Consignee, ") &
    IF(REGEX_MATCH(Text, "[ “][Tt]ransporter[ \.,:;”]|person[ ]who.*?carries[—\.]"), "Carrier, ") &
    IF(REGEX_MATCH(Text, "[ “][Dd]river[ \.,:;”]"), "Driver, ") &
    IF(REGEX_MATCH(Text, "[ “][Ii]mporter[ \.,:;”]|person[ ]who.*?imports*?[—\.]"), "Importer, ") &
    IF(REGEX_MATCH(Text, "[ “][Ee]xporter[ \.,:;”]|person[ ]who.*?exports*?[—\.]"), "Exporter, ") &
    IF(REGEX_MATCH(Text, "[ “][Ii]nstaller[ \.,:;”]"), "Installer, ") &
    IF(REGEX_MATCH(Text, "[ “][Mm]aintainer[ \.,:;”]"), "Maintainer, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]epairer[ \.,:;”]"), "Repairer, ") &
    IF(REGEX_MATCH(Text, "[ “][Pp]rincipal[ ][Cc]ontractor"), "Principal Contractor, ") &
    IF(REGEX_MATCH(Text, "[ “][Cc]ontractor[ \.,:;”]"), "Contractor, ") &
    IF(REGEX_MATCH(Text, "[ “][Uu]ser[ \.,:;”]"), "User, ") &
    IF(REGEX_MATCH(Text, "[ “][Oo]perator[ \.,:;”]|[Pp]erson[ ]who[ ]operates[ ]the[ ]plant"), "Operator, ") &
    IF(REGEX_MATCH(Text, "[ ]person[ ]who.*?keeps*?[—\.]"), "Keeper, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]euser[ \.,:;”]"), "Reuser, ") &
    IF(REGEX_MATCH(Text, "[ ]person[ ]who.*?treats*?[—\.]"), "Treater, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]ecycler[ \.,:;”]"), "Recycler, ") &
    IF(REGEX_MATCH(Text, "[ “][Dd]isposer[ \.,:;”]"), "Disposer, ") &
    IF(REGEX_MATCH(Text, "[ “][Pp]olluter[ \.,:;”]"), "Polluter, ") &
    IF(REGEX_MATCH(Text, "[ “][Aa]ssessors?[ \.,:;”]"), "Assessor, ") &
    IF(REGEX_MATCH(Text, "[ “][Ii]nspector[ \.,:;”]"), "Inspector, "),
    ",[ ]$", ""
)