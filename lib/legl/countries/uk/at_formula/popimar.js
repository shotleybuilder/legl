REGEX_REPLACE(
    "" &
    IF(REGEX_MATCH(Text, "[ “][Pp]ermit[ \.,:;”]|[ ][Aa]uthorisation[ \.,:;”]|[Ll]i[sc]en[sc]e"), "\"Permit, Authorisation, License\", ") &
    IF(REGEX_MATCH(Text, "[ “][Cc]hecki?n?g?[ \.,:;”]|[ ][Mm]onitori?n?g?[ \.,:;”]"), "Monitor, ") &
    IF(REGEX_MATCH(Text, "[ “][Rr]eviewi?n?g?[ \.,:;”]"), "Review, "),
    ",[ ]$", ""
)