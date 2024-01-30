defmodule Legl.Countries.Uk.LeglRegister.EnactTest do
  # mix test test/legl/countries/uk/legl_register/enact_test.exs:8
  use ExUnit.Case

  alias Legl.Countries.Uk.LeglRegister.LegalRegister, as: LR
  alias Legl.Services.LegislationGovUk.RecordGeneric, as: GOV
  alias Legl.Services.LegislationGovUk.Url, as: URL
  alias Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy

  @record [
    %{
      record: %LR{
        Title_EN:
          "Health Protection (Coronavirus Restrictions and Functions of Local Authorities) (Amendment) (Wales) Regulations",
        type_code: "wsi",
        Year: 2020,
        Number: "1409"
      },
      result: %{
        url: ~s[/wsi/2020/1409/introduction/data.xml],
        intro: %{enacting_text: nil, introductory_text: "", urls: %{"c24417001" => nil}}
      }
    },
    %{
      record: %LR{
        Title_EN:
          "Health Protection (Coronavirus, International Travel and Public Health Information) (England) (Amendment) Regulations",
        type_code: "uksi",
        Year: 2020,
        Number: "691"
      },
      result: %{
        url: "/uksi/2020/691/introduction/data.xml",
        intro: %{
          enacting_text:
            "The Secretary of State makes the following Regulations in exercise of the powers conferred by sections 45B, 45F(2) and 45P(2) of the Public Health (Control of Disease) Act 1984  c24187071.",
          introductory_text: "",
          urls: %{
            "c24187071" => [
              "http://www.legislation.gov.uk/id/ukpga/1984/22",
              "http://www.legislation.gov.uk/id/ukpga/2008/14"
            ]
          }
        },
        text: %GetEnactedBy.Enact{
          enacting_laws: [],
          enacting_text:
            "The Secretary of State makes the following Regulations in exercise of the powers conferred by sections 45B, 45F(2) and 45P(2) of the Public Health (Control of Disease) Act 1984  c24187071.",
          introductory_text: "",
          text:
            "The Secretary of State makes the following Regulations in exercise of the powers conferred by sections 45B, 45F(2) and 45P(2) of the Public Health (Control of Disease) Act 1984  c24187071.",
          urls: %{
            "c24187071" => [
              "http://www.legislation.gov.uk/id/ukpga/1984/22",
              "http://www.legislation.gov.uk/id/ukpga/2008/14"
            ]
          }
        },
        match: %GetEnactedBy.Enact{
          enacting_laws: ["UK_ukpga_1984_22"],
          enacting_text:
            "The Secretary of State makes the following Regulations in exercise of the powers conferred by sections 45B, 45F(2) and 45P(2) of the Public Health (Control of Disease) Act 1984  c24187071.",
          introductory_text: "",
          text:
            "The Secretary of State makes the following Regulations in exercise of the powers conferred by sections 45B, 45F(2) and 45P(2) of the Public Health (Control of Disease) Act 1984  c24187071.",
          urls: %{
            "c24187071" => [
              "http://www.legislation.gov.uk/id/ukpga/1984/22",
              "http://www.legislation.gov.uk/id/ukpga/2008/14"
            ]
          }
        }
      }
    },
    %{
      record: %LR{
        Title_EN:
          "Health Protection (Coronavirus, Restrictions) (No. 3) and (All Tiers) (England) (Amendment) Regulations",
        type_code: "uksi",
        Year: 2021,
        Number: "8"
      },
      result: %{
        url: ~s[/wsi/2020/1409/introduction/data.xml],
        intro: %{enacting_text: nil, introductory_text: "", urls: %{"c24417001" => nil}},
        enacted_by: "UK_ukpga_1984_22"
      }
    }
  ]

  setup do
    {:ok, Enum.at(@record, 2)}
  end

  describe "Legl.Services.LegislationGovUk.Url" do
    test "introduction_path/1", %{record: record, result: result} do
      url = URL.introduction_path(record)
      assert result.url == url
    end
  end

  describe "Legl.Services.LegislationGovUk.RecordGeneric" do
    test "enacting_text/1", %{record: record, result: result} do
      url = URL.introduction_path(record)
      intro = GOV.enacting_text(url)

      assert {:ok, :xml, intro} = intro

      assert result.intro == intro
      IO.inspect(intro)
    end
  end

  describe "Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy" do
    test "get_leg_gov_uk/1" do
      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(@record)

      assert %{
               enacting_text: "The Welsh Ministers" <> _,
               introductory_text: "",
               urls: %{
                 "c24417001" => [
                   "http://www.legislation.gov.uk/id/ukpga/1984/22",
                   "http://www.legislation.gov.uk/id/ukpga/2008/14"
                 ]
               }
             } = response

      IO.inspect(response, limit: :infinity, pretty: true)
    end

    test "text/1", %{record: record, result: result} do
      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(record)

      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.text(response)

      assert result.text == response
    end

    test "e_regexes/0" do
      e_regexes = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.e_regexes()
      assert is_list(e_regexes)
      [hd | _] = e_regexes

      assert {{"Planning Act", "ukpga", "2008", "29"},
              ~r/in exercise of the powers.*?(?: in)? sections?.*? of(?: the)? Planning Act 2008/} =
               hd

      IO.inspect(e_regexes)
    end

    test "s_regexes/0" do
      s_regexes = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.s_regexes()
      assert is_list(s_regexes)
      [hd | _] = s_regexes

      assert {{"Northern Ireland Act", "ukpga", "2000", "1"},
              ~r/powers conferred by paragraph.*?Schedule.*?to the[ ]+Northern Ireland Act 2000/} =
               hd

      IO.inspect(s_regexes)
    end

    test "specific_enacting_clauses/1", %{record: record, result: result} do
      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(record)

      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.text(response)

      {:ok, response} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.specific_enacting_clauses(response)

      assert result.text == response

      IO.inspect(response)
    end

    test "enacting_law_in_match/1", %{record: record, result: result} do
      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(record)

      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.text(response)

      {:ok, response} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.enacting_law_in_match(response)

      assert result.match == response

      IO.inspect(response)
    end

    test "get_urls/2" do
      {:ok, _record, %{enacting_text: enacting_text, urls: urls}} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(@record)

      IO.inspect(urls, label: "URLS")
      IO.inspect(enacting_text, label: "TEXT")

      {:ok, url_set} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_urls(urls, enacting_text)

      assert [
               "http://www.legislation.gov.uk/id/ukpga/1984/22",
               "http://www.legislation.gov.uk/id/ukpga/2008/14"
             ] = url_set
    end

    test "match_on_year/2" do
      {:ok, _record, %{enacting_text: enacting_text, urls: urls}} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(@record)

      {:ok, url_set} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_urls(urls, enacting_text)

      {:ok, url_matches} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.match_on_year(url_set, enacting_text)

      assert ["http://www.legislation.gov.uk/id/ukpga/1984/22"] = url_matches
    end

    test "enacting_laws/1" do
      {:ok, _record, %{enacting_text: enacting_text, urls: urls}} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(@record)

      {:ok, url_set} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_urls(urls, enacting_text)

      {:ok, url_matches} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.match_on_year(url_set, enacting_text)

      {:ok, enacting_laws} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.enacting_laws(url_matches)

      assert ["UK_ukpga_1984_22"] = enacting_laws
    end

    test "enacting_law_in_enacting_text/1" do
      {:ok, response} = Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_leg_gov_uk(@record)

      {:ok, %{enacting_laws: enacting_laws}} =
        Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.enacting_law_in_enacting_text(response)

      assert ["UK_ukpga_1984_22"] = enacting_laws
    end

    test "enacted_by/1" do
      name = ExPrompt.get("Name")
      [_, type_code, year, number] = String.split(name, "_")
      record = %{type_code: type_code, Year: year, Number: number}

      with(
        {:ok, enact} <- GetEnactedBy.get_leg_gov_uk(record),
        {:ok, enact} <- GetEnactedBy.text(enact),
        {:ok, enact} <-
          GetEnactedBy.specific_enacting_clauses(enact) |> IO.inspect(label: "SPEC ENACT CLAUSES"),
        {:ok, enact} <-
          GetEnactedBy.enacting_law_in_match(enact) |> IO.inspect(label: "ENACT LAW IN MATCH"),
        {:ok, enact} <-
          GetEnactedBy.enacting_law_in_enacting_text(enact)
          |> IO.inspect(label: "ENACT LAW IN ENACT TEXT"),
        {:ok, record} <- GetEnactedBy.enacted_by(enact, record)
      ) do
        # assert record."Enacted_by" == result.enacted_by
        IO.inspect(record."Enacted_by", limit: :infinity, pretty: true)
      end
    end

    test "enacted_by_description/1", %{record: record, result: _result} do
      with(
        {:ok, enact} <- GetEnactedBy.get_leg_gov_uk(record),
        {:ok, enact} <- GetEnactedBy.text(enact),
        {:ok, enact} <- GetEnactedBy.specific_enacting_clauses(enact),
        {:ok, enact} <- GetEnactedBy.enacting_law_in_match(enact),
        {:ok, enact} <- GetEnactedBy.enacting_law_in_enacting_text(enact),
        {:ok, record} <- GetEnactedBy.enacted_by(enact, record),
        {:ok, record} <- GetEnactedBy.enacted_by_description(enact, record)
      ) do
        assert record.enacted_by_description ==
                 "UK_ukpga_1984_22\nPublic Health (Control of Disease) Act 1984\nhttps://legislation.gov.uk/ukpga/1984/22/introduction/data.xml"

        IO.inspect(record.enacted_by_description, limit: :infinity, pretty: true)
      end
    end

    test "get_enacting_laws/2" do
      {:ok, record} = GetEnactedBy.get_enacting_laws(@record)
      IO.inspect(record."Enacted_by", limit: :infinity, pretty: true)
      IO.inspect(record.enacted_by_description, limit: :infinity, pretty: true)
    end
  end
end
