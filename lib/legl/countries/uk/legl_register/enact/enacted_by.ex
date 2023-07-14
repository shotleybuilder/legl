defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy do
  @moduledoc """
  Run as
  Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.run([t: type_code, base_name: "UK S"])
  """

  alias Legl.Countries.Uk.UkAirtable, as: AT

  @new_law_csv ~s[lib/legl/countries/uk/legl_register/enact/new_law.csv]
  @enacted_by_csv ~s[lib/legl/countries/uk/legl_register/enact/enacting.csv]
  @source_path ~s[lib/legl/countries/uk/legl_register/enact/enacted_source.json]
  @enacting_path ~s[lib/legl/countries/uk/legl_register/enact/enacting.json]

  @default_opts %{
    base_name: "UK E",
    type_code: :uksi,
    type_class: nil,
    fields: ["Name", "Title_EN", "type_code", "Year", "Number", "Enacted_by"],
    view: "",
    filesave: true
  }

  @doc """
    opts has this shape

    %{base_name: "UK S", fields: ["Name",
    "Title_EN", "type_code", "Year", "Number", "Enabled by"], files:
    {#PID<0.418.0>, #PID<0.419.0>}, sTypeClass: "Order", sTypeCode: "nisr",
    type_class: :order, type_code: :nisr, view: "Enabled_by"}

  """
  def run(opts \\ []) when is_list(opts) do
    opts = Enum.into(opts, @default_opts)
    opts = type_code(opts)
    opts = type_class(opts)

    # save the file instances into opts
    {new_law_csv, enacted_by_csv} = open_files()
    opts = Map.put(opts, :new_law_csv, new_law_csv)
    opts = Map.put(opts, :enacted_by_csv, enacted_by_csv)

    IO.puts("options #{Enum.each(opts, &IO.puts(inspect(&1)))}")

    # %UKTypeCode is a struct with type_code as atom key and type_code as string value
    # Also, bundles type_codes under country key e.g. ni: ["nia", "apni", "nisi", "nisr", "nisro"]

    case opts.sTypeCode do
      nil ->
        IO.puts("ERROR with type_code option of value nil")

      types when is_list(types) ->
        Enum.each(types, fn type ->
          IO.puts(">>>#{type}")
          get_child_process(opts)
        end)

      type when is_binary(type) ->
        get_child_process(opts)
    end

    File.close(new_law_csv)
    File.close(enacted_by_csv)
  end

  def get_child_process(opts) do
    # return Airtable Legal Register records with empty 'Enabled_by' field
    formula =
      case opts.sTypeClass do
        nil ->
          ~s/AND({type_code}="#{opts.sTypeCode}",{Enacted_by}=BLANK())/

        x ->
          ~s/AND({type_code}="#{opts.sTypeCode}", {type_class}="#{x}" ,{Enacted_by}=BLANK())/
      end

    opts = Map.put(opts, :formula, formula)

    # :ok <- dedupe(new_law_csv),
    # :ok <- dedupe(parents_csv)
    with {:ok, at_records} <- AT.get_records_from_at(opts),
         :ok <- filesave(at_records, @source_path, opts),
         {:ok, results} <-
           Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy.get_enacting_laws(at_records, opts),
         :ok <- filesave(results, @enacting_path, opts) do
      save_enacted_by_to_csv(results, opts)
      save_new_laws_to_csv(results, opts)
      :ok
    else
      {:error, error} ->
        IO.puts("#{error}")

      %{"message" => msg, "type" => type} ->
        IO.puts("ERROR #{type} msg: #{msg}")
    end
  end

  defp open_files() do
    {:ok, new_law_csv} = @new_law_csv |> Path.absname() |> File.open([:utf8, :write, :read])

    IO.puts(new_law_csv, "Name,Title_EN,type_code,Year,Number")

    {:ok, enacted_by_csv} = @enacted_by_csv |> Path.absname() |> File.open([:utf8, :write, :read])

    IO.puts(enacted_by_csv, "Name,Enacted_by")
    {new_law_csv, enacted_by_csv}
  end

  defp type_code(opts) do
    # sets the type_class as a string in opts
    tc =
      case opts.type_code do
        nil ->
          nil

        _ ->
          tc = Map.get(%Legl.Countries.Uk.UkTypeCode{}, opts.type_code)

          case tc do
            nil ->
              IO.puts("ERROR type_class #{opts.type_code} not recognised: setting to nil")
              nil

            x ->
              x
          end
      end

    Map.put(opts, :sTypeCode, tc)
  end

  defp type_class(opts) do
    # sets the type_class as a string in opts
    tc =
      case opts.type_class do
        nil ->
          nil

        _ ->
          tc = Map.get(%Legl.Countries.Uk.UkTypeClass{}, opts.type_class)

          case tc do
            nil ->
              IO.puts("ERROR type_class #{opts.type_class} not recognised: setting to nil")
              nil

            x ->
              x
          end
      end

    Map.put(opts, :sTypeClass, tc)
  end

  defp filesave(records, _, %{filesave: false} = _opts), do: records

  defp filesave(records, path, %{filesave: true} = _opts) do
    json = Map.put(%{}, "records", records) |> Jason.encode!()
    Legl.Utility.save_at_records_to_file(~s/#{json}/, path)
  end

  def save_enacted_by_to_csv(results, opts) do
    Enum.each(results, fn
      %{"id" => id, "fields" => %{Enacted_by: enacted_by}} = _result ->
        IO.puts(opts.enacted_by_csv, "#{id},#{enacted_by}")
    end)
  end

  def save_new_laws_to_csv(results, opts) do
    Enum.reduce(results, [], fn %{enacting_laws: eLaws} = _result, acc ->
      acc ++ eLaws
    end)
    |> Enum.uniq_by(&{&1.id})
    |> new_laws()
    |> Enum.each(&IO.puts(opts.new_law_csv, &1))
  end

  def new_laws(enacting_laws) do
    Enum.reduce(enacting_laws, [], fn law, acc ->
      %{id: id, number: number, title: title, type: type, year: year} = law

      # we have to quote enclose in case title contains commas and quotes
      title =
        Legl.Airtable.AirtableTitleField.title_clean(title)
        |> Legl.Utility.csv_quote_enclosure()

      [~s/#{id},#{title},#{type},#{year},#{number}/ | acc]
    end)
  end
end
