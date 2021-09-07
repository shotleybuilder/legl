IF(
  REGEX_MATCH(Acronym, "DGUV"),
  SWITCH(_url,
    "dguv_long",
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            TRIM(LOWER({Title 🇩🇪})),
            '- ', ' '
          ),
          '[,|\\(|\\)]', ''
        ),
        ' ','-'
      ),
    "dguv_short",
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            TRIM(LOWER({Title 🇩🇪})),
            '- ', ' '
          ),
          '[,|\\(|\\)]', ''
        ),
        ' ','-'
      ),
    "dguv_regel",
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            TRIM(LOWER({Title 🇩🇪})),
            '[,|\\(|\\)|:|;]', ''
          ),
          '[[ ]-[ ]|-[ ]|[ ]-|-]', ' '
        ),
        ' ','-'
      ),
    "dguv_regel_long",
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            TRIM(LOWER({Title 🇩🇪})),
            '[,|\\(|\\)|:|;]', ''
          ),
          '[´|[ ]-[ ]|-[ ]|[ ]-|-]', ' '
        ),
        ' ','-'
      ),
    "dguv_info",
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            REGEX_REPLACE(
              REGEX_REPLACE(
                REGEX_REPLACE(
                  TRIM(LOWER({Title 🇩🇪})),
                  '[[\\?]|[ ]&|„|"|”|!|\\(|\\)|[:]', ''
                ),
                ';', ''
              ),
              '-\/', '/'
            ),
            '[-][,][ ]|[,][ ]', ','
          ),
          '[[,]|[´]|[ ]-[ ]|-[ ]|[ ]-|-]', ' '
        ),
        ' ','-'
      ),
    "dguv_info_long",
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            REGEX_REPLACE(
              REGEX_REPLACE(
                TRIM(LOWER({Title 🇩🇪})),
                '[[\\?]|[ ]&|„|"|”|!|\\(|\\)|:|;]', ''
              ),
              '-\/', '/'
            ),
            '[-][,][ ]|[,][ ]', ','
          ),
          '[[,]|[´]|[ ]-[ ]|-[ ]|[ ]-|-]', ' '
        ),
        ' ','-'
      ),
    "dguv_grundsatz",
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    TRIM(LOWER({Title 🇩🇪})),
    '[§|[\\?]|[ ]&|„|"|”|!|\\(|\\)|:|;]', ''
    ),
    '-\/', '/'
    ),
    '[-][,][ ]|[,][ ]', ','
    ),
    '[[,]|[´]|[ ]-[ ]|-[ ]|[ ]-|-]', ' '
    ),
    ' ','-'
    ),
    "ä", "ae"
    ),
    "ö", "oe"
    ),
    "ü", "ue"
    ),
    "ß", "ss"
    ),
    "dguv_grundsatz_long",
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    REGEX_REPLACE(
    TRIM(LOWER({Title 🇩🇪})),
    '[§|[\\?]|[ ]&|„|"|”|!|\\(|\\)|:|;]', ''
    ),
    '-\/', '/'
    ),
    '[-][,][ ]|[,][ ]', ','
    ),
    '[[,]|[´]|[ ]-[ ]|-[ ]|[ ]-|-]', ' '
    ),
    ' ','-'
    ),
    "ä", "ae"
    ),
    "ö", "oe"
    ),
    "ü", "ue"
    ),
    "ß", "ss"
    ),
    "dguv_uniq",
      TRIM(LOWER({Title 🇩🇪})),
    "dguv_info_uniq",
      TRIM(LOWER({Title 🇩🇪})),
    "dguv_info_long_uniq",
      REGEX_REPLACE(
        REGEX_REPLACE(
          REGEX_REPLACE(
            REGEX_REPLACE(
              REGEX_REPLACE(
                TRIM(LOWER({Title 🇩🇪})),
                '[[\\?]|[ ]&|„|"|”|!|\\(|\\)|:|;]', ''
              ),
              '-\/', '/'
            ),
            '[-][,][ ]|[,][ ]', ','
          ),
          '[[,]|[´]|[ ]-[ ]|-[ ]|[ ]-|-]', ' '
        ),
        ' ','-'
      ),
    "dguv_regel_uniq",
      TRIM(LOWER({Title 🇩🇪}))
  )
)
