UK & ID &
    IF(REGEX_MATCH(Region, "UK"), "_UK",
        IF(REGEX_MATCH(Region, "England,[ ]Wales,[ ]Scotland"), "_GB",
            IF(REGEX_MATCH(Region, "England,[ ]Wales,[ ]Northern[ ]Ireland"), "_EWNI",
                IF(REGEX_MATCH(Region, "England,[ ]Wales"), "_EW",
                    IF(REGEX_MATCH(Region, "England"), "_E",
                        IF(REGEX_MATCH(Region, "Wales"), "_W",
                            IF(REGEX_MATCH(Region, "Scotland"), "_S",
                                IF(REGEX_MATCH(Region, "Northern[ ]Ireland"), "_NI"
                                )))))))) &
    IF(Record_Type = "amendment, heading", "_a") &
    IF(Record_Type = "amendment, general", "_a_" & Amendment) &
    IF(Record_Type = "amendment, textual", "_ax_" & Amendment) &
    IF(Record_Type = "modification, heading", "_m") &
    IF(Record_Type = "modification, content", "_mx_" & Amendment) &
    IF(Record_Type = "extent, heading", "_e") &
    IF(Record_Type = "extent, content", "_ex_" & Amendment) &
    IF(Record_Type = "commencement, heading", "_c") &
    IF(Record_Type = "commencement, content", "_cx" & Amendment) &
    IF(Dupe, "_" & Dupe)