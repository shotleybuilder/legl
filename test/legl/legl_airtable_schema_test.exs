defmodule Legl.Airtable.Schema.Test do
  use ExUnit.Case

  alias Legl.Airtable.Schema

  describe "chapter/3" do
    test "1 luku - Finland" do
      regex = ~s/^(\\d+)/
      str = ~s/#{Legl.chapter_emoji()}1 luku Yleiset säännökset/
      s = Schema.chapter(regex, str, %Schema{})
      assert s == %Schema{type: "chapter", chapter: "1", text: "1 luku Yleiset säännökset"}
    end
  end
end
