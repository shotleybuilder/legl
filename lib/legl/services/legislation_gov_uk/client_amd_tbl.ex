defmodule Legl.Services.LegislationGovUk.ClientAmdTbl do
  # https://www.poeticoding.com/download-large-files-with-httpoison-async-requests/

  @doc """
    Rtns an AsyncResponse struct with id
    PID used is self() - the iex console

    async response
    receive/1 gets the response msg from HTTPoison
    and works like a <case do end> statement, but runs multiple
    times handling each msg
  """
  def run!(url) do
    case HTTPoison.get!(url, %{}, stream_to: self()) do
      %HTTPoison.AsyncResponse{id: id} -> async_response({id, %{}})
    end
  end

  defp async_response({id, data}) do
    receive do
      # first msg is a status code
      %HTTPoison.AsyncStatus{id: ^id, code: 200} ->
        async_response({id, data})

      %HTTPoison.AsyncStatus{id: ^id, code: 301} ->
        async_response({id, data})

      # %HTTPoison.AsyncStatus{id: ^id, code: 307} ->
      #  async_response({id, data})

      %HTTPoison.AsyncStatus{id: ^id, code: 404} ->
        {:error, 404, "No resource"}

      %HTTPoison.AsyncStatus{id: ^id, code: code} ->
        {:error, code, "Other response code"}

      # then the headers in the HTTPoison AsyncHeaders struct
      %HTTPoison.AsyncHeaders{id: ^id, headers: headers} ->
        ct = headers |> Map.new() |> content_type?()
        data = Map.merge(data, %{content_type: ct, body: ""})
        async_response({id, data})

      %HTTPoison.AsyncRedirect{id: ^id, headers: headers, to: to} ->
        ct =
          headers
          |> Map.new()
          |> content_type?()

        data = Map.merge(data, %{content_type: ct, to: to})
        async_response({id, data})

      # then the content in the AsyncChunk struct
      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        async_response({id, %{data | body: data.body <> chunk}})

      # pass back the data when the end msg is received
      %HTTPoison.AsyncEnd{id: ^id} ->
        {:ok, %{content_type: data.content_type, body: data.body}}
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
