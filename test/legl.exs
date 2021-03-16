defmodule LeglTest do
  use ExUnit.Case, async: true

  describe "Emojis" do
    test "annex" do
      assert <<0x270A::utf8>> == Legl.annex_emoji()
    end
  end

  describe "conv_alphabetic_classes/1" do
    test "e" do
      assert 2 == Legl.conv_alphabetic_classes("b")
      assert 2 == Legl.conv_alphabetic_classes("B")
    end
  end
end
