defmodule DoseyTest do
  use ExUnit.Case
  doctest Dosey

  test "greets the world" do
    assert Dosey.hello() == :world
  end
end
