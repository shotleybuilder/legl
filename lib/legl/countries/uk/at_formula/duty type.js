REGEX_REPLACE(
    "" &
    IF(REGEX_MATCH(Text, "[ ][Nn]o[ ]person[ ]shall"), "Duty, ") &
    IF(REGEX_MATCH(Text, "[ ][Tt]he[ ]person.*?must[ ]use"), "Duty, ") &
    IF(REGEX_MATCH(Text, "[ ][Tt]he[ ]person.*?shall"), "Duty, ") &
    IF(REGEX_MATCH(Text, "[ ][Pp]erson[ ](?:shall[ ]notify|shall[ ]furnish[ ]the[ ]authority)]"), "Duty, ") &
    IF(REGEX_MATCH(Text, "[ ]A[ ]person[ ]shall[ ]not"), "Duty, ") &
    IF(REGEX_MATCH(Text, "[ ]shall[ ]be[ ]the[ ]duty[ ]of[ ]any[ ]person"), "Duty, ") &
    IF(REGEX_MATCH(Text, "[ ][Pp]erson[ ]*?may[ ]at[ ]any[ ]time]"), "Right, ") &
    IF(REGEX_MATCH(Text, "[a-z]”[ ](?:means|includes|has?v?e?[ ]the[ ](?:same )?meanings?|is|are[ ]to[ ]be[ ]read[ ]as)[ —]"), "\"Interpretation, Definition\", ") &
    IF(REGEX_MATCH(Text, "[ ]has?v?e?[ ]the[ ](?:same )?meanings?[ ]as"), "\"Interpretation, Definition\", ") &
    IF(REGEX_MATCH(Text, "[ ]any[ ]reference[ ]in[ ]this[ ].*?to"), "\"Interpretation, Definition\", ") &
    IF(REGEX_MATCH(Text, "[ ][Ff]or[ ]the[ ]purposes[ ]of.*?[ ](?:Part|Chapter|[sS]ection|subsection)"), "\"Interpretation, Definition\", ") &
    IF(REGEX_MATCH(Text, "[ ]This[ ](?:Part|Chapter|[Ss]ection)[ ]applies"), "\"Application, Scope\", ") &
    IF(REGEX_MATCH(Text, "[ ]This[ ](?:Part|Chapter|[Ss]ection)[ ]does[ ]not[ ]apply"), "\"Application, Scope\", ") &
    IF(REGEX_MATCH(Text, "[ ]does[ ]not[ ]apply"), "\"Application, Scope\", ") &
    IF(REGEX_MATCH(Text, "[ ][Aa]ppeal[ ]"), "\"Defence, Exemptions, Appeals\", ") &
    IF(REGEX_MATCH(Text, "[ ][Oo]ffence[ ]|[ ]fixed[ ]penalty"), "Offences, ") &
    IF(REGEX_MATCH(Text, "shall not[ ]"), "Exemption, "),
    ",[ ]$", ""
)