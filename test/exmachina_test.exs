defmodule ExmachinaTest do
  use ExUnit.Case
  doctest Exmachina

  test "greets the world" do
    assert Exmachina.hello() == :world
  end
end
