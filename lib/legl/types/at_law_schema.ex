defmodule Types.ATLawSchema do
  @law_schema ~s(
    Name
    Title_EN
    Geo_Parent
    Region
    Year
    Number
    Type
    Amends?
    Environment?
  )

  def law_schema, do: @law_schema

  def law_schema_as_list, do: Enum.map(String.split(@law_schema), fn x -> x end)

end
