defmodule Legl.Airtable.AirtableTitleField do

  @doc """
  Procedure to remove the 'the' from the title string that comes back from legislation.gov.uk
  """
  def remove_the("The " <> title = _amending_title), do: title
  def remove_the(title), do: title

  @doc """
  Procedure to remove the year from the title string that comes back from legislation.gov.uk
  """
  def remove_year(str) do
    Regex.replace(~r/(.*?)([ ]\d{4})$/, str, "\\g{1}")
  end

  def lowcase(title), do: String.downcase(title)

  def upcaseFirst(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest

  def title_clean(title) do
    title |> remove_the |> remove_year # |> lowcase |> upcaseFirst
  end

end
