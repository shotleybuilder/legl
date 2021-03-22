defmodule UK.Schema do
  @moduledoc false

  # Schema defines a struct to hold the data that is tranlsated into a .txt file and ultimately copied and pasted into Airtable.
  # :TODO make this universal to all countries and not just implemented in UK

  defstruct flow: "",
            type: "",
            # c also used for schedules with the "s" prefix
            part: "",
            chapter: "",
            # sc also used for schedule part
            subchapter: "",
            article: "",
            para: "",
            sub: 0,
            str: ""
end
