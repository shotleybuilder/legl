UK&
IF({flow}="pre","+"&
IF(chapter,chapter&"_")&
IF(sub_chapter,sub_chapter&"_")&
IF(section,section&"_")&
IF(article,article&"_")&
IF(sub,sub&"_"))&
IF(OR(flow="",flow="main"),
IF(part, "_"&part)&
IF(chapter,"_"&chapter)&
IF(sub_chapter,"_"&sub_chapter)&
IF(section,"_"&section)&
IF(article,"_"&article)&
IF(para, "_"&para)&
IF(sub,"_"&sub))&
IF(flow="post","-")&
IF(REGEX_MATCH(flow, "1|2|3|4|5|6|7|8|9|0"),"-"&flow&
IF(part, "_"&part)&
IF(chapter,"_"&chapter)&
IF(sub_chapter,"_"&sub_chapter)&
IF(section,"_"&section)&
IF(article,"_"&article)&
IF(para, "_"&para)&
IF(sub,"_"&sub))