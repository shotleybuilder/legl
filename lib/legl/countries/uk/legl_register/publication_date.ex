defmodule Legl.Countries.Uk.LeglRegister.PublicationDate do
  @moduledoc """

  """
  alias Legl.Countries.Uk.LeglRegister.LegalRegister
  alias Legl.Countries.Uk.LeglRegister.New.New.LegGovUk
  alias Legl.Countries.Uk.LeglRegister.Options, as: LRO
  alias Legl.Countries.Uk.LeglRegister.CRUD.Options

  @doc """
  Linked record field linking the Legal Register to the Publication Date table
  """
  @spec set_publication_date_link(%LegalRegister{}, map()) :: {:ok, %LegalRegister{}}
  def set_publication_date_link(record, %{record_ids: record_ids})
      when is_struct(record) do
    IO.write(" PUBLICATION DATE")

    Map.put(
      record,
      :"Publication Date",
      Map.get(record_ids, record.publication_date)
    )
  end

  def set_publication_date_link(record, _), do: record

  @doc """
  Function to iterate results from legislation.gov.uk and match against
  type_code, Number and Year
  iex -> Legl.Countries.Uk.LeglRegister.New.New.find_publication_date()
  """
  def find_publication_date(opts \\ []) do
    opts =
      Enum.into(opts, %{})
      |> LRO.base_name()
      |> LRO.base_table_id()
      |> LRO.type_code()
      |> LRO.number()
      |> LRO.year()
      |> Options.month()
      |> Options.days()

    {from, to} = opts.days

    Enum.reduce_while(from..to, [], fn day, acc ->
      with({:ok, records} <- LegGovUk.getNewLaws({day, day}, opts)) do
        case Enum.reduce_while(records, acc, fn
               %{type_code: type_code, Number: number, Year: year} = record, acc ->
                 IO.puts(
                   "#{number} #{opts.number}, #{type_code} #{opts.type_code}, #{year} #{opts.year}"
                 )

                 case number == opts.number and type_code == opts.type_code and
                        Legl.Utility.year_as_integer(year) ==
                          Legl.Utility.year_as_integer(opts.year) do
                   true -> {:halt, [record | acc]}
                   false -> {:cont, acc}
                 end
             end) do
          [] ->
            {:cont, acc}

          match ->
            # IO.inspect(match)
            {:halt, [match | acc]}
        end
      else
        {:error, msg} ->
          IO.puts("ERROR: #{msg}")
          {:cont, acc}
      end
    end)
  end
end
