defmodule Legl.Services.Airtable.AirtableParams do
  defstruct [
    :base,
    :table,
    :record,
    :table_name,
    data: "",
    env: :dev,
    media: "json",
    options: []
  ]
  # implied default value of nil

  alias __MODULE__ # so we can use the struct here
  import Legl.Services.Airtable.AtFields
  import Legl.Services.Airtable.AtFormulas
  import Legl.Services.Airtable.AtViews


  def params_validation(%{"media" => media})
    when media not in ["json", "md", "html", "pdf"] do
    {:error, "Media not one of json, md, html or pdf"}
  end

  def params_validation(params) do
    cond do

      Map.has_key?(params, "base_name") == true ->
        case Legl.Services.Airtable.AtBases.get_base_id(params["base_name"]) do
          {:ok, base_id} ->
            Map.put(params, "base", base_id)
            |> Map.pop("base_name")
            |> elem(1)
            |> params_validation()
          _ ->
            {:error,
            "Client app has not been configured for the base name: #{params["base_name"]}"}
        end

      Map.has_key?(params, "base") == false ->
        {:error, "No base name given. URL should contain the Base ID number."}

      String.starts_with?( params["base"], "app" ) == false ->
        {:error, "Not a valid Airtable Base ID number."}

      Map.has_key?(params, "table_name_validated?") == false ->
        #app uses snake case plan names, let's convert first

        case Legl.Services.Airtable.AtTables.get_table_id(
          params["base"], params["table_name"]
          ) do
          {:ok, table_id} ->
            Map.put(params, "table", table_id)
            |> Map.put("table_name_validated?", true)
            #|> Map.pop("table_name")
            #|> elem(1)
            |> params_validation()
          {:error, error} -> {:error, error}
          _ ->
            {:error, "Client app has not been configured with the plan name:
            #{params["table_name"]}"}
        end

      Map.has_key?(params, "table") == false ->
        {:error, "No table name given. URL should contain: table=[table name]."}

      String.starts_with?(params["table"], "tbl" ) == false ->
        {:error, "#{params["table"]} is not a valid Airtable table ID number."}

      true ->
        {:ok, params}
    end
  end


 def params_defaults(params) do
   params =
     Enum.into(params, %{}, fn {key, value} ->
       { String.to_atom(key), value }
     end)
   Map.merge( %AirtableParams{}, params)
   |> Map.put(:env, Mix.env())
   |> options()
   |> (&{:ok, &1}).()
 end

 defp options(%{hse_processes: _} = params) do
   options_with_formula(params)
 end

 defp options(%{schema: _} = params) do
   options_with_formula(params)
 end

 defp options(params) do
   fields =
     at_fields(params)
   view =
     at_views(params)
   Map.put(params, :options, [ view: view, fields: fields])
 end

 defp options_with_formula(params) do
   fields =
     at_fields(params)
   view =
     at_views(params)
   formula =
     hseplan_formula(params)
   Map.put(params, :options, [ view: view, fields: fields,  formula: formula])
 end
end
