REGEX_REPLACE(
    UK&
    IF({flow}="pre",
    Part&"_"&
    Chapter&"_"&
    Heading&"_"&
    {Section||Regulation}&"_"&
    {Sub_Section||Sub_Regulation}&"_"&
    Paragraph&"_")&

    IF(OR(flow="",flow="main"),"_"&
    Part&"_"&
    Chapter&"_"&
    Heading&"_"&
    {Section||Regulation}&"_"&
    {Sub_Section||Sub_Regulation}&"_"&
    Paragraph&"_")&
    
    IF(flow="post","-")&
    IF(REGEX_MATCH(flow, "1|2|3|4|5|6|7|8|9|0"),"-"&flow&"_"&
    Part&"_"&
    Chapter&"_"&
    Heading&"_"&
    {Section||Regulation}&"_"&
    {Sub_Section||Sub_Regulation}&"_"&
    Paragraph&"_"),
    "_*$",
    "")&
    IF(Record_Type="heading, amendment","_aa")&
    IF(Record_Type="amendment, general","_aa_"&Amendment)&
    IF(Record_Type="amendment, textual","_aa_"&Amendment)&
    IF(Record_Type="heading, modification","_am")&
    IF(Record_Type="modification","_am_"&Amendment)&
    IF(Record_Type="heading, extent","_ae")&
    IF(Record_Type="extent","_ae_"&Amendment)&
    IF(Record_Type="heading, commencement","_c")&
    IF(Record_Type="commencement","_c"&Amendment)