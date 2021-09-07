IF(
  REGEX_MATCH(Acronym, "DGUV"),
  SWITCH(_url,
    "dguv_long",
      "https://publikationen.dguv.de/regelwerk/publikationen-nach-fachbereich/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_fachbereich_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_sachgebiet_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      address&"/"&
      REGEX_REPLACE(REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({Title 🇩🇪})),'- ', ' '), '[,|\\(|\\)]', ''),' ','-')&
      "?c=13",
    "dguv_short",
      "https://publikationen.dguv.de/regelwerk/dguv-vorschriften/"&
      address&"/"&
      REGEX_REPLACE(REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({Title 🇩🇪})),'- ', ' '), '[,|\\(|\\)]', ''),' ','-')&
      "?c=13",
    "dguv_regel",
      "https://publikationen.dguv.de/regelwerk/dguv-regeln/"&
      address&"/"&
      REGEX_REPLACE(REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({Title 🇩🇪})), '[,|\\(|\\)|:|;]', ''),'[[ ]-[ ]|-[ ]|[ ]-|-]', ' '),' ','-')&
      "?c=13",
    "dguv_regel_long",
      "https://publikationen.dguv.de/regelwerk/publikationen-nach-fachbereich/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_fachbereich_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_sachgebiet_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      address&"/"&
      REGEX_REPLACE(REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({Title 🇩🇪})), '[,|\\(|\\)|:|;]', ''),'[´|[ ]-[ ]|-[ ]|[ ]-|-]', ' '),' ','-'),
    "dguv_info",
      "https://publikationen.dguv.de/regelwerk/dguv-informationen/"&
      address&"/"&
      title_url,
    "dguv_info_long",
      "https://publikationen.dguv.de/regelwerk/publikationen-nach-fachbereich/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_fachbereich_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_sachgebiet_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      address&"/"&
      title_url,
    "dguv_grundsatz",
      "https://publikationen.dguv.de/regelwerk/dguv-grundsaetze/"&
      address&"/"&
      title_url,
    "dguv_grundsatz_long",
      "https://publikationen.dguv.de/regelwerk/publikationen-nach-fachbereich/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_fachbereich_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_sachgebiet_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      address&"/"&
      title_url,
    "dguv_uniq",
      "https://publikationen.dguv.de/regelwerk/dguv-vorschriften/"&address,
    "dguv_info_uniq",
      "https://publikationen.dguv.de/regelwerk/dguv-informationen/"&address,
    "dguv_info_long_uniq",
      "https://publikationen.dguv.de/regelwerk/publikationen-nach-fachbereich/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_fachbereich_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_sachgebiet_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      address,
    "dguv_regel_uniq",
      "https://publikationen.dguv.de/regelwerk/dguv-regeln/"&address,
    "dguv_grundsatz_uniq",
      "https://publikationen.dguv.de/regelwerk/dguv-grundsaetze/"&
      address,
    "dguv_grundsatz_long_uniq",
      "https://publikationen.dguv.de/regelwerk/publikationen-nach-fachbereich/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_fachbereich_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      REGEX_REPLACE(REGEX_REPLACE(TRIM(LOWER({dguv_sachgebiet_subject})), '[-|,|\\(|\\)]', ''), ' ', '-')&"/"&
      address
  ),
  IF(_url = "baua",
    "https://www.baua.de/DE/Angebote/Rechtstexte-und-Technische-Regeln/Regelwerk/"&
    Acronym&
    "/"&
    IF(
      address,
      address,
      Acronym&'-'&REGEX_REPLACE(REGEX_REPLACE(Number, '\.| ', '-'), '[ ]', '')
    )&
    ".html",
    IF(
      address,
      "https://www.gesetze-im-internet.de/"&address,
      IF(
        Acronym,
        "https://www.gesetze-im-internet.de/"&LOWER(Acronym)
      )
    )
  )
)
