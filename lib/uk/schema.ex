defmodule UK.Schema do
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
