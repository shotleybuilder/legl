defmodule Legl.Countries.Uk.LeglArticle.Article.ArticleTest do
  # mix test test/legl/countries/uk/legl_article/article/article_test.exs
  use ExUnit.Case

  # alias Legl.Countries.Uk.LeglArticle.Article

  describe "Legl.Services.LegislationGovUk.RecordGeneric" do
    test "!=made article/1" do
      url = Legl.Services.LegislationGovUk.Url.article_url("UK_uksi_1992_2793")
      response = Legl.Services.LegislationGovUk.RecordGeneric.article(url)
      assert {:ok, _, false} = response
    end

    test "==made article/1" do
      url = Legl.Services.LegislationGovUk.Url.article_url("UK_uksi_1989_682")
      response = Legl.Services.LegislationGovUk.RecordGeneric.article(url)
      assert {:ok, _, true} = response
    end

    test ".pdf article/1" do
      url = Legl.Services.LegislationGovUk.Url.article_url("UK_nisr_1982_429")
      response = Legl.Services.LegislationGovUk.RecordGeneric.article(url)
      assert {:ok, _, true} = response
    end
  end

  describe "UK LAT" do
    test "original ONLY" do
      result = UK.lat(selection: 0, Name: "UK_uksi_1992_2793", workflow_selection: 0)
      assert is_binary(result)
      IO.inspect(result, limit: :infinity)
    end

    test "original & clean" do
      result = UK.lat(selection: 0, Name: "UK_uksi_1992_2793", workflow_selection: 1, html?: true)
      assert is_binary(result)
      IO.inspect(result, limit: :infinity)
    end

    test "original, clean, parse" do
      result =
        UK.lat(
          selection: 0,
          Name: "UK_uksi_1992_2793",
          workflow_selection: 2,
          html?: true,
          type: :regulation,
          pbs?: false
        )

      assert is_binary(result)
      IO.inspect(result, limit: :infinity)
    end

    test "original, clean, parse, airtable" do
      result =
        UK.lat(
          selection: 0,
          Name: "UK_uksi_1992_2793",
          workflow_selection: 3,
          html?: true,
          type: :regulation,
          pbs?: false,
          country: :uk
        )

      assert is_list(result)
      [hd | _] = result
      IO.inspect(hd, limit: :infinity)
    end

    test "original, clean, parse, airtable, taxa" do
      result =
        UK.lat(
          selection: 0,
          Name: "UK_uksi_1992_2793",
          workflow_selection: 4,
          html?: true,
          type: :regulation,
          pbs?: false,
          country: :uk,
          taxa_workflow_selection: 0
        )

      assert is_list(result)
      [hd | _] = result
      IO.inspect(hd, limit: :infinity)
    end
  end
end
