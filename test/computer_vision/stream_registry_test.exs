defmodule ComputerVision.StreamRegistryTest do
  use ExUnit.Case, async: true

  alias ComputerVision.StreamRegistry

  test "register/2 and lookup/1" do
    StreamRegistry.register("channel_1", self())
    assert {:ok, pid} = StreamRegistry.lookup("channel_1")
    assert pid == self()
  end

  test "lookup/1 returns error for unknown channel" do
    assert :error = StreamRegistry.lookup("unknown_#{System.unique_integer()}")
  end

  test "unregister/1 removes entry" do
    StreamRegistry.register("channel_2", self())
    StreamRegistry.unregister("channel_2")
    assert :error = StreamRegistry.lookup("channel_2")
  end
end
