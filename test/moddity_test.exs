defmodule ModdityTest do
  use ExUnit.Case
  doctest Moddity

  test "greets the world" do
    assert Moddity.hello() == :world
  end
end
