defmodule Legl.Services.LegislationGovUk.RecordGeneric do
  @endpoint "https://www.legislation.gov.uk"

  @enact &Legl.Services.LegislationGovUk.Parsers.EnactingText.sax_event_handler/2
  @extent &Legl.Services.LegislationGovUk.Parsers.ParserExtent.sax_event_handler/2
  @revoke &Legl.Services.LegislationGovUk.Parsers.ParserRevoke.sax_event_handler/2

  def enacting_text(url) do
    case Legl.Services.LegislationGovUk.ClientGeneric.run!(@endpoint <> url, @enact) do
      {:ok, %{:content_type => :xml, :body => %{acc: acc}}} ->
        {:ok, :xml, acc}

      {:ok, %{:content_type => :html}} ->
        {:ok, :html}

      {:error, code, error} ->
        {:error, code, error}
    end
  end

  def extent(url) do
    case Legl.Services.LegislationGovUk.ClientGeneric.run!(@endpoint <> url, @extent) do
      {:ok, %{:content_type => :xml, :body => %{acc: acc}}} ->
        {:ok, :xml, acc}

      {:ok, %{:content_type => :html}} ->
        {:ok, :html}

      {:error, code, error} ->
        {:error, code, error}
    end
  end

  def revoke(url) do
    case Legl.Services.LegislationGovUk.ClientGeneric.run!(@endpoint <> url, @revoke) do
      {:ok, %{:content_type => :xml, :body => %{acc: acc}}} ->
        {:ok, :xml, acc}

      {:ok, %{:content_type => :html}} ->
        {:ok, :html}

      {:error, code, error} ->
        {:error, code, error}
    end
  end

  def leg_gov_uk_html(path, client, parser) do
    with(
      url = @endpoint <> path,
      # IO.puts("HTML URL: #{url}"),
      {:ok, %{:content_type => :html, :body => body}} <- client.(url),
      {:ok, response} <- parser.(body)
      # IO.inspect(response, label: "HTML CONTENT: ")
    ) do
      {:ok, response}
    else
      :no_records -> :no_records
      {:error, code, response} -> {:error, code, path, response}
    end
  end
end
