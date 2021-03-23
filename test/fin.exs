defmodule FIN.Test do
  use ExUnit.Case

  describe "FIN.Parser.parser/1" do
    test "rm_header/1" do
      binary = ~s"""

      Finlex ®

          Suomeksi
          På svenska
          In English

          Etusivu
          Lainsäädäntö
          Oikeuskäytäntö
          Viranomaiset
          Valtiosopimukset
          Hallituksen esitykset
          Julkaisut

      Hae aineistosta

      Haussa katkaisumerkki *, esim. opintotu* ja takaisinpe*. Laveampi haku tai-sanalla, esim. avopuol* tai aviopuol*. Kokeile myös tarkennettua hakua ja asiasanastoa. Katso ohjeet.
      Finlex › Lainsäädäntö › Ajantasainen lainsäädäntö › Vuosi 2016 › 29.12.2016/1548
      29.12.2016/1548
      Dokumentin versiot

          Viitetiedot
          På svenska

      Valtioneuvoston asetus painelaitteista

      Katso tekijänoikeudellinen huomautus käyttöehdoissa.
      """

      s = FIN.Parser.rm_header(binary)
      assert s == ""
    end

    test "get_chapter/1" do
      binary = ~s"""
      1 luku
      Yleiset säännökset
      1 §
      Soveltamisala
      """

      s = FIN.Parser.get_chapter(binary)

      assert s ==
               ~s/#{Legl.chapter_emoji()}1 luku Yleiset säännökset\n1 §\nSoveltamisala\n/
    end

    test "get_article/1" do
      binary = ~s"""
      2 §
      Soveltamisalan rajaukset
      Tämän asetuksen soveltamisalaan eivät kuulu:
      """

      s = FIN.Parser.get_article(binary)

      assert s ==
               ~s/#{Legl.article_emoji()}2 § Soveltamisalan rajaukset\nTämän asetuksen soveltamisalaan eivät kuulu:\n/
    end
  end
end
