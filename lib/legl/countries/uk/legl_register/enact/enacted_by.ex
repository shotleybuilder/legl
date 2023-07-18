defmodule Legl.Countries.Uk.LeglRegister.Enact.EnactedBy do
  @moduledoc """
  Run as
  Legl.Countries.Uk.LeglRegister.Enact.EnactedBy.run([t: type_code, base_name: "UK S"])
  """

  alias Legl.Countries.Uk.UkAirtable, as: AT
  alias Legl.Countries.Uk.UkTypeClass, as: TypeClass
  alias Legl.Countries.Uk.UkTypeCode, as: TypeCode

  @new_law_csv ~s[lib/legl/countries/uk/legl_register/enact/new_law.csv] |> Path.absname()
  @enacted_by_csv ~s[lib/legl/countries/uk/legl_register/enact/enacting.csv] |> Path.absname()
  @source_path ~s[lib/legl/countries/uk/legl_register/enact/enacted_source.json]
  @enacting_path ~s[lib/legl/countries/uk/legl_register/enact/enacting.json]

  @default_opts %{
    # a new value for the Enacted_by field ie the cells are blank
    new?: true,
    # target single record Enacted_by field by providing the Name (key/ID)
    name: "",
    # set this as an option or get an error!
    base_name: "",
    type_code: [""],
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

    opts =
      with {:ok, type_code} <- TypeCode.type_code(opts.type_code),
           {:ok, type_class} <- TypeClass.type_class(opts.type_class),
           {new_law_csv, enacted_by_csv} = open_files() do
        Map.merge(
          opts,
          %{
            type_class: type_class,
            type_code: type_code,
            new_law_csv: new_law_csv,
            enacted_by_csv: enacted_by_csv
          }
        )
      else
        {:error, error} ->
          IO.puts("ERROR: #{error}")
      end

    # %UKTypeCode is a struct with type_code as atom key and type_code as string value
    # Also, bundles type_codes under country key e.g. ni: ["nia", "apni", "nisi", "nisr", "nisro"]

    Enum.each(opts.type_code, fn type ->
      IO.puts(">>>#{type}")
      formula = formula(type, opts)
      opts = Map.put(opts, :formula, formula)
      IO.puts("options #{inspect(opts)}")
      get_child_process(opts)
    end)

    File.close(opts.new_law_csv)
    File.close(opts.enacted_by_csv)
  end

  def get_child_process(opts) do
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

  def formula(type, %{name: ""} = opts) do
    f = if opts.new?, do: [~s/{Enacted_by}=BLANK()/], else: []
    f = if type != "", do: [~s/{type_code}="#{type}"/ | f], else: f
    f = if opts.type_class != "", do: [~s/{type_class}="#{opts.type_class}"/ | f], else: f
    # f = if opts.view != "", do: [~s/view="#{opts.view}"/ | f], else: f
    ~s/AND(#{Enum.join(f, ",")})/
  end

  def formula(_type, %{name: name} = _opts) do
    ~s/{name}="#{name}"/
  end

  defp open_files() do
    # path = @new_law_csv |> Path.absname()
    {:ok, new_law_csv} = File.open(@new_law_csv, [:utf8, :append, :read])

    File.write(@new_law_csv, "Name,Title_EN,type_code,Year,Number\n")

    # path = @enacted_by_csv |> Path.absname()
    {:ok, enacted_by_csv} = File.open(@enacted_by_csv, [:utf8, :append, :read])

    File.write(@enacted_by_csv, "Name,Enacted_by\n")
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
      %{"fields" => %{"Name" => name, Enacted_by: enacted_by}} = _result ->
        IO.puts(opts.enacted_by_csv, "#{name},#{enacted_by}")
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
