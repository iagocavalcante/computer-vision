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
end
