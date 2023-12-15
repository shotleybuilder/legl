REGEX_REPLACE(
    ""&
    IF(REGEX_MATCH(paste_text_here, "[Ii]nvestor" ), "Investor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Oo]wner" ), "Owner, ")&
    IF(REGEX_MATCH(paste_text_here, "[Oo]ccupier" ), "Occupier, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ee]mployer" ), "Employer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Cc]ompany|[Bb]usiness|[Oo]rganisation|[Ee]nterprise" ), "Company, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ee]mployee" ), "Employee, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ww]orker" ), "Worker, ")&
    IF(REGEX_MATCH(paste_text_here, "[Rr]esponsible[ ][Pp]erson" ), "Responsible Person, ")&
    IF(REGEX_MATCH(paste_text_here, "[Cc]ompetent[ ][Pp]erson" ), "Competent Person, ")&
    IF(REGEX_MATCH(paste_text_here, "[Aa]uthorised[ ][Pp]erson|[Aa]uthorised [Bb]ody" ), "Authorised Person, ")&
    IF(REGEX_MATCH(paste_text_here, "[Aa]ppointed[ ][Pp]erson" ), "Appointed Person, ")&
    IF(REGEX_MATCH(paste_text_here, "[Rr]elevant[ ][Pp]erson" ), "Relevant Person, ")&
    IF(REGEX_MATCH(paste_text_here, "[Dd]uty[ ][Hh]older" ), "Duty Holder, ")&
    IF(REGEX_MATCH(paste_text_here, "[Pp]erson|[Ee]veryone|[Cc]itizen"), "Person, ")&
    IF(REGEX_MATCH(paste_text_here, "[Aa]dvis[oe]r" ), "Advisor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Nn]urse|[Pp]hysician|[Dd]octor" ), "OH Advisor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Rr]epresentative"), "Representative, ")&
    IF(REGEX_MATCH(paste_text_here, "[Tt]rade[ ][Uu]nion"), "TU, ")&
    IF(REGEX_MATCH(paste_text_here, "[Aa]gent[\\s|\\.]"), "Agent, ")&
    IF(REGEX_MATCH(paste_text_here, "[Mm]iniste?ry?|[Rr]egulator\\s?" ), "Ministry / Regulator, ")&
    IF(REGEX_MATCH(paste_text_here, "[Pp]rincipal[ ][Dd]esigner" ), "Principal Designer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Dd]esigner" ), "Designer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Cc]onstructor" ), "Constructor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Mm]anufacturer"), "Manufacturer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Pp]roducer"), "Producer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Aa]dvertiser|[Mm]arketer"), "Marketer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ss]upplier" ), "Supplier, ")&
    IF(REGEX_MATCH(paste_text_here, "[Dd]istributor" ), "Distributor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ss]eller" ), "Seller, ")&
    IF(REGEX_MATCH(paste_text_here, "[Rr]etailer" ), "Retailer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ss]torer" ), "Storer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Cc]onsignor" ), "Consignor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Hh]andler" ), "Handler, ")&
    IF(REGEX_MATCH(paste_text_here, "[Cc]onsignee" ), "Consignee, ")&
    IF(REGEX_MATCH(paste_text_here, "[Tt]ransporter" ), "Transporter, ")&
    IF(REGEX_MATCH(paste_text_here, "[Dd]river" ), "Driver, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ii]mporter" ), "Importer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ee]xporter"), "Exporter, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ii]nstaller" ), "Installer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Mm]aintainer" ), "Maintainer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Rr]epairer" ), "Repairer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Pp]rincipal[ ][Cc]ontractor" ), "Principal Contractor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Cc]ontractor" ), "Contractor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Uu]ser" ), "User, ")&
    IF(REGEX_MATCH(paste_text_here, "[Oo]perator" ), "Operator, ")&
    IF(REGEX_MATCH(paste_text_here, "[Rr]user" ), "Reuser, ")&
    IF(REGEX_MATCH(paste_text_here, "[Rr]ecycler" ), "Recycler, ")&
    IF(REGEX_MATCH(paste_text_here, "[Dd]isposer" ), "Disposer, ")&
    IF(REGEX_MATCH(paste_text_here, "[Pp]olluter" ), "Polluter, ")&
    IF(REGEX_MATCH(paste_text_here, "[Aa]ssessor[\\s|\\.]" ), "Assessor, ")&
    IF(REGEX_MATCH(paste_text_here, "[Ii]nspector" ), "Inspector, "),
    ",[ ]$", ""
    )