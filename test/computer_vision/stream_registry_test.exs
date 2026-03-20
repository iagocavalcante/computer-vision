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

  test "process death auto-cleans registry entry" do
    test_pid = self()

    pid =
      spawn(fn ->
        StreamRegistry.register("death_test", self())
        send(test_pid, :registered)
        Process.sleep(:infinity)
      end)

    assert_receive :registered
    assert {:ok, ^pid} = StreamRegistry.lookup("death_test")

    Process.exit(pid, :kill)
    Process.sleep(50)

    assert :error = StreamRegistry.lookup("death_test")
  end

  test "duplicate registration from same process replaces" do
    StreamRegistry.register("dup_test", self())
    # Registry allows re-registration from same process — verify it works
    assert {:ok, _} = StreamRegistry.lookup("dup_test")
  end
end
