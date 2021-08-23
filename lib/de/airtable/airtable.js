REGEX_REPLACE(DE&" "&
IF(AND(flow="pre", {Article Type}="titel"), "")&
IF(AND(flow="pre", {Article Type}="eingangsformel"),  "_")&
IF(AND(flow="pre", {Article Type}!="titel"),  "_ "&{Article Type})&
IF(OR(flow="",flow="main"),"§ "&
IF(part,part&"_")&
IF(chapter,chapter&"_")&
IF(section,section&"_")&
IF(sub_section,sub_section&"_")&
IF(article,article&"_")&
IF(para,para&"_")&
IF(sub,sub&"_")&
IF({____X_},{____X_}&"_")&
IF(REGEX_MATCH({Article Type}, "fußnote"), "fn")
)&
IF(flow="prov","+"&
IF(part,part&"_")&
IF(chapter,chapter&"_")&
IF(section,section&"_")&
IF(sub_section,sub_section&"_")&
IF(article,article&"_")&
IF(para,para&"_")&
IF(sub,sub&"_")&
IF({____X_},{____X_}&"_")
)&
IF(flow="post"," 🗒 "&
IF(part,part&"_")&
IF(chapter,chapter&"_")&
IF(section,section&"_")&
IF(sub_section,sub_section&"_")&
IF(article,article&"_")&
IF(para,para&"_")&
IF(sub,sub&"_")&
IF({____X_},{____X_}&"_")
)&
IF(AND(flow!="", flow!="main", flow!="pre", flow!="prov", flow!="post"),
" > "&flow&"_"&{Article Type}&
IF(part,"_"&part)&
IF(chapter,chapter&"_")&
IF(section,"_"&section)&
IF(sub_section,"_"&sub_section)&
IF(article,"_"&article)&
IF(para,"_"&para)&
IF(sub,"_"&sub)&
IF({____X_},"_"&{____X_})
),"_$","")
