defmodule SwePdf do
    
    def swe_pdf_test do

        # firefox pdf viewer

        {:ok, binary} = File.read(Path.absname("lib/pdf.txt"))

        # rm page markers and join lines
        binary = Regex.replace(~r/([\r\n|\n]?BFS[ ]\d{4}:\dH[ ]\d{4}[ ])/, binary, " ")

        # match a chapter heading
        binary = Regex.replace(~r/(Kap\.[ ]\d+[ ])/, binary, "\n\\g{1}")

        # match regulation heading
        binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,]+\d+[ ]§\d?[ ]{4,})/, binary, "\n\\g{1}")

        # match the start of a regulation
        binary = Regex.replace(~r/(\d+[ ]§\d?[ ]{4,})/, binary, "\n\\g{1}")

        # match a sub-reg
        binary = Regex.replace(~r/(\d[ ][a-z][ ]§\d[ ]{4})/, binary, "\n\\g{1}")

        File.write("lib/pdf_new.txt", binary)
    end

    def pdf do
        
        # chrome pdf viewer

        {:ok, binary} = File.read(Path.absname("lib/pdf.txt"))

        # remove page markers and join lines crossing pages
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

        # match regulation heading
        binary = Regex.replace(~r/([A-Z]{1}[a-zåäö\s,]+)(?:\r\n|\n)(\d+[ ]§\d?)/, binary, "\n🧡\\g{1}\n\\g{2}")

        # match the start of a regulation
        binary = Regex.replace(~r/(?<!kap\.)(?:[\n|\r\n])(^\d+[ ]§\d?)/m, binary, "\n🔴\\g{1}")

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

        File.write("lib/pdf_new.txt", binary)
    end

end