defmodule Legl.Countries.Uk.AirtableAmendment.UkArticleAmendmentTest do
  use ExUnit.Case
  import Legl.Countries.Uk.AirtableAmendment.Amendments

  @path "test/legl/countries/uk/airtable_amendment/test_data.csv"

  # mix test test/legl/countries/uk/airtable_amendment/uk_article_amendment_test.exs:6

  describe "load_source_records/1" do
    test "loads the csv" do
      {:ok, result} = load_source_records(@path)
      result = result |> Enum.take(1)

      assert result ==
               [
                 %{
                   amendment: "",
                   changes: "",
                   chapter: "",
                   dupe: "",
                   flow: "pre",
                   heading: "",
                   id: "UK_ukpga_1996_8_FA_____",
                   name: "UK_ukpga_1996_8_FA",
                   para: "",
                   part: "",
                   record_type: "title",
                   region: "",
                   section: "",
                   sub_section: "",
                   text:
                     " Finance Act 1996 📌 1996 CHAPTER 8 📌 An Act to grant certain duties, to alter other duties, and to amend the law relating to the National Debt and the Public Revenue, and to make further provision in connection with Finance. 📌 [29th April 1996] 📌 Most Gracious Sovereign, 📌 We, Your Majesty’s most dutiful and loyal subjects, the Commons of the United Kingdom in Parliament assembled, towards raising the necessary supplies to defray Your Majesty’s public expenses, and making an addition to the public revenue, have freely and voluntarily resolved to give and grant unto Your Majesty the several duties hereinafter mentioned; and do therefore most humbly beseech Your Majesty that it may be enacted, and be it enacted by the Queen’s most Excellent Majesty, by and with the advice and consent of the Lords Spiritual and Temporal, and Commons, in this present Parliament assembled, and by the authority of the same, as follows—"
                 }
               ]
    end
  end

  describe "amendments/1" do
    test "creates the amendment records" do
      {:ok, records} = load_source_records(@path)
      {:ok, result} = amendments(records)
      result = result |> Enum.take(3)

      assert result ==
               [
                 F1: %Legl.Countries.Uk.AirtableAmendment.Amendments{
                   ef: "F1",
                   ids: [],
                   text:
                     "F1 S. 4(4) (5) repealed (retrospective to 6pm on 7.3.2001) by 2001 c. 9, Ss. 2(5), 110, Sch. 33 Pt. 1(1)"
                 },
                 F2: %Legl.Countries.Uk.AirtableAmendment.Amendments{
                   ef: "F2",
                   ids: [],
                   text:
                     "F2 S. 5(5) omitted (retrospective to 1.4.2008) by virtue of Finance Act 2008 (c. 9), Sch. 5 paras. 25(b), 26(b)"
                 }
               ]
    end
  end

  describe "amendment_relationships/2" do
    test "builds associations between Articles and Amendments" do
      {:ok, source_records} = load_source_records(@path)
      {:ok, amendments} = amendments(source_records)
      {:ok, result} = amendment_relationships(source_records, amendments)

      assert result ==
               %{
                 F1: %Legl.Countries.Uk.AirtableAmendment.Amendments{
                   ef: "F1",
                   text:
                     "F1 S. 4(4) (5) repealed (retrospective to 6pm on 7.3.2001) by 2001 c. 9, Ss. 2(5), 110, Sch. 33 Pt. 1(1)",
                   ids: ["UK_ukpga_1996_8_FA_1__4_4_5__UK", "UK_ukpga_1996_8_FA_1__4_4_4__UK"]
                 },
                 F2: %Legl.Countries.Uk.AirtableAmendment.Amendments{
                   ef: "F2",
                   text:
                     "F2 S. 5(5) omitted (retrospective to 1.4.2008) by virtue of Finance Act 2008 (c. 9), Sch. 5 paras. 25(b), 26(b)",
                   ids: ["UK_ukpga_1996_8_FA_1__4_5_5__UK"]
                 }
               }
    end
  end
end
