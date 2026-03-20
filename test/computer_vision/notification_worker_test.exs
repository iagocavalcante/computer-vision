defmodule ComputerVision.NotificationWorkerTest do
  use ComputerVision.DataCase

  alias ComputerVision.{Accounts, Social, Streaming}

  setup do
    {:ok, streamer} =
      Accounts.register_user(%{
        email: "streamer@test.com",
        username: "streamer",
        password: "validpassword123"
      })

    {:ok, follower} =
      Accounts.register_user(%{
        email: "follower@test.com",
        username: "follower",
        password: "validpassword123"
      })

    {:ok, channel} = Streaming.create_channel(%{user_id: streamer.id, title: "Test Stream"})
    {:ok, _} = Social.follow_user(follower.id, streamer.id)
    %{streamer: streamer, follower: follower, channel: channel}
  end

  test "creates notifications for followers when streamer goes live",
       %{streamer: streamer, follower: follower, channel: channel} do
    # Subscribe to follower's notification topic
    Phoenix.PubSub.subscribe(ComputerVision.PubSub, "user:#{follower.id}")

    # Broadcast the event (NotificationWorker listens on "streams" topic)
    Phoenix.PubSub.broadcast(
      ComputerVision.PubSub,
      "streams",
      {:streamer_went_live, streamer, channel}
    )

    # Give the GenServer time to process
    Process.sleep(100)

    # Verify notification was created in DB
    notifications = Social.list_unread_notifications(follower.id)
    assert length(notifications) == 1
    assert hd(notifications).type == "streamer_went_live"
    assert hd(notifications).payload["username"] == "streamer"

    # Verify PubSub broadcast to follower
    assert_received {:notification, :streamer_went_live, ^streamer}
  end

  test "does nothing when streamer has no followers", %{channel: _channel} do
    {:ok, lonely_streamer} =
      Accounts.register_user(%{
        email: "lonely@test.com",
        username: "lonely",
        password: "validpassword123"
      })

    {:ok, lonely_channel} = Streaming.create_channel(%{user_id: lonely_streamer.id})

    Phoenix.PubSub.broadcast(
      ComputerVision.PubSub,
      "streams",
      {:streamer_went_live, lonely_streamer, lonely_channel}
    )

    Process.sleep(100)

    # No notifications created for anyone
    assert Social.list_unread_notifications(lonely_streamer.id) == []
  end
end
