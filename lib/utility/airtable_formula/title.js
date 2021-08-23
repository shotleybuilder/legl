IF(
  REGEX_MATCH(Title, "(19[7|8|9]\\d)/"),
  REGEX_EXTRACT(Title, "(19[7|8|9]\\d)/"),
  IF(
    REGEX_MATCH(Title, "(20[0|1|2]\\d)/"),
    REGEX_EXTRACT(Title, "(20[0|1|2]\\d)/"),
    IF(
      REGEX_MATCH(Title, "/(19[7|8|9]\\d)"),
      REGEX_EXTRACT(Title, "/(19[7|8|9]\\d)"),
      IF(
        REGEX_MATCH(Title, "/(20[0|1|2]\\d)"),
        REGEX_EXTRACT(Title, "/(20[0|1|2]\\d)"),
        IF(
          REGEX_MATCH(Title, "(20[0|1|2]\\d)"),
          REGEX_EXTRACT(Title, "(20[0|1|2]\\d)"),
          IF(
            REGEX_MATCH(Title, "(19[7|8|9]\\d)"),
            REGEX_EXTRACT(Title, "(19[7|8|9]\\d)")
          )
        )
      )
    )
  )
)
IF(
  REGEX_MATCH(
    Title,
    "(\d\d?)\.[ ](?:Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)"
  ),
  REGEX_EXTRACT(
    Title,
    "(\d\d?)\.[ ](?:Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)"
  )
)

IF(REGEX_MATCH(Title, "Januar"),
  "01",
  IF(REGEX_MATCH(Title, "Februar"),
    "02",
    IF(REGEX_MATCH(Title, "März"),
      "03",
      IF(REGEX_MATCH(Title, "April"),
        "04",
        IF(REGEX_MATCH(Title, "Mai"),
          "05",
          IF(REGEX_MATCH(Title, "Juni"),
            "06",
            IF(REGEX_MATCH(Title, "Juli"),
              "07",
              IF(REGEX_MATCH(Title, "August"),
                "08",
                IF(REGEX_MATCH(Title, "September"),
                  "09",
                  IF(REGEX_MATCH(Title, "Oktober"),
                    "10",
                    IF(REGEX_MATCH(Title, "November"),
                    "11",
                      IF(REGEX_MATCH(Title, "Dezember"),
                      "12"
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)
