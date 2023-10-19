defmodule Legl.Services.LegislationGovUk.ClientGeneric do
  def run!(url, parser) do
    case HTTPoison.get!(url, %{}, stream_to: self()) do
      %HTTPoison.AsyncResponse{id: id} ->
        async_response({id, %{}}, parser)
    end
  end

  defp async_response({id, data}, parser) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: 200} ->
        async_response({id, data}, parser)

      %HTTPoison.AsyncStatus{id: ^id, code: 301} ->
        async_response({id, data}, parser)

      %HTTPoison.AsyncStatus{id: ^id, code: 404} ->
        {:error, 404, "resource not found"}

      %HTTPoison.AsyncStatus{id: ^id, code: code} ->
        {:error, code, "other response"}

      %HTTPoison.AsyncHeaders{id: ^id, headers: headers} ->
        ct =
          headers
          |> Map.new()
          |> content_type?()

        data = Map.merge(data, %{content_type: ct, body: ""})
        async_response({id, data}, parser)

      %HTTPoison.AsyncRedirect{id: ^id, headers: headers, to: to} ->
        ct = headers |> Map.new() |> content_type?()
        data = Map.merge(data, %{content_type: ct, to: to})
        async_response({id, data}, parser)

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        data.content_type
        |> case do
          :xml ->
            c_state = {id, %{data | body: data.body <> chunk}}

            {:ok, acc_out, _} =
              :erlsom.parse_sax(chunk, nil, parser, [
                {:continuation_function, &async_response/2, c_state}
              ])

            {:ok, %{content_type: :xml, body: acc_out}}

          _ ->
            async_response({id, %{data | body: data.body <> chunk}}, parser)
        end

      %HTTPoison.AsyncEnd{id: ^id} ->
        {:ok, %{content_type: data.content_type, body: data.body}}
    end
  end

  defp async_response(tail, {id, data}) do
    receive do
      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        {<<tail::binary, chunk::binary>>, {id, %{data | body: data.body <> chunk}}}

      %HTTPoison.AsyncEnd{id: ^id} ->
        {tail, {id, data}}
    end
  end

  defp content_type?(%{"Content-Type" => "application/xhtml+xml;charset=utf-8"}),
    do: :xhtml

  defp content_type?(%{"Content-Type" => "text/html;charset=utf-8"}),
    do: :html

  defp content_type?(%{"Content-Type" => "text/html"}),
    do: :html

  defp content_type?(%{"Content-Type" => "application/xml;charset=utf-8"}),
    do: :xml

  defp content_type?(%{"Content-Type" => "application/atom+xml;charset=utf-8"}),
    do: :atom
end
