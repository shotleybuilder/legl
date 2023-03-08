# mix test test/legl/countries/uk/uk_leg_gov_uk_properties_test.exs:25

defmodule Legl.Countries.Uk.UkLegGovUkPropertiesTest do
  use ExUnit.Case
  import Legl.Countries.Uk.UkLegGovUkProperties

  @record %Legl.Services.LegislationGovUk.Record{
    metadata: %{
      description: "This Order consolidates the Air Navigation (No. 2) Order 1995, as amended. In addition to some minor drafting amendments the following new provisions are added.",
      images: '3',
      modified: "2017-01-10",
      paras_total: '254',
      paras_body: '134',
      paras_schedule: '120',
      paras_attachment: '0',
      pdf_href: "http://www.legislation.gov.uk/uksi/2000/1562/introduction/made/data.pdf",
      si_code: "CIVIL AVIATION",
      subject: ["public transport", "air transport", "dangerous animal licences",
      "traffic management", "navigation"],
      title: "The Air Navigation Order 2000"
    }
  }

  describe "get from legislation.gov.uk" do
    test "get_properties_from_legislation_gov_uk/1" do
      url =
        "/uksi/2000/1562/introduction/made/data.xml"
      resp = get_properties_from_legislation_gov_uk(url)
      assert is_map(resp)
      assert %{
        paras_total: 254,
        modified: "10/01/2017"
      } = resp

    end
  end
end
