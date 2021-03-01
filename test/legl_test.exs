defmodule LeglTest do
  use ExUnit.Case
  doctest Legl

  test "greets the world" do
    assert Legl.hello() == :world
  end
end
