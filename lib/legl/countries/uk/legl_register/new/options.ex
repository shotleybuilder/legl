defmodule Legl.Countries.Uk.LeglRegister.New.Options do
  alias Legl.Services.Airtable.AtBasesTables

  @default_opts %{
    base_name: "UK S",
    table_name: "Publication Date",
    type_code: [""],
    year: 2023,
    month: nil,
    day: nil,
    # days as a tuple {from, to} eg {10, 23} for days from 10th to 23rd
    days: nil,
    # Where's the data coming from?
    source: :web,
    # Trigger .csv saving?
    csv?: false,
    # Global mute msg
    mute?: true
  }

  def default_opts, do: @default_opts

  @spec legal_register_base_id_table_id(map()) :: map()
  def legal_register_base_id_table_id(opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(opts.base_name)

    {:ok, {_base_id, pub_table_id}} =
      AtBasesTables.get_base_table_id(opts.base_name, opts.table_name)

    Map.merge(opts, %{base_id: base_id, table_id: table_id, pub_table_id: pub_table_id})
  end

  @spec source(map()) :: map()
  def source(opts) do
    Map.put(
      opts,
      :source,
      case ExPrompt.choose("Source Records", [
             "legislation.gov.uk",
             "w/ si code",
             "w/o si code",
             "w/ & w/o si code",
             "amending_laws",
             "amended laws"
           ]) do
        0 ->
          :web

        1 ->
          :si_code

        2 ->
          :x_si_code

        3 ->
          :both

        4 ->
          {
            :amend,
            "lib/legl/countries/uk/legl_register/amend/new_amending_laws_enum0.json"
          }

        5 ->
          {
            :amend,
            "lib/legl/countries/uk/legl_register/amend/new_amended_laws_enum0.json"
          }
      end
    )
  end

  @spec month(map()) :: map()
  def month(opts) do
    Map.put(
      opts,
      :month,
      ExPrompt.choose("Month", ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"])
      |> (&Kernel.+(&1, 1)).()
    )
  end

  @spec day_groups(map()) :: map()
  def day_groups(opts) do
    Map.put(
      opts,
      :days,
      case ExPrompt.choose("Days", ["1-9", "10-20", "21-30", "21-31", "21-28"]) do
        0 -> {1, 9}
        1 -> {10, 20}
        2 -> {21, 30}
        3 -> {21, 31}
        4 -> {21, 28}
      end
    )
  end

  @spec days(map()) :: map()
  def days(opts) do
    from = ExPrompt.string("from?: ") |> String.to_integer()
    to = ExPrompt.string("to?: ") |> String.to_integer()

    Map.put(
      opts,
      :days,
      {from, to}
    )
  end

  @spec formula(map()) :: map()
  def formula(%{source: :web} = opts) do
    with(
      f = [~s/{Year}="#{opts.year}"/],
      {:ok, f} <- month_formula(opts.month, f),
      f = if(opts.day != nil, do: [~s/{Day}="#{opts.day}"/ | f], else: f),
      f = if({from, to} = opts.days, do: [day_range_formula(from, to) | f], else: f)
    ) do
      Map.put(opts, :formula, ~s/AND(#{Enum.join(f, ",")})/)
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def formula(_), do: {:ok, nil}

  defp day_range_formula(from, to) do
    ~s/OR(#{Enum.map(from..to, fn d ->
      d = if String.length(Integer.to_string(d)) == 1 do
        ~s/0#{d}/
      else
        ~s/#{d}/
      end
      ~s/{Day}="#{d}"/
    end) |> Enum.join(",")})/
  end

  defp month_formula(nil, _), do: {:error, "Month option required e.g. month: 4"}

  defp month_formula(month, f) when is_integer(month) do
    month = if String.length(Integer.to_string(month)) == 1, do: ~s/0#{month}/, else: ~s/#{month}/
    {:ok, [~s/{Month}="#{month}"/ | f]}
  end
end
