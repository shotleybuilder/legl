IF(
  REGEX_MATCH({Title 🇩🇪},"AMR"), REGEX_EXTRACT({Title 🇩🇪}, "AMR[ ]?N?r?\.?[ ]?\d*\.?\d*"),
  IF(
    REGEX_MATCH({Title 🇩🇪},"ASR"), REGEX_EXTRACT({Title 🇩🇪}, "ASR[ ]?[A-Z]?\.?[ ]?\d*\.?\d*"),
    IF(
      REGEX_MATCH({Title 🇩🇪},"RAB"), REGEX_EXTRACT({Title 🇩🇪}, "RAB[ ]?N?r?\.?[ ]?\d*\.?\d*"),
      IF(
        REGEX_MATCH({Title 🇩🇪},"TRBS"), REGEX_EXTRACT({Title 🇩🇪}, "TRBS[ ]?N?r?\.?[ ]?\d*\.?\d*"),
        IF(
          REGEX_MATCH({Title 🇩🇪},"TRBA"), REGEX_EXTRACT({Title 🇩🇪}, "TRBA[ ]?N?r?\.?[ ]?\d*\.?\d*"),
          IF(
            REGEX_MATCH({Title 🇩🇪},"TRGS"), REGEX_EXTRACT({Title 🇩🇪}, "TRGS[ ]?N?r?\.?[ ]?\d*\.?\d*"),
            IF(
              REGEX_MATCH({Title 🇩🇪},"TRLV"), REGEX_EXTRACT({Title 🇩🇪}, "TRLV[ ]?N?r?\.?[ ]?\d*\.?\d*"),
              IF(
                REGEX_MATCH({Title 🇩🇪},"TROS"), REGEX_EXTRACT({Title 🇩🇪}, "TROS[ ]?N?r?\.?[ ]?\d*\.?\d*"),
                IF(
                  REGEX_MATCH({Title 🇩🇪},"TREMF"), REGEX_EXTRACT({Title 🇩🇪}, "TREMF[ ]?N?r?\.?[ ]?\d*\.?\d*"),
                  IF(
                    REGEX_MATCH({Title 🇩🇪},"DGUV"), REGEX_EXTRACT({Title 🇩🇪}, "DGUV[ ]?[A-Za-z]*\.?[ ]?\d*\.?\d*")
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
