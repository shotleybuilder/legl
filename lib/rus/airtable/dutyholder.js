REGEX_REPLACE(
  ""&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ii]nvestor" ), "Investor, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Oo]wner" ), "Owner, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Oo]ccupier" ), "Occupier, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ee]mployer" ), "Employer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Cc]ompany|[Bb]usiness|[Oo]rganisation|[Ee]nterprise" ), "Company, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ee]mployee" ), "Employee, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ww]orker" ), "Worker, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Pp]erson|[Ee]veryone|[Cc]itizen"), "Person, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Aa]dvis[oe]r" ), "Advisor, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Nn]urse|[Pp]hysician|[Dd]octor" ), "OH Advisor, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Rr]epresentative"), "Rep, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Tt]rade[ ][Uu]nion"), "TU, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Aa]gent[\\s|\\.]"), "Agent, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Mm]iniste?ry?|[Rr]egulator\\s?" ), "Ministry / Regulator, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Dd]esigner" ), "Designer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Cc]onstructor" ), "Constructor, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Mm]anufacturer"), "Manufacturer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Pp]roducer"), "Producer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Aa]dvertiser|[Mm]arketer"), "Marketer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ss]upplier" ), "Supplier, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Dd]istributor" ), "Distributor, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ss]eller" ), "Seller, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Rr]etailer" ), "Retailer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ss]torer" ), "Storer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Cc]onsignor" ), "Consignor, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Hh]andler" ), "Handler, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Cc]onsignee" ), "Consignee, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Tt]ransporter" ), "Transporter, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Dd]river" ), "Driver, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ii]mporter" ), "Importer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ee]xporter"), "Exporter, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ii]nstaller" ), "Installer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Mm]aintainer" ), "Maintainer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Rr]epairer" ), "Repairer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Cc]ontractor" ), "Contractor, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Uu]ser" ), "User, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Oo]perator" ), "Operator, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Rr]user" ), "Reuser, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Rr]ecycler" ), "Recycler, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Dd]isposer" ), "Disposer, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Pp]olluter" ), "Polluter, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Aa]uthorised [Pp]erson|[Aa]uthorised [Bb]ody" ), "Authorised Person, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Aa]ssessor[\\s|\\.]" ), "Assessor\\s+, ")&
  IF(REGEX_MATCH({text_en_🏴󠁧󠁢󠁥󠁮󠁧󠁿️}, "[Ii]nspector" ), "Inspector, "),
  ",[ ]$", "")
