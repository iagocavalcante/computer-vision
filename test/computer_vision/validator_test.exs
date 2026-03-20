defmodule ComputerVision.ValidatorTest do
  use ComputerVision.DataCase
  alias ComputerVision.Accounts

  test "validates correct stream key format" do
    {:ok, user} =
      Accounts.register_user(%{
        email: "test@example.com",
        username: "teststreamer",
        password: "validpassword123"
      })

    stream_key = "teststreamer_#{user.stream_key}"
    assert {:ok, _} = ComputerVision.Validator.validate_stream_key(stream_key)
  end

  test "rejects invalid stream key" do
    {:ok, _} =
      Accounts.register_user(%{
        email: "test@example.com",
        username: "teststreamer",
        password: "validpassword123"
      })

    assert {:error, _} = ComputerVision.Validator.validate_stream_key("teststreamer_invalidkey")
  end

  test "rejects non-existent user" do
    assert {:error, _} =
             ComputerVision.Validator.validate_stream_key("nouser_#{Ecto.UUID.generate()}")
  end

  test "validates malformed stream key (no underscore)" do
    assert {:error, "malformed stream key"} =
             ComputerVision.Validator.validate_stream_key("nounderscore")
  end

  test "validates empty stream key" do
    assert {:error, _} = ComputerVision.Validator.validate_stream_key("")
  end

  test "ensure_channel creates channel if missing" do
    {:ok, user} =
      Accounts.register_user(%{
        email: "new@test.com",
        username: "newstreamer",
        password: "validpassword123"
      })

    # User has no channel yet
    assert ComputerVision.Streaming.get_channel_by_user(user.id) == nil

    # Validating stream key should create the channel
    {:ok, _} = ComputerVision.Validator.validate_stream_key("newstreamer_#{user.stream_key}")

    # Channel should now exist
    assert ComputerVision.Streaming.get_channel_by_user(user.id) != nil
  end
end
