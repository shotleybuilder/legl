defmodule Country do
  alias Types.AirtableSchema

  @callback schema :: AirtableSchema.t()

  @callback airtable([:atom]) :: %{}
end
