REGEX_REPLACE(
  REGEX_REPLACE(
    REGEX_REPLACE(
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            REGEX_REPLACE(
              REGEX_REPLACE(
                REGEX_REPLACE(
                  REGEX_REPLACE(
                    REGEX_REPLACE(
                      REGEX_REPLACE(
                        REGEX_REPLACE(
                          TRIM(Downcase), "\\(|\\)|\\/|\"|\\-|[A-Za-z]+\\.?\\d+|\\d+|:|\\.|,|—|\\*|&|\\[|\\]|\\+", ""
                        ),
                        "[ ][T|t]o[ ]|[ ][T|t]h[a|e|i|o]t?s?e?[ ]"," "
                      ),
                      "[ ][A|a][ ]|[ ][A|a]n[ ]|[ ][A|a]nd[ ]|[ ][A|a]t[ ]|[ ][A|a]re[ ]", " "
                    ),
                    "[ ][F|f]?[O|o]r[ ]", " "
                  ),
                  "[ ][I|i][f|n][ ]|[ ][I|i][s|t]s?[ ]", " "
                ),
                "[ ][O|o][f|n][ ]", " "
              ),
              "[ ][N|n]ot?[ ]", " "
            ),
            "[ ][B|b][e|y][ ]", " "
          ),
          "[ ][W|w]i?t?ho?[ ]", " "
        ),
        "[ ][A-Z|a-z][ |\\.|,]", ""
      ),
      "[H| h]as?v?e?[ ]", ""
    ),
    "[ ]+", ", "
  ),
  "^,[ ]", 
"" )
