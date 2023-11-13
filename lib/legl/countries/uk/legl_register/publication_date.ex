defmodule Legl.Countries.Uk.LeglRegister.PublicationDate do
  alias Legl.Countries.Uk.LeglRegister.LegalRegister

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
end
