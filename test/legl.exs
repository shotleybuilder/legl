defmodule LeglTest do

  use ExUnit.Case, async: true

  describe "Emojis" do

    test "annex" do
      assert << 0x270A :: utf8 >> == Legl.annex_emoji()
    end


  end


end
