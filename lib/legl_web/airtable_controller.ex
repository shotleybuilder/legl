defmodule LeglWeb.AirtableController do
  #   use LeglWeb, :controller
  #   alias Legl.AirtableRecords, as: Records

  #   @json_file Path.relative_to("./test/legl/services/factory/at.json", __DIR__)

  #   def records(conn, %{media: "json", data: "file"} = params) do
  #     {:ok, {jsonset, _}, _} = Records.run(params)
  #     jsonset
  #     |> Stream.into(File.stream!(@json_file))
  #     |> Stream.run()
  #     text(conn, ".json saved to #{@json_file}")
  #   end
  # end
end
