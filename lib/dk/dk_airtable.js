REGEX_REPLACE(
DK
&IF(AND({flow}="pre", {Article Type}="titel"),  " _ "&{Article Type})
&IF(AND({flow}="pre", {Article Type}="godkendelse"),  " __ "&{Article Type})
&IF(OR(flow="",flow="main"),
" § "
&IF(part,part&"_")
&IF(chapter,chapter&"_")
&IF(section,section&"_")
&IF(article,article&"_")
&IF(para,para&"_")
&IF(sub,sub&"_")
&IF({____X_},{____X_}&"_"))
&IF({flow}="prov",
"+"
&IF(part,part&"_")
&IF(chapter,chapter&"_")
&IF(section,section&"_")
&IF(article,article&"_")
&IF(para,para&"_")
&IF(sub,sub&"_")
&IF({____X_},{____X_}&"_"))
&IF(  {flow}="post",
" 🗒 "
&IF(part,part&"_")
&IF(chapter,chapter&"_")
&IF(section,section&"_")
&IF(article,article&"_")
&IF(para,para&"_")
&IF({sub},{sub}&"_")
&IF({____X_},{____X_}&"_"))
&IF(AND({flow}!="", {flow}!="main", {flow}!="pre", {flow}!="prov", {flow}!="post"),
" > "&{Article Type}&"_"&{flow}
&IF(part,"_"&part)
&IF(chapter,"_"&chapter)
&IF(section,"_"&section)
&IF(article,"_"&article)
&IF(para,"_"&para)
&IF({sub},"_"&{sub})
&IF({____X_},"_"&{____X_})),
"_$",
"")
