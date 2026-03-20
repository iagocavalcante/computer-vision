defmodule ComputerVision.Storage.LocalTest do
  use ExUnit.Case, async: true
  alias ComputerVision.Storage.Local

  @test_dir "test/tmp/storage"

  setup do
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)
    on_exit(fn -> File.rm_rf!(@test_dir) end)
    %{base_dir: @test_dir}
  end

  test "write and read segment", %{base_dir: base_dir} do
    assert :ok = Local.write_segment(base_dir, "user1", "stream1", "seg0.ts", "video data")
    assert {:ok, "video data"} = Local.read_segment(base_dir, "user1", "stream1", "seg0.ts")
  end

  test "read non-existent segment returns error", %{base_dir: base_dir} do
    assert {:error, :enoent} = Local.read_segment(base_dir, "user1", "stream1", "missing.ts")
  end

  test "delete_stream removes all segments", %{base_dir: base_dir} do
    Local.write_segment(base_dir, "user1", "stream1", "seg0.ts", "data")
    Local.write_segment(base_dir, "user1", "stream1", "seg1.ts", "data")
    assert :ok = Local.delete_stream(base_dir, "user1", "stream1")
    assert {:error, :enoent} = Local.read_segment(base_dir, "user1", "stream1", "seg0.ts")
  end
end
