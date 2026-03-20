defmodule ComputerVision.AdminTest do
  use ComputerVision.DataCase
  alias ComputerVision.Admin

  test "set/2 and get/2 for instance settings" do
    Admin.set("site_name", "My Stream Site")
    assert Admin.get("site_name") == "My Stream Site"
  end

  test "get/2 returns default when not set" do
    assert Admin.get("missing_key", "default") == "default"
  end

  test "set/2 updates existing key" do
    Admin.set("site_name", "Old Name")
    Admin.set("site_name", "New Name")
    assert Admin.get("site_name") == "New Name"
  end
end
