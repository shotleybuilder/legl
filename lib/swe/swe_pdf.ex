defmodule SwePdf do

  @moduledoc """
    Parser for .pdfs published on the following websites:
    https://www.boverket.se
    https://www.elsakerhetsverket.se
    https://www.av.se
    https://www.transportstyrelsen.se

    Use the chrome pdf viewer
  """
    
  @doc """
    https://www.boverket.se
  """
  def pdf(pdf) when pdf == "boverket" do

    {:ok, binary} = File.read(Path.absname(Legl.original))

    # remove page markers and handle lines crossing pages Boverket
    binary = 
        Regex.replace(
            ~r/([\r\n|\n]BFS[ ]\d{4}:\d[\r\n|\n][A-Z]+[ ]\d{1,4}[\r\n|\n]\d+[\r\n|\n])(.)/, 
            binary, "\n\\g{2}")

    # remove the last period of m.m.
    binary = Regex.replace(~r/[ ]m\.m\.$/m, binary, " m,m,")

    # trim front
    binary = Regex.replace(~r/^[ ]/m, binary, "")
    
    # match a chapter heading
    binary = Regex.replace(~r/(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")

    # join headings that span 2 lines
    binary = Regex.replace(~r/^(\d+[ ]§\d*[ ]*)(?:\r\n|\n)([ ]?.)/m, binary, "\\g{1} \\g{2}")

    # match regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,]+)(?:\r\n|\n)(\d+[ ]§\d?)/, binary, "\n🧡\\g{1}\n\\g{2}")

    # match the start of a regulation
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🔴\\g{1}")

    # match sub-regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,\.]+)(?:\r\n|\n)(\d+[ ][a-z][ ]§\d?)/, binary, "\n⛔\\g{1}\n\\g{2}")

    # match a sub-reg
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ][a-z][ ]§\d?)/m, binary, "\n🐽️\\g{1}")

    # match numbered lists
    binary = Regex.replace(~r/(^\d+\.[ ].)/m, binary, "\n\\g{1}")

    # match lettered lists
    binary = Regex.replace(~r/(^[ ]?[a-z]+\)[ ].)/m, binary, "\n\\g{1}")

    # dashed bulleted lists
    binary = Regex.replace(~r/(^\–[ ])/m, binary, "\n\\g{1}")

    # sentances
    binary = Regex.replace(~r/(\.[\r|\r\n])([A-Z])/m, binary, "\\g{1}\n\\g{2}")

    # join sentances
    binary = Regex.replace(~r/([^\.\n])(?:\n|\r\n)([^A-Z💙🧡⛔🔴💡🐽️])/m, binary, "\\g{1} \\g{2}")

    # rm empty lines
    binary = Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")

    # flag bilaga
    binary = Regex.replace(~r/(^Bilaga)/m, binary, "💡\\g{1}")

    # join the regs and bilaga
    binary = Regex.replace(~r/[ \t]*(?:\r\n|\n)([^💙🧡⛔🔴💡🐽️]|\–|”)/m, binary, "📌\\g{1}")

    File.write(Legl.annotated, binary)
  end

  @doc """
    https://www.elsakerhetsverket.se
  """
  def pdf(pdf) when pdf == "elsak" do
      
    {:ok, binary} = File.read(Path.absname("lib/pdf.txt"))

    # remove page markers Elsakerhetsverket
    binary = Regex.replace(~r/^ELSÄK-FS[\r\n|\n]\d{4}:\d+[\r\n|\n]/, binary, "")

    # remove page numbers
    binary = Regex.replace(~r/^\d+(?:\r\n|\n)/m, binary, "")

    # remove the last period of m.m.
    binary = Regex.replace(~r/[ ]m\.m\.$/m, binary, " m,m,")

    # trim front
    binary = Regex.replace(~r/^[ ]/m, binary, "")

    # replace wierd bullet symbol 
    binary = Regex.replace(~r/^\/m, binary, "-")

    # remove the guidance
    binary = Regex.replace(~r/^(GUNNEL FÄRM)(?:\r\n|\n)(Horst Blüchert)(.*)/sm, binary, "\\g{1}\n\\g{2}")
    
    # match a chapter heading
    binary = Regex.replace(~r/\.(?:\r\n|\n)(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")
    binary = Regex.replace(~r/[\d\.](?:\r\n|\n)(^\d+ kap\.[ ]?.*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n\n")

    # join headings that span 2 lines
    binary = Regex.replace(~r/\.(?:\r\n|\n)^(\d+[ ]§\d*[ ]*)(?:\r\n|\n)([ ]?.)/m, binary, "\\g{1} \\g{2}")

    # headings before headings
    binary = Regex.replace(
      ~r/([A-Z].*[^\.])(?:\r\n|\n)([A-Z].*[^\.])(?:\r\n|\n)(\d+[ ]§)/, binary, 
      "💦\\g{1}\n\\g{2}\n\\g{3}"
    )

    # match regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö ,]+)(?:\r\n|\n)(\d+[ ]§\d?)/m, binary, "\n🧡\\g{1}\n\\g{2}")
    binary = Regex.replace(~r/^(Ikraftträdande.*)(?:\r\n|\n)([A-Z])/m, binary, "\n🧡\\g{1}\n🔴\\g{2}")

    # match the start of a regulation
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🔴\\g{1}")

    # match sub-regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,\.]+)(?:\r\n|\n)(\d+[ ][a-z][ ]§\d?)/, binary, "\n⛔\\g{1}\n\\g{2}")

    # match a sub-reg
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ][a-z][ ]§\d?)/m, binary, "\n🐽️\\g{1}")

    # match numbered lists
    binary = Regex.replace(~r/(^\d+\.[ ].)/m, binary, "\n\\g{1}")

    # match lettered lists
    binary = Regex.replace(~r/(^[ ]?[a-z]+\)[ ].)/m, binary, "\n\\g{1}")

    # dashed & bulleted lists
    binary = Regex.replace(~r/(^[\•\–][ ])/m, binary, "\n\\g{1}")

    # sentances
    binary = Regex.replace(~r/(\.[\r|\r\n])([A-Z])/m, binary, "\\g{1}\n\\g{2}")

    # join sentances
    binary = Regex.replace(~r/([^\.\n])(?:\n|\r\n)([^A-Z💙🧡⛔🔴💡🐽️])/m, binary, "\\g{1} \\g{2}")

    # rm empty lines
    binary = Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")

    # flag bilaga
    binary = Regex.replace(~r/(^Bilaga)/m, binary, "💡\\g{1}")

    # join the regs and bilaga
    binary = Regex.replace(~r/[ \t]*(?:\r\n|\n)([^💙🧡⛔🔴💡🐽️]|[\–”\•])/m, binary, "📌\\g{1}")

    File.write("lib/pdf_test.txt", binary)
  end

  @doc """
    https://www.av.se
    remove guidance section from the pasted pdf text
  """
  def pdf(pdf) when pdf == "av" do
      


    {:ok, binary} = File.read(Path.absname("lib/pdf.txt"))

    # remove page markers Elsakerhetsverket
    binary = Regex.replace(~r/^\d+[ ]?(?:\r\n|\n)AFS[ ]\d{4}:\d+[\r\n|\n]?/m, binary, "")
    binary = Regex.replace(~r/^AFS[ ]\d{4}:\d+[\r\n|\n]\d+/m, binary, "")
    binary = Regex.replace(~r/^AFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")
    
    # remove page numbers
    binary = Regex.replace(~r/^\d+(?:\r\n|\n)/m, binary, "")

    # remove the last period of m.m.
    binary = Regex.replace(~r/[ ]m\.m\.$/m, binary, " m,m,")

    # trim front
    binary = Regex.replace(~r/^[ ]/m, binary, "")

    # replace weird bullet symbol 
    binary = Regex.replace(~r/^\/m, binary, "-")
    # replace weird box symbol 
    binary = Regex.replace(~r/^[ ]/m, binary, "")
    
    # match a chapter heading
    binary = Regex.replace(~r/\.(?:\r\n|\n)(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")
    binary = Regex.replace(~r/[\d\.](?:\r\n|\n)(^\d+ kap\.[ ]?.*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n\n")

    # join headings that span 2 lines
    binary = Regex.replace(~r/\.(?:\r\n|\n)^(\d+[ ]§\d*[ ]*)(?:\r\n|\n)([ ]?.)/m, binary, "\\g{1} \\g{2}")

    # headings before headings
    binary = Regex.replace(~r/([A-Z].*[^\.])(?:\r\n|\n)([A-Z].*[^\.])(?:\r\n|\n)(\d+[ ]§)/, binary, "💦\\g{1}\n\\g{2}\n\\g{3}")

    # match regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö ,]+)(?:\r\n|\n)(\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🧡\\g{1}\n\\g{2}")
    binary = Regex.replace(~r/^(Ikraftträdande.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")
    binary = Regex.replace(~r/^(Övergångsbestämmelser.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")

    # match the start of a regulation
    binary = Regex.replace(~r/(?<! kap\.)(?:[\n|\r\n])(^\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🔴\\g{1}")

    # match sub-regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,\.]+)(?:\r\n|\n)(\d+[ ][a-z][ ]§\d?)/, binary, "\n⛔\\g{1}\n\\g{2}")

    # match a sub-reg
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ][a-z][ ]§\d?)/m, binary, "\n🐽️\\g{1}")

    # match numbered lists
    binary = Regex.replace(~r/(^\d+\.[ ].)/m, binary, "\n\\g{1}")

    # match lettered lists
    binary = Regex.replace(~r/(^[ ]?[a-z]+\)[ ].)/m, binary, "\n\\g{1}")

    # dashed & bulleted lists
    binary = Regex.replace(~r/(^[\•\–][ ])/m, binary, "\n\\g{1}")

    # sentances
    binary = Regex.replace(~r/(\.[\r|\r\n])([A-Z])/m, binary, "\\g{1}\n\\g{2}")

    # join sentances
    binary = Regex.replace(~r/([^\.\n])(?:\n|\r\n)([^A-Z💙🧡⛔🔴💡🐽️])/m, binary, "\\g{1} \\g{2}")

    # rm empty lines
    binary = Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")

    # flag bilaga
    binary = Regex.replace(~r/(^Bilaga[ ]\d+\.)/m, binary, "💡\\g{1}")

    # join the regs and bilaga
    binary = Regex.replace(~r/[ \t]*(?:\r\n|\n)([^💙🧡⛔🔴💡🐽️]|[\–”\•])/m, binary, "📌\\g{1}")

    File.write("lib/pdf_test.txt", binary)
  end

  @doc """
    https://www.msb.se
  """
  def pdf(pdf) when pdf == "msb" do

    {:ok, binary} = File.read(Path.absname("lib/pdf.txt"))

    # remove page markers Elsakerhetsverket
    binary = Regex.replace(~r/^MSBFS[ ]*(?:\r\n|\n)+[ ]?\d{4}:\d+(?:\r\n|\n)\d+(?:\r\n|\n)/m, binary, "\n")
    binary = Regex.replace(~r/^MSBFS[ ]\d{4}:\d+[\r\n|\n]\d+/m, binary, "")
    binary = Regex.replace(~r/^MSBFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")
    
    # remove page numbers
    binary = Regex.replace(~r/^\d+(?:\r\n|\n)/m, binary, "")

    # remove the last period of m.m.
    binary = Regex.replace(~r/[ ]m\.m\.$/m, binary, " m,m,")

    # trim front
    binary = Regex.replace(~r/^[ ]/m, binary, "")

    # replace weird bullet symbol 
    binary = Regex.replace(~r/^\/m, binary, "-")
    # replace weird box symbol 
    binary = Regex.replace(~r/^[ ]/m, binary, "")
    
    # match a chapter heading
    binary = Regex.replace(~r/\.(?:\r\n|\n)(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")
    binary = Regex.replace(~r/[\d\.][ ]?(?:\r\n|\n)(^\d+ kap\.[ ]?.*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n\n")

    # join headings that span 2 lines
    binary = Regex.replace(~r/\.(?:\r\n|\n)^(\d+[ ]§\d*[ ]*)(?:\r\n|\n)([ ]?.)/m, binary, "\\g{1} \\g{2}")

    # headings before headings
    binary = Regex.replace(~r/([A-Z].*[^\.])(?:\r\n|\n)([A-Z].*[^\.])(?:\r\n|\n)(\d+[ ]§)/, binary, "💦\\g{1}\n\\g{2}\n\\g{3}")

    # match regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö ,\-]+)(?:\r\n|\n)(\d+[ ]§\d*[ ][^a-z])/mu, binary, "\n🧡\\g{1}\n\\g{2}")
    binary = Regex.replace(~r/^(Ikraftträdande.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")
    binary = Regex.replace(~r/^(Övergångsbestämmelser.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")

    # match the start of a regulation
    binary = Regex.replace(~r/(?<! kap\.)(?:[\n|\r\n])(^\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🔴\\g{1}")

    # match sub-regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,\.]+)(?:\r\n|\n)(\d+[ ][a-z][ ]§\d?)/, binary, "\n⛔\\g{1}\n\\g{2}")

    # match a sub-reg
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ][a-z][ ]§\d?)/m, binary, "\n🐽️\\g{1}")

    # match numbered lists
    binary = Regex.replace(~r/(^\d+\.[ ].)/m, binary, "\n\\g{1}")

    # match lettered lists
    binary = Regex.replace(~r/(^[ ]?[a-z]+\)[ ].)/m, binary, "\n\\g{1}")

    # dashed & bulleted lists
    binary = Regex.replace(~r/(^[\•\–][ ])/m, binary, "\n\\g{1}")

    # sentances
    binary = Regex.replace(~r/(\.[\r|\r\n])([A-Z])/m, binary, "\\g{1}\n\\g{2}")

    # join sentances
    binary = Regex.replace(~r/([^\.\n])(?:\n|\r\n)([^A-Z💙🧡⛔🔴💡🐽️])/m, binary, "\\g{1} \\g{2}")

    # rm empty lines
    binary = Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")

    # flag bilaga
    binary = Regex.replace(~r/(^Bilaga)/m, binary, "💡\\g{1}")

    # join the regs and bilaga
    binary = Regex.replace(~r/[ \t]*(?:\r\n|\n)([^💙🧡⛔🔴💡🐽️]|[\–”\•])/m, binary, "📌\\g{1}")

    File.write("lib/pdf_test.txt", binary)
  end

  @doc """
  STEMFS
    https://www.msb.se
  """
  def pdf(pdf) when pdf == "stemfs" do

    {:ok, binary} = File.read(Path.absname("lib/pdf.txt"))

    # remove page markers Elsakerhetsverket
    binary = Regex.replace(~r/^STEMFS[ ]*(?:\r\n|\n)+[ ]?\d{4}:\d+(?:\r\n|\n)/m, binary, "\n")
    binary = Regex.replace(~r/^STEMFS[ ]\d{4}:\d+[\r\n|\n]\d+/m, binary, "")
    binary = Regex.replace(~r/^STEMFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")
    
    # remove page numbers
    binary = Regex.replace(~r/^\d+(?:\r\n|\n)/m, binary, "")

    # remove the last period of m.m.
    binary = Regex.replace(~r/[ ]m\.m\.$/m, binary, " m,m,")

    # trim front
    binary = Regex.replace(~r/^[ ]/m, binary, "")

    # replace weird bullet symbol 
    binary = Regex.replace(~r/^\/m, binary, "-")
    # replace weird box symbol 
    binary = Regex.replace(~r/^[ ]/m, binary, "")
    
    # match a chapter heading
    binary = Regex.replace(~r/\.(?:\r\n|\n)(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")
    binary = Regex.replace(~r/[\d\.][ ]?(?:\r\n|\n)(^\d+ kap\.[ ]?.*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n\n")

    # join headings that span 2 lines
    binary = Regex.replace(~r/\.(?:\r\n|\n)^(\d+[ ]§\d*[ ]*)(?:\r\n|\n)([ ]?.)/m, binary, "\\g{1} \\g{2}")

    # headings before headings
    binary = Regex.replace(~r/([A-Z].*[^\.])(?:\r\n|\n)([A-Z].*[^\.])(?:\r\n|\n)(\d+[ ]§)/, binary, "💦\\g{1}\n\\g{2}\n\\g{3}")

    # match regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö ,\-]+)(?:\r\n|\n)(\d+[ ]§\d*[ ][^a-z])/mu, binary, "\n🧡\\g{1}\n\\g{2}")
    binary = Regex.replace(~r/^(Ikraftträdande.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")
    binary = Regex.replace(~r/^(Övergångsbestämmelser.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")

    # match the start of a regulation
    binary = Regex.replace(~r/(?<! kap\.)(?:[\n|\r\n])(^\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🔴\\g{1}")

    # match sub-regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,\.]+)(?:\r\n|\n)(\d+[ ][a-z][ ]§\d?)/, binary, "\n⛔\\g{1}\n\\g{2}")

    # match a sub-reg
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ][a-z][ ]§\d?)/m, binary, "\n🐽️\\g{1}")

    # match numbered lists
    binary = Regex.replace(~r/(^\d+\.[ ].)/m, binary, "\n\\g{1}")

    # match lettered lists
    binary = Regex.replace(~r/(^[ ]?[a-z]+\)[ ].)/m, binary, "\n\\g{1}")

    # dashed & bulleted lists
    binary = Regex.replace(~r/(^[\•\–][ ])/m, binary, "\n\\g{1}")

    # sentances
    binary = Regex.replace(~r/(\.[\r|\r\n])([A-Z])/m, binary, "\\g{1}\n\\g{2}")

    # join sentances
    binary = Regex.replace(~r/([^\.\n])(?:\n|\r\n)([^A-Z💙🧡⛔🔴💡🐽️])/m, binary, "\\g{1} \\g{2}")

    # rm empty lines
    binary = Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")

    # flag bilaga
    binary = Regex.replace(~r/(^Bilaga)/m, binary, "💡\\g{1}")

    # join the regs and bilaga
    binary = Regex.replace(~r/[ \t]*(?:\r\n|\n)([^💙🧡⛔🔴💡🐽️]|[\–”\•])/m, binary, "📌\\g{1}")

    File.write("lib/pdf_test.txt", binary)
  end

  @doc """
  https://www.transportstyrelsen.se
  """
  def pdf(pdf) when pdf == "tsfs" do

    {:ok, binary} = File.read(Path.absname("lib/pdf.txt"))

    # remove page markers Elsakerhetsverket
    binary = Regex.replace(~r/^\d+(?:\r\n|\n)TSFS[ ]*\d{4}:\d+(?:\r\n|\n)/m, binary, "\n")
    # TSFS 2010:155
    binary = Regex.replace(~r/^TSFS[ ]\d{4}:\d+(?:\r\n|\n)/m, binary, "")
    binary = Regex.replace(~r/^TSFS[ ]\d{4}:\d+[ ]\d+[\r\n|\n]?/m, binary, "")
    
    # remove page numbers
    binary = Regex.replace(~r/^\d+(?:\r\n|\n)/m, binary, "")

    # remove the last period of m.m.
    binary = Regex.replace(~r/[ ]m\.m\.$/m, binary, " m,m,")

    # trim front
    binary = Regex.replace(~r/^[ ]/m, binary, "")

    # replace weird bullet symbol 
    binary = Regex.replace(~r/^\/m, binary, "-")
    # replace weird box symbol 
    binary = Regex.replace(~r/^[ ]/m, binary, "")
    
    # match a chapter heading
    binary = Regex.replace(~r/\.(?:\r\n|\n)(^Kap\.[ ]\d+[ ].*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n")
    binary = Regex.replace(~r/[\d\.][ ]?(?:\r\n|\n)(^\d+ kap\.[ ]?.*)(?:\r\n|\n)/m, binary, "\n💙\\g{1}\n\n")

    # join headings that span 2 lines
    binary = Regex.replace(~r/\.(?:\r\n|\n)^(\d+[ ]§\d*[ ]*)(?:\r\n|\n)([ ]?.)/m, binary, "\\g{1} \\g{2}")

    # headings before headings
    binary = Regex.replace(~r/([A-Z].*[^\.])(?:\r\n|\n)([A-Z].*[^\.])(?:\r\n|\n)(\d+[ ]§)/, binary, "💦\\g{1}\n\\g{2}\n\\g{3}")

    # match regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö ,\-]+)(?:\r\n|\n)(\d+[ ]§\d*[ ][^a-z])/mu, binary, "\n🧡\\g{1}\n\\g{2}")
    binary = Regex.replace(~r/^(Ikraftträdande.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")
    binary = Regex.replace(~r/^(Övergångsbestämmelser.*)(?:\r\n|\n)([A-Z\d])/um, binary, "\n🧡\\g{1}\n🔴\\g{2}")

    # match the start of a regulation
    binary = Regex.replace(~r/(?<! kap\.)(?:[\n|\r\n])(^\d+[ ]§\d*[ ][^a-z])/m, binary, "\n🔴\\g{1}")

    # match sub-regulation heading
    binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,\.]+)(?:\r\n|\n)(\d+[ ][a-z][ ]§\d?)/, binary, "\n⛔\\g{1}\n\\g{2}")

    # match a sub-reg
    binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ][a-z][ ]§\d?)/m, binary, "\n🐽️\\g{1}")

    # match numbered lists
    binary = Regex.replace(~r/(^\d+\.[ ].)/m, binary, "\n\\g{1}")

    # match lettered lists
    binary = Regex.replace(~r/(^[ ]?[a-z]+\)[ ].)/m, binary, "\n\\g{1}")

    # dashed & bulleted lists
    binary = Regex.replace(~r/(^[\•\–][ ])/m, binary, "\n\\g{1}")

    # sentances
    binary = Regex.replace(~r/(\.[\r|\r\n])([A-Z])/m, binary, "\\g{1}\n\\g{2}")

    # join sentances
    binary = Regex.replace(~r/([^\.\n])(?:\n|\r\n)([^A-Z💙🧡⛔🔴💡🐽️])/m, binary, "\\g{1} \\g{2}")

    # rm empty lines
    binary = Regex.replace(~r/(?:\r\n|\n)+[ ]?(?:\r\n|\n)+/, binary, "\n")

    # flag bilaga
    binary = Regex.replace(~r/(^Bilaga)/m, binary, "💡\\g{1}")

    # join the regs and bilaga
    binary = Regex.replace(~r/[ \t]*(?:\r\n|\n)([^💙🧡⛔🔴💡🐽️]|[\–”\•])/m, binary, "📌\\g{1}")

    File.write("lib/pdf_test.txt", binary)
  end

  def pdf_clean(pdf) do
      
      pdf(pdf)

      {:ok, binary} = File.read(Path.absname(Legl.annotated))
    
      binary
      |> String.replace("💚", "")
      |> String.replace("💡", "")
      |> String.replace("💙", "")
      |> String.replace("⛔", "")
      |> String.replace("🧡", "")
      |> String.replace("⚡", "")
      |> String.replace("🔴", "")
      |> String.replace("💦", "")
      |> String.replace("🐽️", "")
      |> (&(File.write("lib/pdf_new.txt", &1))).()

      {:ok, binary} = File.read(Path.absname(Legl.airtable))
    
      chapter_numbers(binary, pdf)
      article_numbers(binary)
      schemas(binary)
    
  end
  def chapter_numbers(pdf) do
      {:ok, binary} = File.read(Path.absname(Legl.airtable))
      chapter_numbers(binary, pdf)
  end

  def chapter_numbers(binary, pdf) do
      regex = 
        case pdf do
          x when x in ["elsak", "msb"] -> ~r/^(\d+) kap\.[ ]?.*/
          _ -> ~r/^Kap\.\s(\d+)/
        end
      chapters =
        String.split(binary, "\n", trim: true)
        |> Enum.reduce([], fn str, acc ->
          case Regex.run(regex, str) do
            [_match, capture] -> [capture | acc]
            nil ->
              case acc do
                [] -> ["" | acc]
                _ -> [hd(acc) | acc]
              end
          end
        end)
        |> Enum.reverse()
    
      Enum.count(chapters) |> IO.inspect(label: "chapter")
    
      Enum.join(chapters, "\n")
      |> (&(File.write(Legl.chapter, &1))).()
  end

    def schemas() do
        {:ok, binary} = File.read(Path.absname(Legl.annotated))
        schemas(binary)
    end

    def schemas(binary) do
        # First line is always the title
        [_head | tail] = String.split(binary, "\n", trim: true)
        schemas =
          tail
          |> Enum.reduce(%{types: ["title"], sections: [""], section: 0}, fn str, acc ->
            {type, section} =
              cond do
                Regex.match?(~r/^(\d+[ ][a-z]*)[ ]?§[\d| ]/, str) -> {"article", acc.section}
                Regex.match?(~r/^Kap\.\s(\d+)/, str) -> {"chapter", 0}
                Regex.match?(~r/^(\d+) kap\.[ ]?.*/, str) -> {"chapter", 0}
                #Regex.match?(~r/^Boverkets|BOVERKETS/, str) -> {"title", acc.section}
                #Regex.match?(~r/^Elsäkerhetsverkets/, str) -> {"title", acc.section}
                #Regex.match?(~r/^[A-ZÅÄÖ][A-ZÅÄÖ]/u, str) -> {"title", acc.section}
                #Regex.match?(~r/^Arbetsmiljöverkets/, str) -> {"title", acc.section}
                Regex.match?(~r/Bilaga/, str) -> {"notes", acc.section+1}
                true ->
                  case List.first(acc.types) do
                    "notes" ->  {"notes", 0}
                    _ -> {"heading", acc.section+1}
                  end
              end
            str_section =
              case section do
                0 -> ""
                _ -> Integer.to_string(section)
              end
            %{acc | :types => [type | acc.types], :sections => [str_section | acc.sections], :section => section }
          end)
      
        Enum.count(schemas.types) |> IO.inspect(label: "types")
      
        schemas.types
        |> Enum.reverse()
        |> Enum.join("\n")
        |> (&(File.write(Legl.type, &1))).()
      
        schemas.sections
        |> Enum.reverse()
        |> Enum.join("\n")
        |> (&(File.write(Legl.section, &1))).()
    end

    def article_numbers() do
        {:ok, binary} = File.read(Path.absname(Legl.airtable))
        article_numbers(binary)
    end

    def article_numbers(binary) do
        #
        articles =
          String.split(binary, "\n", trim: true)
          |> Enum.reduce([], fn str, acc ->
            case Regex.run(~r/^(\d+[ ][a-z]*)[ ]?§[\d| ]/, str) do
            [_match, capture] ->
            [String.replace(capture, " ", "") | acc]
            nil -> ["" | acc]
            end
          end)
          |> Enum.reverse()
      
        Enum.count(articles) |> IO.inspect(label: "articles")
      
        Enum.join(articles, "\n")
        |> (&(File.write(Legl.article, &1))).()
    end

end