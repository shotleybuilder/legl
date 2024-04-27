defmodule Legl.Services.Hse.ClientCases do
  def get_hse_cases(page_number) do
    # https://resources.hse.gov.uk/convictions-history/case/case_list.asp?ST=C&EO=LIKE&SN=F&SF=DN&SV=
    # https://resources.hse.gov.uk/convictions-history/case/case_list.asp?PN=1&ST=C&EO=LIKE&SN=F&SF=DN&SV=&SO=ADN

    base_url = ~s|https://resources.hse.gov.uk/convictions-history/case/|

    url = ~s/case_list.asp?PN=#{page_number}ST=C&EO=LIKE&SN=F&SF=DN&SV=/

    Req.new(base_url: base_url, url: url)
    |> Req.Request.append_request_steps(debug_url: debug_url())
    |> Req.request!()
    |> Map.get(:body)
    |> parse_tr()
    |> extract_td()
    |> extract_cases()
  end

  # PRIVATE FUNCTIONS

  defp parse_tr(body) do
    {:ok, document} = Floki.parse_document(body)
    Floki.find(document, "tr")
  end

  defp extract_td(notices) do
    Enum.reduce(notices, [], fn
      {"tr", [], notice}, acc -> [notice | acc]
      _, acc -> acc
    end)
  end

  defp extract_cases(cases) do
    IO.inspect(cases, label: "Cases")
  end

  defp debug_url,
    do: fn request ->
      IO.inspect(URI.to_string(request.url), label: "URL")
      request
    end
end
